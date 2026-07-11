const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Player = struct {
    spawned_explosion: bool = false,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(self: *Player, game: *Game) void {
        const player = game.player();
        const player_component = player.get(Game.C.Player);

        if (player_component.lives == 0) {
            return game.gameOver();
        }

        clampPlayerToWorld(game, player);
        self.updateDeath(game, player, player_component);
        updateWeapons(game, player, player_component);
        destroyOutOfBoundsProjectiles(game);
        pickupShards(game, player, player_component);
    }

    fn updateDeath(
        self: *@This(),
        game: *Game,
        player: Game.EntityContext,
        player_component: *Game.C.Player,
    ) void {
        if (player_component.destroyed_at) |destroyed_at| {
            if (!self.spawned_explosion) {
                spawnExplosion(game, player.getConst(Game.C.Body).position);
                self.spawned_explosion = true;
            }

            if (destroyed_at + Game.C.Player.respawn_time <= game.elapsedTime()) {
                // Respawn
                player_component.destroyed_at = null;
                self.spawned_explosion = false;
                const body = player.get(Game.C.Body);
                body.position = game.worldCenterBottom();
                body.velocity = .init(0, 0);
            } else {
                return;
            }
        }
    }

    fn updateWeapons(
        game: *Game,
        player: Game.EntityContext,
        player_component: *Game.C.Player,
    ) void {
        if (player_component.destroyed_at != null) return;

        var it = player_component.weaponIterator();

        while (it.next()) |entry| {
            updateWeapon(game, entry.item, entry.slot_index, player, player_component);
        }

        // updateWeapon(game, &player_component.base_weapon, player, player_component);
        //
        // if (player_component.extra_weapon) |*extra_weapon| {
        //     updateWeapon(game, extra_weapon, player, player_component);
        // }
    }

    fn updateWeapon(
        game: *Game,
        weapon: *Game.C.Item,
        slot_index: usize,
        player: Game.EntityContext,
        player_component: *Game.C.Player,
    ) void {
        weapon.item_type.weapon.update();

        if (weapon.item_type.weapon.next_shoot_at <= game.elapsedTime()) {
            const body = player.getConst(Game.C.Body);
            const offset = player_component.body.gameplayOffset(game, slot_index);
            const position = body.position.add(offset);
            weapon.item_type.weapon.shoot(game, weapon, position, player, onSpawnProjectile);
        }
    }

    fn onSpawnProjectile(_: Game.EntityContext, ctx: Game.EntityContext) void {
        // TODO: change damage to be based on the item
        ctx.add(Game.C.PlayerProjectile.init(1));
    }

    // fn updateWeapon(
    //     game: *Game,
    //     weapon: *Game.C.Player.PlayerWeapon,
    //     player: Game.EntityContext,
    //     player_component: *Game.C.Player,
    // ) void {
    //     weapon.level = weapon.levelByShards(player_component.shards);
    //     const weapon_renderable = player_component.weapon_ctx.get(Game.C.Renderable);
    //     weapon_renderable.* = weapon.weaponSprite(game);
    //
    //     if (weapon.next_shoot_at <= game.elapsedTime()) {
    //         const body = player.getConst(Game.C.Body);
    //         weapon.shoot(game, body.position);
    //     }
    // }

    fn clampPlayerToWorld(game: *Game, ctx: Game.EntityContext) void {
        const body = ctx.get(Game.C.Body);
        const hitbox = game.hitbox(ctx);
        const world_pos = game.worldPosition();
        const world_size = game.worldSize();
        const min_bounds = world_pos;
        const max_bounds = world_pos.add(world_size);
        const half_size_x = hitbox.size().x * 0.5;
        const half_size_y = hitbox.size().y * 0.5;
        if (hitbox.left() < min_bounds.x) body.position.x = min_bounds.x + half_size_x;
        if (hitbox.right() > max_bounds.x) body.position.x = max_bounds.x - half_size_x;
        if (hitbox.top() < min_bounds.y) body.position.y = min_bounds.y + half_size_y;
        if (hitbox.bottom() > max_bounds.y) body.position.y = max_bounds.y - half_size_y;
    }

    fn destroyOutOfBoundsProjectiles(game: *Game) void {
        var it = game.entityIterator(.{ Game.C.PlayerProjectile, Game.C.Body }, .{});

        while (it.next()) |ctx| {
            if (game.isOutOfBounds(ctx, .allow_bottom)) {
                ctx.destroy();
            }
        }
    }

    fn spawnExplosion(game: *Game, position: Game.Vector) void {
        const fade_duration = 0.6;
        const center_scale_per_second = 2;
        const shard_speed = 100;
        const shard_duration = 0.6;

        const center_ctx = game.createEntity();
        center_ctx.add(Game.C.Body.init(position));
        center_ctx.add(game.initSprite(.init(47, 74, 17, 31)));
        center_ctx.add(Game.C.ScaleGradient.init(center_scale_per_second));
        center_ctx.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        var cursor = Game.Vector.init(193, 7);
        const shard_size = Game.Vector.init(5, 6);

        const shard_0 = game.createEntity();
        shard_0.add(Game.C.Body.init(position));
        var shard_body = shard_0.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(shard_speed, 0).rotate(std.math.pi / 2.0 + std.math.pi / 4.0).multiply(.init(1, -1));
        shard_0.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        cursor.x += 5;
        shard_0.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_0.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        const shard_1 = game.createEntity();
        shard_1.add(Game.C.Body.init(position));
        shard_body = shard_1.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(0, -shard_speed);
        shard_1.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        cursor.x += 5;
        shard_1.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_1.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        const shard_2 = game.createEntity();
        shard_2.add(Game.C.Body.init(position));
        shard_body = shard_2.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(shard_speed, 0).rotate(std.math.pi / 4.0).multiply(.init(1, -1));
        shard_2.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        cursor.x = 193;
        cursor.y += 7;
        shard_2.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_2.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        const shard_3 = game.createEntity();
        shard_3.add(Game.C.Body.init(position));
        shard_body = shard_3.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(shard_speed, 0).rotate(std.math.pi + std.math.pi / 4.0).multiply(.init(1, -1));
        shard_3.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        cursor.x += 5;
        shard_3.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_3.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        const shard_4 = game.createEntity();
        shard_4.add(Game.C.Body.init(position));
        shard_body = shard_4.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(shard_speed, 0).rotate(std.math.pi + 2.0 * std.math.pi / 4.0).multiply(.init(1, -1));
        shard_4.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        cursor.x += 5;
        shard_4.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_4.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));

        const shard_5 = game.createEntity();
        shard_5.add(Game.C.Body.init(position));
        shard_body = shard_5.get(Game.C.Body);
        shard_body.velocity = Game.Vector.init(shard_speed, 0).rotate(std.math.pi + 3.0 * std.math.pi / 4.0).multiply(.init(1, -1));
        shard_5.add(game.initSprite(.init(cursor.x, cursor.y, shard_size.x, shard_size.y)));
        shard_5.add(Game.C.DestroyAt.init(game.elapsedTime() + shard_duration));
        shard_5.add(Game.C.FadeGradient.init(game.elapsedTime(), fade_duration));
    }

    fn pickupShards(
        game: *Game,
        player: Game.EntityContext,
        player_component: *Game.C.Player,
    ) void {
        if (player_component.destroyed_at != null) return;

        var it = game.entityIterator(.{Game.C.Shard}, .{});
        const player_body = player.getConst(Game.C.Body);

        const min_hoover_distance: f32 = 50 * 50;
        const pickup_distance: f32 = 5 * 5;

        while (it.next()) |ctx| {
            const body = ctx.get(Game.C.Body);
            const distance = body.position.distanceSqr(player_body.position);
            const shard = ctx.get(Game.C.Shard);

            if (distance <= pickup_distance) {
                ctx.destroy();
                game.playSound(.pickup_shard);
                player_component.shards += shard.value();
                continue;
            }

            if (distance > min_hoover_distance) {
                shard.enable_drag = true;
                continue;
            }

            shard.enable_drag = false;

            const hoover_ratio = (min_hoover_distance - distance) / min_hoover_distance;
            const hoover_speed = hoover_ratio * 100;

            body.velocity = player_body.position.subtract(body.position).normalize().scale(hoover_speed);
        }
    }
};
