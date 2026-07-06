const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Player = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(self: *Player, game: *Game) void {
        const player = game.player();
        const player_component = player.get(Game.C.Player);

        if (player_component.lives == 0) {
            return game.gameOver();
        }

        if (player_component.next_shoot_at <= game.elapsedTime()) {
            player_component.next_shoot_at += player_component.shoot_cooldown;
            self.shoot(game, player);
        }

        var it = game.entityIterator(.{ Game.C.PlayerProjectile, Game.C.Body }, .{});

        while (it.next()) |ctx| {
            if (game.isOutOfBounds(ctx)) {
                ctx.destroy();
            }
        }
    }

    fn shoot(_: *Player, game: *Game, player: Game.EntityContext) void {
        const body = player.getConst(Game.C.Body);
        spawnProjectile(game, body.position);
    }

    fn spawnProjectile(game: *Game, position: Game.Vector) void {
        const ctx = game.createEntity();
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        body.velocity.y = -500;
        ctx.add(Game.C.Renderable.initSprite(game.spritesheet(), .init(28, 38, 7, 13)));
        const sprite = ctx.get(Game.C.Renderable);
        sprite.sprite.tint = .orange;
        ctx.add(Game.C.PlayerProjectile.init(1));
    }
};
