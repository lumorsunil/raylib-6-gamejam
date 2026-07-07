const Game = @import("../game.zig").Game;

pub const Player = struct {
    lives: usize = 3,
    next_shoot_at: f64 = 0,
    shoot_cooldown: f64 = 0.3,
    destroyed_at: ?f64 = null,

    pub const respawn_time = 3;

    pub fn init() @This() {
        return .{};
    }

    pub fn hit(self: *Player, game: *Game, _: usize) void {
        if (self.destroyed_at) |_| return;
        self.destroyed_at = game.elapsedTime();
        self.lives -= 1;
    }
};
