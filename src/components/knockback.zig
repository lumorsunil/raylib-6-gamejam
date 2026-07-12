const Game = @import("../game.zig").Game;

pub const Knockback = struct {
    force: Game.Vector,

    pub fn init(force: Game.Vector) @This() {
        return .{ .force = force };
    }
};
