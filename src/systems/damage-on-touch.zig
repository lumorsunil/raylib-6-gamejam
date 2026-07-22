const Game = @import("../game.zig").Game;

pub const DamageOnTouch = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *DamageOnTouch, game: *Game) void {
        const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
        defer zone.end();

        var it = game.entityIterator(.{ Game.C.Body, Game.C.DamageOnTouch }, .{});
        const player = game.player();
        const player_hitbox = game.hitbox(player);

        while (it.next()) |ctx| {
            const hitbox = game.hitbox(ctx);
            const dot = ctx.getConst(Game.C.DamageOnTouch);

            if (hitbox.checkCollision(player_hitbox)) {
                const player_component = player.get(Game.C.Player);
                player_component.hit(game, dot.damage);

                if (dot.destroy_source) {
                    ctx.destroy();
                }
            }
        }
    }
};
