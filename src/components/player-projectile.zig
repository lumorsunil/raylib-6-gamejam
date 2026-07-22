pub const PlayerProjectile = struct {
    damage: f32,

    pub fn init(damage: f32) @This() {
        return .{ .damage = damage };
    }
};
