const Game = @import("../game.zig").Game;

pub const Animation = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *Animation, game: *Game) void {
        var it = game.entityIterator(.{Game.C.Animation}, .{});

        while (it.next()) |ctx| {
            const animation = ctx.get(Game.C.Animation);
            animation.update(game.elapsedTime());

            if (animation.isDone()) continue;

            const renderable = ctx.getOrAdd(Game.C.Renderable);
            renderable.* = animation.currentFrame();
        }
    }
};
