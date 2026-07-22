const Game = @import("../game.zig").Game;

pub const Body = struct {
    enabled: bool = true,
    ctx: Game.EntityContext,
    // position: Game.Vector,
    // velocity: Game.Vector = .init(0, 0),
    // acceleration: Game.Vector = .init(0, 0),
    scale: f32 = 1,
    // rotation: f32 = 0,
    // angular_velocity: f32 = 0,
    lock_x: bool = false,
    lock_y: bool = false,

    pub fn init(ctx: Game.EntityContext, pos: Game.Vector) @This() {
        ctx.game.physics().container.setBody(
            ctx.entity.index,
            pos,
            .init(0, 0),
            .init(0, 0),
            0,
            0,
            false,
            null,
        );

        return .{
            .ctx = ctx,
            // .position = position,
        };
    }

    fn getContainer(self: @This()) *Game.S.Physics.BodyContainer {
        return &self.ctx.game.physics().container;
    }

    fn getIndex(self: @This()) usize {
        return self.ctx.entity.index;
    }

    pub fn position(self: @This()) Game.Vector {
        const x = self.getContainer().position_x.get(self.getIndex());
        const y = self.getContainer().position_y.get(self.getIndex());

        return .init(x, y);
    }

    pub fn setPosition(self: @This(), new_position: Game.Vector) void {
        self.setPositionX(new_position.x);
        self.setPositionY(new_position.y);
    }

    pub fn setPositionX(self: @This(), new_position_x: f32) void {
        self.getContainer().position_x.set(self.ctx.game.allocator, self.getIndex(), new_position_x, null);
    }

    pub fn setPositionY(self: @This(), new_position_y: f32) void {
        self.getContainer().position_y.set(self.ctx.game.allocator, self.getIndex(), new_position_y, null);
    }

    pub fn velocity(self: @This()) Game.Vector {
        const x = self.getContainer().velocity_x.get(self.getIndex());
        const y = self.getContainer().velocity_y.get(self.getIndex());

        return .init(x, y);
    }

    pub fn setVelocity(self: @This(), new_velocity: Game.Vector) void {
        self.setVelocityX(new_velocity.x);
        self.setVelocityY(new_velocity.y);
    }

    pub fn setVelocityX(self: @This(), new_velocity_x: f32) void {
        self.getContainer().velocity_x.set(self.ctx.game.allocator, self.getIndex(), new_velocity_x, null);
    }

    pub fn setVelocityY(self: @This(), new_velocity_y: f32) void {
        self.getContainer().velocity_y.set(self.ctx.game.allocator, self.getIndex(), new_velocity_y, null);
    }

    pub fn acceleration(self: @This()) Game.Vector {
        const x = self.getContainer().acceleration_x.get(self.getIndex());
        const y = self.getContainer().acceleration_y.get(self.getIndex());

        return .init(x, y);
    }

    pub fn setAcceleration(self: @This(), new_acceleration: Game.Vector) void {
        self.getContainer().acceleration_x.set(self.ctx.game.allocator, self.getIndex(), new_acceleration.x, null);
        self.getContainer().acceleration_y.set(self.ctx.game.allocator, self.getIndex(), new_acceleration.y, null);
    }

    pub fn rotation(self: @This()) f32 {
        return self.getContainer().rotation.get(self.getIndex());
    }

    pub fn setRotation(self: @This(), new_rotation: f32) void {
        self.getContainer().rotation.set(self.ctx.game.allocator, self.getIndex(), new_rotation, null);
    }

    pub fn rotationVelocity(self: @This()) f32 {
        return self.getContainer().rotation_velocity.get(self.getIndex());
    }

    pub fn setRotationVelocity(self: @This(), new_rotation_velocity: f32) void {
        self.getContainer().rotation_velocity.set(self.ctx.game.allocator, self.getIndex(), new_rotation_velocity, null);
    }

    pub fn enableDrag(self: @This()) void {
        self.getContainer().drag_factor.set(self.ctx.game.allocator, self.getIndex(), 1, null);
    }

    pub fn disableDrag(self: @This()) void {
        self.getContainer().drag_factor.set(self.ctx.game.allocator, self.getIndex(), 0, null);
    }
};
