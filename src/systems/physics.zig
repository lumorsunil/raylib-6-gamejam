const std = @import("std");
const Allocator = std.mem.Allocator;
const Game = @import("../game.zig").Game;
const rl = @import("raylib");

pub const PhysicsOptions = struct {
    enable_separate_axis_update: bool = false,
};

pub const Axis = enum { x, y };

pub fn Physics(comptime _: PhysicsOptions) type {
    return struct {
        enabled: bool = true,
        grid: ?DefaultGrid = null,
        container: BodyContainer,

        const grid_mod = @import("physics/grid.zig");
        pub const Grid = grid_mod.Grid;
        pub const DefaultGrid = grid_mod.DefaultGrid;
        pub const DefaultCell = grid_mod.DefaultCell;

        pub const BodyContainer = @import("physics/body-container.zig").BodyContainer;

        pub fn init(allocator: Allocator) @This() {
            return .{
                .container = .init(allocator),
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            if (self.grid) |*grid| grid.deinit(allocator);
            self.container.deinit();
        }

        pub fn update(self: *@This(), game: *Game) void {
            const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
            defer zone.end();

            var it = game.entityIterator(.{Game.C.Body}, .{});
            const time_step = game.physicsTimeStep();

            if (self.grid) |*grid| {
                const clear_zone = Game.tracyZoneN(@src(), "grid clear");
                defer clear_zone.end();

                for (grid.data) |*cell| {
                    cell.clear();
                }
            }

            for (0..game.physics_frames) |_| {
                const frame_zone = Game.tracyZoneN(@src(), "physics frame");
                defer frame_zone.end();

                self.updateBodyContainer(time_step);

                it.reset();
                while (it.next()) |ctx| {
                    self.updateAxis(game, ctx);

                    // if (ctx.tryGet(Game.C.Shard)) |shard| {
                    //     if (shard.enable_drag) {
                    //         applyDrag(ctx.get(Game.C.Body), time_step);
                    //     }
                    // }
                }
            }

            self.container.endPhysicsFrame();

            // for (0..game.physics_frames) |_| {
            //     const frame_zone = Game.tracyZoneN(@src(), "physics frame");
            //     defer frame_zone.end();
            //
            //     it.reset();
            //     while (it.next()) |ctx| {
            //         const process_zone = Game.tracyZoneN(@src(), "process entity");
            //         defer process_zone.end();
            //
            //         const body = ctx.get(Game.C.Body);
            //         if (!body.enabled) continue;
            //
            //         body.setVelocity(body.velocity().add(body.acceleration().scale(time_step)));
            //         const velocity_pre_knockback = body.velocity();
            //         if (ctx.tryGet(Game.C.Knockback)) |knockback| {
            //             body.setVelocity(body.velocity().add(knockback.force.scale(time_step)));
            //             knockback.force = knockback.force.subtract(knockback.force.scale(3 * time_step));
            //             if (knockback.force.length() <= 0.1) ctx.remove(Game.C.Knockback);
            //         }
            //
            //         body.setRotation(body.rotation() + body.angular_velocity * time_step);
            //
            //         if (comptime options.enable_separate_axis_update) {
            //             self.updateAxis(game, ctx, body, &.{.x}, time_step);
            //             self.updateAxis(game, ctx, body, &.{.y}, time_step);
            //         } else {
            //             self.updateAxis(game, ctx, body, &.{ .x, .y }, time_step);
            //         }
            //
            //         body.velocity = velocity_pre_knockback;
            //
            //         if (ctx.tryGet(Game.C.Shard)) |shard| {
            //             if (shard.enable_drag) {
            //                 applyDrag(body, time_step);
            //             }
            //         }
            //
            //         body.acceleration = .init(0, 0);
            //     }
            // }
        }

        fn updateBodyContainer(self: *@This(), time_step: f32) void {
            const frame_zone = Game.tracyZoneN(@src(), @src().fn_name);
            defer frame_zone.end();

            const drag_factor = 3;

            self.container.updatePositions(drag_factor, time_step, .x);
            self.container.updatePositions(drag_factor, time_step, .y);
            self.container.updateRotation(drag_factor, time_step);
        }

        pub fn updatePosition(
            _: *@This(),
            body: *Game.C.Body,
            comptime axiis: []const Axis,
            time_step: f32,
        ) void {
            const zone = Game.tracyZoneN(@src(), @src().fn_name);
            defer zone.end();

            inline for (comptime axiis) |axis| {
                switch (comptime axis) {
                    .x => {
                        if (!body.lock_x) {
                            body.position.x += body.velocity.x * time_step;
                        }
                    },
                    .y => {
                        if (!body.lock_y) {
                            body.position.y += body.velocity.y * time_step;
                        }
                    },
                }
            }
        }

        // TODO: vectorize everything in here
        pub fn updateAxis(
            self: *@This(),
            game: *Game,
            ctx: Game.EntityContext,
            // body: *Game.C.Body,
            // comptime axiis: []const Axis,
            // time_step: f32,
        ) void {
            const zone = Game.tracyZoneN(@src(), @src().fn_name);
            defer zone.end();

            // self.updatePosition(body, axiis, time_step);
            if (self.grid) |*grid| {
                const process_zone = Game.tracyZoneN(@src(), "process grid");
                defer process_zone.end();

                const hitbox = game.hitbox(ctx);
                const candidates = DefaultGrid.CellCandidates.init(grid.*, hitbox.hitbox);

                const cell_zone = Game.tracyZoneN(@src(), "update cell");
                var it = candidates.iterator(grid);
                while (it.next()) |entry| {
                    entry.cell.putEntity(game.allocator, ctx.entity);
                }
                cell_zone.end();

                // grid.resolveCollisions(game, ctx, body, &.{.x});
            }
        }

        fn applyDrag(body: *Game.C.Body, time_step: f32) void {
            const zone = Game.tracyZoneN(@src(), @src().fn_name);
            defer zone.end();

            const drag_factor = 3;

            body.setVelocity(body.velocity().subtract(body.velocity().scale(drag_factor * time_step)));
            body.setRotationVelocity(body.rotationVelocity() - body.rotationVelocity() * drag_factor * time_step);
        }
    };
}
