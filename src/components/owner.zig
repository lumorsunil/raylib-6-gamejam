const Game = @import("../game.zig").Game;

pub const Owner = struct {
    owner: Game.EntityContext,

    pub fn init(owner: Game.EntityContext) @This() {
        return .{ .owner = owner };
    }
};
