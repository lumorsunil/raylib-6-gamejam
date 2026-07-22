const std = @import("std");
const Allocator = std.mem.Allocator;
const Game = @import("../../game.zig").Game;
const VectorArrayList = @import("vector-array-list.zig").VectorArrayList;

const VAL = VectorArrayList(f32, 0, .default);
const VA = VAL.Vector;
const Vector = Game.Vector;
const Axis = @import("../physics.zig").Axis;

pub const BodyContainer = struct {
    allocator: Allocator,
    gravity_factor: VAL = .empty,
    acceleration_x: VAL = .empty,
    acceleration_y: VAL = .empty,
    velocity_x: VAL = .empty,
    velocity_y: VAL = .empty,
    position_x: VAL = .empty,
    position_y: VAL = .empty,
    rotation: VAL = .empty,
    rotation_velocity: VAL = .empty,
    drag_factor: VAL = .empty,

    pub fn init(allocator: Allocator) @This() {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        const allocator = self.allocator;
        inline for (std.meta.fields(@This())) |field| {
            if (@hasDecl(field.type, "deinit")) {
                @field(self, field.name).deinit(allocator);
            }
        }
    }

    pub fn setBody(
        self: *@This(),
        i: usize,
        pos: Vector,
        vel: Vector,
        acc: Vector,
        r: f32,
        rv: f32,
        is_static: bool,
        is_pointers_invalidated: ?*bool,
    ) void {
        const allocator = self.allocator;
        self.gravity_factor.set(allocator, i, if (is_static) 0 else 1, is_pointers_invalidated);
        self.position_x.set(allocator, i, pos.x, is_pointers_invalidated);
        self.position_y.set(allocator, i, pos.y, is_pointers_invalidated);
        self.velocity_x.set(allocator, i, vel.x, is_pointers_invalidated);
        self.velocity_y.set(allocator, i, vel.y, is_pointers_invalidated);
        self.acceleration_x.set(allocator, i, acc.x, is_pointers_invalidated);
        self.acceleration_y.set(allocator, i, acc.y, is_pointers_invalidated);
        self.rotation.set(allocator, i, r, is_pointers_invalidated);
        self.rotation_velocity.set(allocator, i, rv, is_pointers_invalidated);
        self.drag_factor.set(allocator, i, 0, is_pointers_invalidated);
    }

    fn integrateScaledFn(dt: f32, a: *VA, b: *VA) void {
        const splat = @as(VA, @splat(dt));

        a.* += b.* * splat;
    }

    fn integrateScaled(dt: f32, a: *VAL, b: *VAL) void {
        a.iterateC(f32, b, dt, integrateScaledFn);
    }

    fn applyGravityFn(gravity: *const VA, acceleration: *VA, gravity_factor: *const VA) void {
        acceleration.* += gravity.* * gravity_factor.*;
    }

    fn applyGravity(self: *@This(), gravity: Vector) void {
        const gravity_x_vector = @as(VA, @splat(gravity.x));
        self.acceleration_x.iterateC(
            *const VA,
            &self.gravity_factor,
            &gravity_x_vector,
            applyGravityFn,
        );
        const gravity_y_vector = @as(VA, @splat(gravity.y));
        self.acceleration_y.iterateC(
            *const VA,
            &self.gravity_factor,
            &gravity_y_vector,
            applyGravityFn,
        );
    }

    fn applyDragFn(drag_factor: *const VA, velocity: *VA, entity_drag_factor: *const VA) void {
        // v = v - v * factor

        const factor = entity_drag_factor.* * drag_factor.*;
        velocity.* -= velocity.* * factor;
    }

    fn applyDrag(self: *@This(), val: *VAL, drag_factor: f32, dt: f32) void {
        @setRuntimeSafety(false);

        const factor = drag_factor * dt;
        const factor_v = @as(VA, @splat(factor));

        val.iterateC(*const VA, &self.drag_factor, &factor_v, applyDragFn);
    }

    pub fn startPhysicsFrame(self: *@This(), gravity: Vector) void {
        @setRuntimeSafety(false);

        self.applyGravity(gravity);
    }

    pub fn endPhysicsFrame(self: *@This()) void {
        @setRuntimeSafety(false);

        self.acceleration_x.setScalar(0);
        self.acceleration_y.setScalar(0);
    }

    pub fn updatePositions(self: *@This(), drag_factor: f32, dt: f32, comptime axis: Axis) void {
        @setRuntimeSafety(false);

        const frame_zone = Game.tracyZoneN(@src(), @src().fn_name ++ "(" ++ @tagName(axis) ++ ")");
        defer frame_zone.end();

        switch (comptime axis) {
            .x => {
                integrateScaled(dt, &self.velocity_x, &self.acceleration_x);
                self.applyDrag(&self.velocity_x, drag_factor, dt);
                integrateScaled(dt, &self.position_x, &self.velocity_x);
            },
            .y => {
                integrateScaled(dt, &self.velocity_y, &self.acceleration_y);
                self.applyDrag(&self.velocity_y, drag_factor, dt);
                integrateScaled(dt, &self.position_y, &self.velocity_y);
            },
        }
    }

    pub fn updateRotation(self: *@This(), drag_factor: f32, dt: f32) void {
        @setRuntimeSafety(false);

        const frame_zone = Game.tracyZoneN(@src(), @src().fn_name);
        defer frame_zone.end();

        self.applyDrag(&self.rotation_velocity, drag_factor, dt);
        integrateScaled(dt, &self.rotation, &self.rotation_velocity);
    }
};
