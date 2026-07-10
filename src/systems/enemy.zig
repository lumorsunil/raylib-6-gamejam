const std = @import("std");
const Game = @import("../game.zig").Game;

const EnemyDef = struct {
    tier: usize,
    weapon: ?Game.C.EnemyWeapon.WeaponType = null,

    pub const n_tiers = 4;

    pub fn init(tier: usize, weapon: ?Game.C.EnemyWeapon.WeaponType) @This() {
        return .{
            .tier = tier,
            .weapon = weapon,
        };
    }

    pub fn noWeapon(tier: usize) @This() {
        return .init(tier, null);
    }

    pub fn merge(prev_tier: usize) @This() {
        const tier = prev_tier + 1;
        return .init(tier, mergeWeapon(tier));
    }

    pub fn tint(self: @This()) Game.Color {
        return switch (self.tier) {
            0 => .green,
            1 => .blue,
            2 => .red,
            3 => .yellow,
            else => .white,
        };
    }

    pub fn health(self: @This()) usize {
        return switch (self.tier) {
            0 => 4,
            1 => 10,
            2 => 20,
            3 => 40,
            else => 1,
        };
    }

    pub fn shardsDropped(self: @This()) usize {
        return switch (self.tier) {
            0 => 4,
            1 => 10,
            2 => 20,
            3 => 40,
            else => 1,
        };
    }

    pub fn velocity(self: @This()) Game.Vector {
        return switch (self.tier) {
            0 => .init(0, 100),
            1 => .init(0, 50),
            2 => .init(0, 25),
            3 => .init(0, 15),
            else => .init(0, 0),
        };
    }

    pub fn mergeWeapon(tier: usize) ?Game.C.EnemyWeapon.WeaponType {
        return switch (tier) {
            0 => null,
            1 => .double_cannon,
            2 => null,
            3 => null,
            else => null,
        };
    }
};

const SpawnDef = union(enum) {
    enemy: EnemyDef,
    group: Group,

    pub fn one(enemy: EnemyDef) @This() {
        return .{ .enemy = enemy };
    }

    pub fn many(enemies: []const Group.GroupEnemy) @This() {
        return .{ .group = .init(enemies) };
    }

    pub const Group = struct {
        enemies: []const GroupEnemy,

        pub fn init(enemies: []const GroupEnemy) @This() {
            return .{ .enemies = enemies };
        }

        pub const GroupEnemy = struct {
            position: Game.Vector,
            velocity: ?Game.Vector,
            def: EnemyDef,

            pub fn init(
                position: Game.Vector,
                velocity: ?Game.Vector,
                def: EnemyDef,
            ) @This() {
                return .{
                    .position = position,
                    .velocity = velocity,
                    .def = def,
                };
            }
        };
    };
};

const WaveDef = struct {
    position: Game.Vector,
    spawns: []const SpawnDef,
    interval: f64,

    pub fn init(
        position: Game.Vector,
        spawns: []const SpawnDef,
        interval: f64,
    ) @This() {
        return .{ .position = position, .spawns = spawns, .interval = interval };
    }

    pub fn totalDuration(self: WaveDef) f64 {
        const len: f64 = @floatFromInt(self.spawns.len);
        return len * self.interval;
    }
};

const Wave = struct {
    def: WaveDef,
    n_spawns_spawned: usize = 0,
    next_spawn_at: f64 = 0,

    pub fn init(def: WaveDef) @This() {
        return .{ .def = def };
    }

    pub fn setup(self: *@This(), t: f64) void {
        self.next_spawn_at = t;
    }

    pub fn shouldSpawn(self: Wave, t: f64) bool {
        if (self.def.spawns.len == 0) return false;
        if (self.n_spawns_spawned >= self.def.spawns.len) return false;
        return self.next_spawn_at <= t;
    }

    pub fn nextSpawn(self: Wave) SpawnDef {
        return self.def.spawns[self.n_spawns_spawned];
    }

    pub fn advance(self: *Wave, t: f64) void {
        self.n_spawns_spawned += 1;
        self.next_spawn_at = t + self.def.interval;
    }

    pub fn totalDuration(self: Wave) f64 {
        return self.def.totalDuration();
    }
};

const Stage = struct {
    waves: []const WaveDef,
    n_waves_spawned: usize = 0,
    next_wave_at: f64 = 0,
    interval: f64,

    pub fn init(waves: []const WaveDef, interval: f64) @This() {
        return .{
            .waves = waves,
            .interval = interval,
            .next_wave_at = waves[0].totalDuration() + interval,
        };
    }

    pub fn setup(self: *@This(), t: f64) void {
        self.next_wave_at = t + self.interval + self.nextWave().totalDuration();
    }

    pub fn shouldAdvance(self: Stage, t: f64) bool {
        return self.next_wave_at <= t;
    }

    pub fn advance(self: *Stage, t: f64) void {
        self.n_waves_spawned += 1;
        if (self.isOver()) return;
        self.setup(t);
    }

    pub fn isOver(self: *Stage) bool {
        return self.n_waves_spawned >= self.waves.len;
    }

    pub fn nextWave(self: Stage) Wave {
        return .init(self.waves[self.n_waves_spawned]);
    }
};

// const at_the_back = -60;
const at_the_back = -0.1;

const stages = [_]Stage{
    // stage_1,
    very_short_stage,
};

const very_short_stage: Stage = .init(&.{
    .init(.init(0, 0), &.{}, 0),
}, 4);

const stage_1: Stage =
    .init(&.{
        .init(.init(0, 0), &.{}, 0),
        .init(.init(0.5, at_the_back), &.{ .one(.noWeapon(0)), .one(.noWeapon(0)), .one(.noWeapon(0)) }, 2),
        .init(.init(0.3, at_the_back), &.{ .one(.init(0, .single_cannon)), .one(.noWeapon(0)), .one(.noWeapon(0)) }, 2),
        .init(.init(0.7, at_the_back), &.{ .one(.noWeapon(0)), .one(.noWeapon(0)), .one(.init(1, .double_cannon)) }, 2),
        .init(.init(100, at_the_back), &.{.many(&.{
            .init(.init(-0.1, at_the_back), .init(50, 50), .init(0, .single_cannon)),
            .init(.init(1.1, at_the_back), .init(-50, 50), .init(0, .single_cannon)),
        })}, 2),
        .init(.init(100, at_the_back), &.{.many(&.{
            .init(.init(0.3, at_the_back), null, .init(1, .double_cannon)),
            .init(.init(0.7, at_the_back), null, .init(1, .double_cannon)),
        })}, 2),
    }, 4);

pub const Enemy = struct {
    current_stage: Stage = stages[0],
    current_stage_index: usize = 0,
    current_wave: Wave = stages[0].nextWave(),

    pub const merge_distance_threshold: f32 = 3;

    pub fn init() @This() {
        return .{};
    }

    pub fn reset(self: *Enemy) void {
        self.current_stage = stages[0];
        self.current_stage_index = 0;
        self.current_wave = stages[0].nextWave();
    }

    pub fn update(self: *Enemy, game: *Game) void {
        self.updateStage(game);
        self.updateHits(game);
        self.updateMerges(game);
        self.updateWeapons(game);
    }

    fn updateStage(self: *Enemy, game: *Game) void {
        const t = game.elapsedTime();

        if (self.current_stage.shouldAdvance(t)) {
            self.advanceStage(game);
        }

        if (self.current_wave.shouldSpawn(t)) {
            self.spawnNext(game);
        }
    }

    fn advanceStage(self: *Enemy, game: *Game) void {
        const t = game.elapsedTime();
        self.current_stage.advance(t);

        if (self.current_stage.isOver()) {
            self.current_stage_index += 1;
            if (self.current_stage_index >= stages.len) {
                // game.ending();
                // return;
                game.shop();
                self.current_stage_index = 0;
            }
            self.current_stage = stages[self.current_stage_index];
        }

        self.current_wave = self.current_stage.nextWave();

        self.setup(game);
    }

    pub fn setup(self: *Enemy, game: *Game) void {
        const t = game.elapsedTime();
        self.current_stage.setup(t);
        self.current_wave.setup(t);
    }

    fn spawnNext(self: *Enemy, game: *Game) void {
        const t = game.elapsedTime();
        const spawn_def = self.current_wave.nextSpawn();
        self.current_wave.advance(t);

        switch (spawn_def) {
            .enemy => |enemy_def| self.spawnByEnemyDef(game, enemy_def, null, null),
            .group => |group| self.spawnGroup(game, group),
        }
    }

    fn spawnByEnemyDef(
        self: *Enemy,
        game: *Game,
        enemy_def: EnemyDef,
        position_override: ?Game.Vector,
        velocity_override: ?Game.Vector,
    ) void {
        const ctx = game.createEntity();
        var position = if (position_override) |p| p else brk: {
            var p = self.current_wave.def.position;
            const wonky_offset = 0.2;
            if (self.current_wave.n_spawns_spawned % 2 == 0) {
                p.x += wonky_offset;
            } else {
                p.x -= wonky_offset;
            }
            break :brk p;
        };
        position = position.multiply(game.worldSize()).add(game.worldPosition());
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        body.velocity = if (velocity_override) |v| v else enemy_def.velocity();
        ctx.add(game.initSprite(.init(127, 5, 31, 17)));
        const renderable = ctx.get(Game.C.Renderable);
        renderable.sprite.tint = enemy_def.tint();
        renderable.sprite.draw_layer = Game.draw_layers.enemy;
        ctx.add(Game.C.Enemy.init(enemy_def.tier, enemy_def.health()));
        if (enemy_def.weapon) |weapon_type| {
            ctx.add(Game.C.EnemyWeapon.init(weapon_type));
        }
        ctx.add(Game.C.DamageOnTouch{ .destroy_source = false });
    }

    fn spawnGroup(self: *Enemy, game: *Game, group: SpawnDef.Group) void {
        for (group.enemies) |enemy| {
            self.spawnByEnemyDef(game, enemy.def, enemy.position, enemy.velocity);
        }
    }

    fn updateHits(_: *Enemy, game: *Game) void {
        var it = game.entityIterator(.{Game.C.Enemy}, .{});

        while (it.next()) |ctx| {
            var proj_it = game.entityIterator(.{Game.C.PlayerProjectile}, .{});
            const hitbox = game.hitbox(ctx);

            while (proj_it.next()) |proj_ctx| {
                const proj_hitbox = game.hitbox(proj_ctx);

                if (hitbox.checkCollision(proj_hitbox)) {
                    hitEnemy(game, ctx, proj_ctx, game.elapsedTime());
                }
            }
        }
    }

    fn hitEnemy(
        game: *Game,
        enemy: Game.EntityContext,
        projectile: Game.EntityContext,
        t: f64,
    ) void {
        projectile.destroy();
        const enemy_component = enemy.get(Game.C.Enemy);
        enemy_component.health -|= 1;
        if (enemy_component.health == 0) {
            const enemy_body = enemy.getConst(Game.C.Body);
            spawnExplosion(game, enemy_body.position);
            spawnShards(game, enemy_component.*, enemy_body.position);
            return enemy.destroy();
        }
        enemy_component.hit_fade_ends_at = t + Game.C.Enemy.hit_fade_duration;
    }

    fn spawnExplosion(game: *Game, position: Game.Vector) void {
        const fade_duration = 0.3;
        const center_scale_per_second = 2;
        const shard_speed = 150;
        const shard_duration = 0.3;

        const center_ctx = game.createEntity();
        center_ctx.add(Game.C.Body.init(position));
        center_ctx.add(game.initSprite(.init(158, 6, 31, 17)));
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

    fn spawnShards(game: *Game, enemy: Game.C.Enemy, position: Game.Vector) void {
        const enemy_def = EnemyDef.init(enemy.tier, null);
        var n_shards = enemy_def.shardsDropped();

        const large_value = Game.C.Shard.Type.large.value();
        const medium_value = Game.C.Shard.Type.medium.value();
        // const small_value = Game.C.Shard.Type.small.value();

        const n_large_max = @divFloor(n_shards, large_value);
        const n_large_min = n_large_max -| 2;
        const n_large = game.random().intRangeAtMost(usize, n_large_min, n_large_max);
        n_shards -= n_large * large_value;

        const n_medium_max = @divFloor(n_shards, medium_value);
        const n_medium_min = n_medium_max -| 2;
        const n_medium = game.random().intRangeAtMost(usize, n_medium_min, n_medium_max);
        n_shards -= n_medium * medium_value;

        const n_small = n_shards;

        for (0..n_large) |_| {
            spawnShard(game, .large, position);
        }

        for (0..n_medium) |_| {
            spawnShard(game, .medium, position);
        }

        for (0..n_small) |_| {
            spawnShard(game, .small, position);
        }
    }

    const shard_speed_variance = 50;
    const shard_speed_min = 150;

    fn spawnShard(game: *Game, shard_type: Game.C.Shard.Type, position: Game.Vector) void {
        const ctx = game.createEntity();
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        const random_speed = game.random().float(f32) * shard_speed_variance + shard_speed_min;
        const r = game.random().float(f32) * std.math.pi * 2;
        const random_vel = Game.Vector.init(random_speed, 0).rotate(r);
        body.velocity = random_vel;
        body.angular_velocity = random_speed;
        const shard = Game.C.Shard.init(shard_type);
        ctx.add(shard);
        ctx.add(shard.renderable(game));
    }

    fn updateMerges(self: *Enemy, game: *Game) void {
        var it = game.entityIterator(.{Game.C.Enemy}, .{});

        outer: while (it.next()) |ctx| {
            const enemy = ctx.getConst(Game.C.Enemy);
            if (enemy.tier == EnemyDef.n_tiers - 1) continue;
            if (enemy.is_merging) continue;

            var other_it = game.entityIterator(.{Game.C.Enemy}, .{});
            const hitbox = game.hitbox(ctx);

            while (other_it.next()) |other_ctx| {
                if (ctx.equals(other_ctx)) continue;

                const other_enemy = other_ctx.getConst(Game.C.Enemy);
                if (other_enemy.tier != enemy.tier) continue;
                if (other_enemy.is_merging) continue;

                const other_hitbox = game.hitbox(other_ctx);

                const d = hitbox.distanceTo(other_hitbox);

                if (d <= merge_distance_threshold) {
                    self.merge(ctx, other_ctx);
                    continue :outer;
                }
            }
        }
    }

    fn merge(self: *Enemy, a: Game.EntityContext, b: Game.EntityContext) void {
        const enemy_a = a.get(Game.C.Enemy);
        const enemy_b = b.get(Game.C.Enemy);

        enemy_a.is_merging = true;
        enemy_b.is_merging = true;

        const body_a = a.getConst(Game.C.Body);
        const body_b = b.getConst(Game.C.Body);

        const world_pos = a.game.worldPosition();
        const world_size = a.game.worldSize();
        const position = body_a.position.lerp(body_b.position, 0.5).subtract(world_pos).divide(world_size);
        const enemy_def: EnemyDef = .merge(enemy_a.tier);

        a.destroy();
        b.destroy();

        self.spawnByEnemyDef(a.game, enemy_def, position, null);
    }

    fn updateWeapons(_: *Enemy, game: *Game) void {
        var it = game.entityIterator(.{ Game.C.Enemy, Game.C.EnemyWeapon }, .{});

        while (it.next()) |ctx| {
            const weapon = ctx.get(Game.C.EnemyWeapon);

            if (weapon.next_shot_at < game.elapsedTime()) {
                shootWeapon(game, ctx, weapon);
            }
        }
    }

    fn shootWeapon(game: *Game, ctx: Game.EntityContext, weapon: *Game.C.EnemyWeapon) void {
        weapon.next_shot_at = game.elapsedTime() + weapon.cooldown();

        const enemy = ctx.getConst(Game.C.Enemy);
        const offset = weapon.offset();
        const body = ctx.getConst(Game.C.Body);
        const position = offset.add(body.position);
        var velocity = body.velocity;
        velocity.x = 0;
        velocity.y = 50 + body.velocity.y;
        const enemy_def = EnemyDef.init(enemy.tier, weapon.weapon_type);

        switch (weapon.weapon_type) {
            .single_cannon => spawnProjectile(game, enemy_def, position, velocity),
            .double_cannon => {
                var p = position;
                const space_between = 20;
                p.x -= space_between / 2;
                spawnProjectile(game, enemy_def, p, velocity);
                p.x += space_between;
                spawnProjectile(game, enemy_def, p, velocity);
            },
        }
    }

    fn spawnProjectile(
        game: *Game,
        enemy_def: EnemyDef,
        position: Game.Vector,
        velocity: Game.Vector,
    ) void {
        const proj_ctx = game.createEntity();
        proj_ctx.add(Game.C.Body.init(position));
        const proj_body = proj_ctx.get(Game.C.Body);
        proj_body.velocity = velocity;
        proj_ctx.add(game.initSprite(.init(36, 39, 5, 11)));
        const sprite = proj_ctx.get(Game.C.Renderable);
        sprite.sprite.tint = enemy_def.tint();
        proj_ctx.add(Game.C.DamageOnTouch{});
    }
};
