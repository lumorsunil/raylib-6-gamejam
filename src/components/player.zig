pub const Player = struct {
    lives: usize = 3,
    next_shoot_at: f64 = 0,
    shoot_cooldown: f64 = 0.6,

    pub fn init() @This() {
        return .{};
    }
};
