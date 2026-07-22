const std = @import("std");
const Allocator = std.mem.Allocator;
const Game = @import("../../game.zig").Game;
const Axis = @import("../physics.zig").Axis;
const rl = @import("raylib");
const ecs = @import("ecs");

pub fn GridOptions(comptime Cell: type) type {
    return struct {
        comptime Cell: type = Cell,
        isSolid: *const fn (game: *Game, cell: Cell) bool,
    };
}

pub fn Grid(comptime Cell: type, comptime options: GridOptions(Cell)) type {
    return struct {
        data: []Cell,
        width: usize,
        height: usize,

        const G = @This();

        pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !@This() {
            const data = try allocator.alloc(Cell, width * height);
            for (data) |*cell| cell.* = .init();
            return .{
                .data = data,
                .width = width,
                .height = height,
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            for (self.data) |*cell| {
                if (@hasDecl(Cell, "deinit")) {
                    cell.deinit(allocator);
                }
            }
            allocator.free(self.data);
        }

        pub fn cellSize(_: @This()) Game.Vector {
            return .init(48, 48);
        }

        pub const CellCandidates = struct {
            aabb: rl.Rectangle,
            min_x: usize,
            min_y: usize,
            max_x: usize,
            max_y: usize,

            pub fn init(grid: G, hitbox: rl.Rectangle) @This() {
                const cell_size = grid.cellSize();

                const hitbox_min_x = @round(hitbox.x);
                const hitbox_max_x = @round(hitbox.x + hitbox.width);
                const hitbox_min_y = @round(hitbox.y);
                const hitbox_max_y = @round(hitbox.y + hitbox.height);

                const min_x: usize = @intFromFloat(grid.clampXToGrid(@divFloor(hitbox_min_x, cell_size.x)));
                const min_y: usize = @intFromFloat(grid.clampYToGrid(@divFloor(hitbox_min_y, cell_size.y)));
                const max_x: usize = @intFromFloat(grid.clampXToGrid(@divFloor(hitbox_max_x, cell_size.x)));
                const max_y: usize = @intFromFloat(grid.clampYToGrid(@divFloor(hitbox_max_y, cell_size.y)));

                return .{
                    .aabb = hitbox,
                    .min_x = min_x,
                    .min_y = min_y,
                    .max_x = max_x,
                    .max_y = max_y,
                };
            }

            pub fn initCircle(grid: G, center: Game.Vector, radius: f32) @This() {
                const tl = center.subtract(.init(radius, radius));
                const aabb = rl.Rectangle.init(tl.x, tl.y, radius * 2, radius * 2);
                return .init(grid, aabb);
            }

            pub fn isEmpty(self: @This()) bool {
                const width = self.max_x - self.min_x;
                const height = self.max_y - self.min_y;

                return width == 0 or height == 0;
            }

            pub const Iterator = struct {
                grid: *G,
                candidates: CellCandidates,
                x: usize,
                y: usize,

                pub fn init(grid: *G, candidates: CellCandidates) @This() {
                    return .{
                        .grid = grid,
                        .candidates = candidates,
                        .x = candidates.min_x,
                        .y = candidates.min_y,
                    };
                }

                pub const Entry = struct {
                    cell: *Cell,
                    x: usize,
                    y: usize,
                    position: Game.Vector,
                };

                pub fn next(self: *@This()) ?Entry {
                    if (self.y > self.candidates.max_y) return null;

                    const result = Entry{
                        .cell = self.grid.getCell(self.x, self.y),
                        .x = self.x,
                        .y = self.y,
                        .position = .init(@floatFromInt(self.x), @floatFromInt(self.y)),
                    };

                    self.x += 1;
                    if (self.x > self.candidates.max_x) {
                        self.x = self.candidates.min_x;
                        self.y += 1;
                    }

                    return result;
                }
            };

            pub fn iterator(self: @This(), grid: *G) Iterator {
                return .init(grid, self);
            }

            pub fn format(
                self: @This(),
                writer: *std.Io.Writer,
            ) std.Io.Writer.Error!void {
                try writer.print("Candidates{{min=({},{}) max=({},{})}}", .{ self.min_x, self.min_y, self.max_x, self.max_y });
            }
        };

        fn clampXToGrid(self: @This(), x: f32) f32 {
            const fwidth: f32 = @floatFromInt(self.width);
            return @max(0, @min(fwidth - 1, x));
        }

        fn clampYToGrid(self: @This(), y: f32) f32 {
            const fheight: f32 = @floatFromInt(self.height);
            return @max(0, @min(fheight - 1, y));
        }

        fn getRecPos(rec: rl.Rectangle, comptime axis: Axis) f32 {
            return switch (comptime axis) {
                .x => rec.x,
                .y => rec.y,
            };
        }

        fn getRecSize(rec: rl.Rectangle, comptime axis: Axis) f32 {
            return switch (comptime axis) {
                .x => rec.width,
                .y => rec.height,
            };
        }

        fn getVectorComponent(v: Game.Vector, comptime axis: Axis) f32 {
            return switch (comptime axis) {
                .x => v.x,
                .y => v.y,
            };
        }

        fn addToVectorComponent(v: *Game.Vector, value: f32, comptime axis: Axis) void {
            switch (comptime axis) {
                .x => v.x += value,
                .y => v.y += value,
            }
        }

        fn roundVectorComponent(v: *Game.Vector, comptime axis: Axis) void {
            switch (comptime axis) {
                .x => v.x = @round(v.x),
                .y => v.y = @round(v.y),
            }
        }

        pub fn resolveCollisions(
            self: *@This(),
            game: *Game,
            ctx: Game.EntityContext,
            body: *Game.C.Body,
            comptime axiis: []const Axis,
        ) void {
            const zone = Game.tracyZoneN(@src(), @src().fn_name);
            defer zone.end();

            const hitbox = game.hitbox(ctx);
            const candidates = CellCandidates.init(self.*, hitbox.hitbox);
            const cell_size = self.cellSize();

            if (candidates.isEmpty()) return;

            var it = candidates.iterator(self);
            while (it.next()) |entry| {
                if (!self.isSolid(game, entry.x, entry.y)) continue;

                const cell_pos = entry.position.multiply(cell_size);

                inline for (comptime axiis) |axis| {
                    const body_min = getRecPos(hitbox.hitbox, axis);
                    const body_max = body_min + getRecSize(hitbox.hitbox, axis);
                    const cell_min = getVectorComponent(cell_pos, axis);
                    const cell_max = cell_min + getVectorComponent(cell_size, axis);

                    const d_min = body_min - cell_max;
                    const d_max = cell_min - body_max;

                    const correction = if (@abs(d_min) < @abs(d_max)) -d_min else d_max;

                    addToVectorComponent(&body.position, correction, axis);
                    roundVectorComponent(&body.position, axis);
                }

                return;
            }
        }

        pub fn getCell(self: @This(), x: usize, y: usize) *Cell {
            return &self.data[x + y * self.width];
        }

        pub fn isSolid(self: @This(), game: *Game, x: usize, y: usize) bool {
            return options.isSolid(game, self.getCell(x, y).*);
        }

        pub const IntersectionHandlerEvent = enum {
            cont,
            abort,
        };

        pub const IntersectionCollidee = union(enum) {
            grid_cell: usize,
            entity: Game.EntityContext,
        };

        pub fn intersectionsRec(
            self: @This(),
            game: *Game,
            rec: rl.Rectangle,
            context: anytype,
            callback: *const fn (@TypeOf(context), IntersectionCollidee) IntersectionHandlerEvent,
        ) void {
            const candidates = CellCandidates.init(self, rec);

            for (candidates.min_x..candidates.max_x) |x| {
                for (candidates.min_y..candidates.max_y) |y| {
                    const cell = self.getCell(x, y);

                    var it = cell.objects.keyIterator();
                    while (it.next()) |entity| {
                        const ctx = Game.EntityContext.init(game, entity);
                        const hitbox = game.hitbox(ctx);

                        if (hitbox.checkCollision(rec)) {
                            switch (callback(context, .{ .entity = ctx })) {
                                .cont => {},
                                .abort => return,
                            }
                        }
                    }

                    if (!self.isSolid(game, x, y)) continue;

                    switch (callback(context, .{ .grid_cell = x + y * self.width })) {
                        .cont => continue,
                        .abort => return,
                    }
                }
            }
        }

        pub const IntersectionCircleIterator = struct {
            game: *Game,
            grid: *G,
            center: Game.Vector,
            radius: f32,
            candidates_it: CellCandidates.Iterator,
            cell_it: ?std.hash_map.AutoHashMapUnmanaged(ecs.Entity, void).KeyIterator,

            pub fn init(game: *Game, grid: *G, center: Game.Vector, radius: f32) @This() {
                const candidates = CellCandidates.initCircle(grid.*, center, radius);

                return .{
                    .game = game,
                    .grid = grid,
                    .candidates_it = candidates.iterator(grid),
                    .center = center,
                    .radius = radius,
                    .cell_it = null,
                };
            }

            pub fn next(self: *@This()) ?IntersectionCollidee {
                if (self.nextEntity()) |entity| return entity;

                while (self.candidates_it.next()) |candidate| {
                    self.cell_it = candidate.cell.objects.keyIterator();
                    if (self.nextEntity()) |entity| return entity;
                }

                return null;
            }

            pub fn nextEntity(self: *@This()) ?IntersectionCollidee {
                const cell_it = if (self.cell_it) |*cell_it| cell_it else return null;

                while (cell_it.next()) |entity| {
                    const ctx = Game.EntityContext.init(self.game, entity.*);
                    const hitbox = self.game.hitbox(ctx);

                    if (rl.checkCollisionCircleRec(self.center, self.radius, hitbox.hitbox)) {
                        return .{ .entity = ctx };
                    }
                }

                self.cell_it = null;

                return null;
            }
        };

        pub fn intersectionsCircle(
            self: *@This(),
            game: *Game,
            center: Game.Vector,
            radius: f32,
        ) IntersectionCircleIterator {
            return .init(game, self, center, radius);
        }
    };
}

pub const DefaultCell = struct {
    is_solid: bool = false,
    objects: std.hash_map.AutoHashMapUnmanaged(ecs.Entity, void) = .empty,

    pub fn init() @This() {
        return .{};
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.objects.deinit(allocator);
    }

    pub fn isSolid(_: *Game, cell: @This()) bool {
        return cell.is_solid;
    }

    pub fn putEntity(self: *@This(), allocator: Allocator, entity: ecs.Entity) void {
        self.objects.put(allocator, entity, {}) catch unreachable;
    }

    pub fn removeEntity(self: *@This(), entity: ecs.Entity) void {
        self.objects.remove(entity);
    }

    pub fn clear(self: *@This()) void {
        self.objects.clearRetainingCapacity();
    }
};

pub const default_grid_options = GridOptions(DefaultCell){
    .isSolid = DefaultCell.isSolid,
};

pub const DefaultGrid = Grid(DefaultCell, default_grid_options);
