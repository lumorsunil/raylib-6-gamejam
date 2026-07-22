const Game = @import("../game.zig").Game;

pub const ScaleGradient = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *ScaleGradient, game: *Game) void {
        var it = game.entityIterator(.{ Game.C.ScaleGradient, Game.C.Body }, .{});

        while (it.next()) |ctx| {
            const scale_gradient = ctx.getConst(Game.C.ScaleGradient);
            const body = ctx.get(Game.C.Body);

            body.scale += scale_gradient.delta_per_second * game.deltaTime();
        }
    }
};
