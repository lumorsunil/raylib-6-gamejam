const Game = @import("../game.zig").Game;

pub const FadeGradient = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *FadeGradient, game: *Game) void {
        var it = game.entityIterator(.{ Game.C.FadeGradient, Game.C.Renderable }, .{});

        while (it.next()) |ctx| {
            const fade_gradient = ctx.getConst(Game.C.FadeGradient);
            const renderable = ctx.get(Game.C.Renderable);

            const alpha = fade_gradient.alpha(game.elapsedTime());
            const new_tint = renderable.sprite.tint.alpha(alpha);
            renderable.sprite.tint = new_tint;
        }
    }
};
