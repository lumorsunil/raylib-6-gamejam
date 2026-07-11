const Game = @import("../game.zig").Game;

pub const Shield = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *Shield, game: *Game) void {
        const player = game.player();
        const player_component = player.get(Game.C.Player);
        var player_shield_it = player_component.shieldIterator();
        while (player_shield_it.next()) |entry| {
            updateShield(game, entry.shield);
        }

        var it = game.entityIterator(.{Game.C.Enemy}, .{});
        while (it.next()) |ctx| {
            const enemy = ctx.get(Game.C.Enemy);
            var enemy_shield_it = enemy.shieldIterator();
            while (enemy_shield_it.next()) |entry| {
                updateShield(game, entry.shield);
            }
        }
    }

    fn updateShield(game: *Game, shield: *Game.C.Item.BodyModShield) void {
        if (shield.regenerate_charge_at <= game.elapsedTime()) {
            game.playSound(.shield_recharge);
            shield.n_charges += 1;
            shield.n_charges = @min(shield.n_charges, shield.charges_max);
            shield.regenerate_charge_at = game.elapsedTime() + shield.regenerate_charge_duration;
        }
    }
};
