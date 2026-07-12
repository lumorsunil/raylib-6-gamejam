const Game = @import("game.zig").Game;

pub const Ending = struct {
    ending_ends_at: f64 = 0,

    const ending_duration = 15;

    pub fn init() @This() {
        return .{};
    }

    pub fn setup(self: *@This(), game: *Game) void {
        self.ending_ends_at = game.elapsedTime() + ending_duration;
    }
};
