pub const GameOver = struct {
    transition_at: f64,

    pub const game_over_duration = 4;

    pub fn init(t: f64) @This() {
        return .{ .transition_at = t + game_over_duration };
    }
};
