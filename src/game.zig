const std = @import("std");
const ecs = @import("ecs");
const rl = @import("raylib");
const emscripten = std.os.emscripten;

const Mode = enum { dev, prod };

const mode: Mode = .dev;

pub const Game = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    reg: ecs.Registry,
    random_io: std.Random.IoSource,
    screen_state: ScreenState = if (mode == .prod) .logo else .gameplay,
    logo: Logo = .init(0),
    menu: Menu = .init(),
    settings: Settings = .init(),
    game_over: GameOver = .init(0),
    wants_to_quit: bool = false,

    pub const ScreenState = enum {
        logo,
        menu,
        gameplay,
        ending,
        game_over,
    };

    pub const Logo = @import("logo.zig").Logo;
    pub const Menu = @import("menu.zig").Menu;
    pub const Settings = @import("settings.zig").Settings;
    pub const GameOver = @import("game-over.zig").GameOver;

    pub const Camera = rl.Camera2D;
    pub const Vector = rl.Vector2;
    pub const Color = rl.Color;
    pub const Texture = rl.Texture2D;

    pub const C = @import("components.zig");
    pub const S = @import("systems.zig");

    pub fn init(io: std.Io, allocator: std.mem.Allocator) @This() {
        return .{
            .io = io,
            .allocator = allocator,
            .reg = .init(allocator),
            .random_io = .{ .io = io },
        };
    }

    pub fn deinit(self: *@This()) void {
        self.physics().deinit(self.allocator);
        self.reg.deinit();
        rl.closeWindow();
    }

    var emscripten_game_ptr: *Game = undefined;

    pub fn run(self: *@This()) void {
        if (@import("builtin").cpu.arch.isWasm()) {
            emscripten_game_ptr = self;
            emscripten.emscripten_set_main_loop(emscripten_loop, self.fps(), 1);
        } else {
            while (!rl.windowShouldClose() and !self.wants_to_quit) self.loop();
        }
    }

    fn emscripten_loop() callconv(.c) void {
        loop(emscripten_game_ptr);
    }

    fn loop(self: *@This()) void {
        self.update();
        rl.beginDrawing();
        self.draw();
        rl.endDrawing();
    }

    pub const setup = @import("setup.zig").setup;
    pub const update = @import("update.zig").update;
    pub const draw = @import("draw.zig").draw;

    pub fn zoom(_: @This()) f32 {
        return 2;
    }

    pub fn fps(_: @This()) u8 {
        return 60;
    }

    pub fn elapsedTime(_: @This()) f64 {
        return rl.getTime();
    }

    pub fn deltaTime(_: @This()) f32 {
        return rl.getFrameTime();
    }

    pub fn screenSize(_: @This()) Vector {
        return .init(720, 720);
    }

    pub fn worldSize(self: @This()) Vector {
        const base_x = 405;
        const base_y = 720;
        const z = self.zoom();
        return .init(base_x / z, base_y / z);
    }

    pub fn worldCenter(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos);
    }

    pub fn worldCenterBottom(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos).multiply(.init(1, 2));
    }

    pub fn worldCenterTop(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos).multiply(.init(1, 0));
    }

    pub fn worldPosition(self: @This()) Vector {
        const screen_size = self.screenSize().scale(1 / self.zoom());
        const world_size = self.worldSize();
        return .init(screen_size.x / 2 - world_size.x / 2, 0);
    }

    pub fn addSingleton(self: *@This(), singleton: anytype) void {
        self.reg.singletons().add(singleton);
    }

    pub fn getSingleton(self: *@This(), comptime T: type) *T {
        return self.reg.singletons().get(T);
    }

    pub fn getSingletonConst(self: *@This(), comptime T: type) T {
        return self.reg.singletons().getConst(T);
    }

    fn singletonFn(comptime T: type) fn (*Game) *T {
        return struct {
            pub fn get(self: *Game) *T {
                return self.getSingleton(T);
            }
        }.get;
    }

    fn singletonConstFn(comptime T: type) fn (*Game) T {
        return struct {
            pub fn get(self: *Game) T {
                return self.getSingletonConst(T);
            }
        }.get;
    }

    pub const camera = singletonFn(Camera);
    pub const cameraSystem = singletonFn(Game.S.Camera);
    pub const input = singletonFn(Game.S.Input);
    pub const physics = singletonFn(Game.S.Physics);
    pub const controllable = singletonFn(Game.S.Controllable);
    pub const destroyEntitiesSystem = singletonFn(Game.S.DestroyEntities);
    pub const spritesheet = singletonConstFn(Texture);

    pub fn initSprite(self: *@This(), source: rl.Rectangle) Game.C.Renderable {
        return .initSprite(self.spritesheet(), source);
    }

    pub fn createEntity(self: *@This()) EntityContext {
        return .init(self, self.reg.create());
    }

    pub fn destroyEntity(self: *@This(), entity: ecs.Entity) void {
        const destroy_entities = self.getSingleton(Game.S.DestroyEntities);
        destroy_entities.destroy(entity);
    }

    pub fn getOneByTag(self: *@This(), comptime T: type) EntityContext {
        var it = self.entityIterator(.{T}, .{});
        return it.next().?;
    }

    pub fn tryGetOneByTag(self: *@This(), comptime T: type) ?EntityContext {
        var it = self.entityIterator(.{T}, .{});
        return it.next();
    }

    pub const EntityContext = struct {
        game: *Game,
        entity: ecs.Entity,

        pub fn init(game: *Game, entity: ecs.Entity) @This() {
            return .{ .game = game, .entity = entity };
        }

        pub fn equals(self: EntityContext, other: EntityContext) bool {
            return self.entity.index == other.entity.index and self.entity.version == other.entity.version;
        }

        pub fn has(self: EntityContext, comptime T: type) bool {
            return self.game.reg.has(T, self.entity);
        }

        pub fn get(self: EntityContext, comptime T: type) *T {
            return self.game.reg.get(T, self.entity);
        }

        pub fn getConst(self: EntityContext, comptime T: type) T {
            return self.game.reg.getConst(T, self.entity);
        }

        pub fn tryGet(self: EntityContext, comptime T: type) ?*T {
            return self.game.reg.tryGet(T, self.entity);
        }

        pub fn tryGetConst(self: EntityContext, comptime T: type) ?T {
            return self.game.reg.tryGetConst(T, self.entity);
        }

        pub fn add(self: EntityContext, component: anytype) void {
            return self.game.reg.addOrReplace(self.entity, component);
        }

        pub fn remove(self: EntityContext, comptime T: type) void {
            return self.game.reg.removeIfExists(T, self.entity);
        }

        pub fn destroy(self: EntityContext) void {
            self.game.destroyEntity(self.entity);
        }

        pub fn valid(self: EntityContext) bool {
            return self.game.reg.valid(self.entity);
        }
    };

    fn EntityIterator(comptime includes: anytype, comptime excludes: anytype) type {
        const View, const Iterator = comptime brk: {
            if (includes.len == 1 and excludes.len == 0) break :brk .{ ecs.BasicView(includes[0]), ecs.utils.ReverseSliceIterator(ecs.Entity) };
            break :brk .{ ecs.MultiView(includes, excludes), ecs.MultiView(includes, excludes).Iterator };
        };

        return struct {
            game: *Game,
            view: View,
            it: ?Iterator = null,

            pub fn init(game: *Game, view: View) @This() {
                return .{ .game = game, .view = view };
            }

            pub fn next(self: *@This()) ?EntityContext {
                const it = self.getIt();
                const entity = it.next() orelse return null;
                return .init(self.game, entity);
            }

            pub fn reset(self: *@This()) void {
                const it = self.getIt();
                it.reset();
            }

            fn getIt(self: *@This()) *Iterator {
                if (self.it) |*it| return it;
                self.it = self.view.entityIterator();
                return &(self.it.?);
            }
        };
    }

    pub fn entityIterator(
        self: *@This(),
        comptime includes: anytype,
        comptime excludes: anytype,
    ) EntityIterator(includes, excludes) {
        return .init(self, self.reg.view(includes, excludes));
    }

    pub fn random(self: *@This()) std.Random {
        return self.random_io.interface();
    }

    pub fn hitbox(_: *@This(), ctx: EntityContext) Game.C.Hitbox {
        const body = ctx.get(Game.C.Body);
        var hitbox_component = ctx.tryGetConst(Game.C.Hitbox) orelse {
            const renderable = ctx.get(Game.C.Renderable);
            const size = renderable.size(1, body.rotation);
            const origin = renderable.origin(1, body.rotation);
            const position = body.position.subtract(origin);

            return .init(position, size);
        };

        const origin = hitbox_component.size().scale(0.5);
        const position = body.position.subtract(origin).add(hitbox_component.position());
        hitbox_component.setPosition(position);

        return hitbox_component;
    }

    pub fn player(self: *Game) EntityContext {
        return self.getOneByTag(Game.C.Player);
    }

    pub fn gameOver(self: *Game) void {
        self.game_over = .init(self.elapsedTime());
        self.screen_state = .game_over;
    }

    pub fn restart(self: *Game) void {
        self.menu.setMenu(Menu.main_menu);
        self.screen_state = .menu;
        self.destroyAllEntities();
        @import("setup.zig").setupEntities(self);
    }

    fn destroyAllEntities(self: *Game) void {
        var it = self.reg.entities();

        while (it.next()) |entity| {
            self.destroyEntity(entity);
        }

        self.destroyEntitiesSystem().update(self);
    }

    pub fn ending(self: *Game) void {
        self.screen_state = .ending;
    }

    pub const OutOfBoundsRules = enum {
        all_directions,
        allow_bottom,
    };

    pub fn isOutOfBounds(self: *Game, ctx: EntityContext, rules: OutOfBoundsRules) bool {
        const hitbox_ = self.hitbox(ctx);
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        if (hitbox_.right() - world_pos.x <= 0) return true;
        if (hitbox_.bottom() - world_pos.y <= 0) return true;
        if (hitbox_.left() - world_pos.x - world_size.x >= 0) return true;
        if (rules != .allow_bottom and hitbox_.top() - world_pos.y - world_size.y >= 0) return true;

        return false;
    }

    pub const draw_layers: struct {
        background: usize,
        enemy: usize,
        player: usize,
    } = .{
        .background = 0,
        .enemy = 1,
        .player = 2,
    };
};
