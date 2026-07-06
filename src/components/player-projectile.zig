pub const PlayerProjectile = struct {
    damage: usize,

    pub fn init(damage: usize) @This() {
        return .{ .damage = damage };
    }
};
