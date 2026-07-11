const std = @import("std");
const Game = @import("../game.zig").Game;

const EnemyDef = struct {
    // tier: usize,
    body: Game.C.Enemy.Body,
    ai_type: Game.C.Enemy.AI.AIType,
    // weapon: ?Game.C.EnemyWeapon.WeaponType = null,

    // pub const n_tiers = 4;

    pub fn init(body: Game.C.Enemy.Body, ai_type: Game.C.Enemy.AI.AIType) @This() {
        return .{ .body = body, .ai_type = ai_type };
    }

    pub fn initRandom(game: *Game, value: usize) !@This() {
        const enemy = try Game.C.Enemy.initRandom(game, value);
        return .init(enemy.body, enemy.ai.ai_type);
    }

    pub fn clone(self: @This(), allocator: std.mem.Allocator) !@This() {
        return .{
            .body = try self.body.clone(allocator),
            .ai_type = self.ai_type,
        };
    }

    pub fn health(self: @This()) f32 {
        return switch (self.body.body_type) {
            .small => 4,
            .medium => 10,
            .large => 20,
        };
    }

    pub fn velocity(self: @This()) Game.Vector {
        return switch (self.body.body_type) {
            .small => .init(0, 75),
            .medium => .init(0, 50),
            .large => .init(0, 25),
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Value: {}\n", .{Game.C.Enemy.init(self.body, self.ai_type, 0).shardsDropped()});
        try writer.print("Body Type: {t}\n", .{self.body.body_type});
        try writer.print("AI Type: {t}\n", .{self.ai_type});
        try writer.print("Items: \n", .{});

        for (self.body.slots, 0..) |slot, i| {
            if (slot) |item| {
                try writer.print("Item {}:\n", .{i});
                try writer.print("Item Type: {t}\n", .{item.item_type});
                try writer.print("Item Tier: {}\n", .{item.tier});
                try writer.print("Item Value: {}\n\n", .{item.shardsDropped()});
            }
        }
    }
};

const SpawnDef = union(enum) {
    enemy: EnemyDef,
    group: Group,

    pub fn initRandom(game: *Game, value: usize) !@This() {
        if (game.random().float(f32) > 0.2) {
            return .{ .enemy = try .initRandom(game, value) };
        } else {
            return .{ .group = try .initRandom(game, value) };
        }
    }

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

        pub fn initRandom(game: *Game, value: usize) !@This() {
            const n_enemies = game.random().intRangeAtMost(usize, 2, 4);
            const enemies = try game.allocator.alloc(GroupEnemy, n_enemies);
            const x_step: f32 = 1.0 / @as(f32, @floatFromInt(n_enemies + 1));

            const same_enemy = if (game.random().boolean()) null else try EnemyDef.initRandom(game, value);

            for (enemies, 0..) |*enemy, i| {
                const fi: f32 = @floatFromInt(i);
                const position = Game.Vector.init(x_step * (fi + 1), 0);
                const enemy_def: EnemyDef = same_enemy orelse try .initRandom(game, value);
                enemy.* = .init(position, null, enemy_def.clone(game.allocator) catch unreachable);
            }

            return .init(enemies);
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

            pub fn format(
                self: @This(),
                writer: *std.Io.Writer,
            ) std.Io.Writer.Error!void {
                try writer.print("Group Position: {},{}\n", .{ self.position.x, self.position.y });
                try writer.print("Group Enemy:\n{f}", .{self.def});
            }
        };

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("# Enemies: {}\n", .{self.enemies.len});
            for (self.enemies, 0..) |enemy, i| {
                try writer.print("Enemy {}:\n{f}\n\n", .{ i, enemy });
            }
        }
    };

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        switch (self) {
            .enemy => |enemy| try writer.print("One {f}", .{enemy}),
            .group => |group| try writer.print("Group:\n{f}", .{group}),
        }
    }
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

    pub fn initRandom(game: *Game, value: usize) !@This() {
        const lanes = [_]Game.Vector{
            .init(0.25, 0),
            .init(0.5, 0),
            .init(0.75, 0),
        };
        const lane_i = game.random().uintLessThan(usize, lanes.len);
        const lane = lanes[lane_i];

        const interval = game.random().float(f32) * 1.8 + 0.2;

        const n_spawns = game.random().intRangeAtMost(usize, 3, 10);
        const spawns = try game.allocator.alloc(SpawnDef, n_spawns);

        for (spawns) |*spawn| spawn.* = try .initRandom(game, value);

        return .init(lane, spawns, interval);
    }

    pub fn totalDuration(self: WaveDef) f64 {
        const len: f64 = @floatFromInt(self.spawns.len);
        return len * self.interval;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Position: {},{}\nInterval: {}\nSpawns: {}\n", .{
            self.position.x, self.position.y,
            self.interval,   self.spawns.len,
        });

        for (self.spawns, 0..) |spawn, i| {
            try writer.print("Spawn {}:\n{f}\n\n", .{ i, spawn });
        }
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
        self.n_spawns_spawned = 0;
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
    starting_value: usize,

    pub fn init(waves: []const WaveDef, interval: f64, starting_value: usize) @This() {
        return .{
            .waves = waves,
            .interval = interval,
            .next_wave_at = waves[0].totalDuration() + interval,
            .starting_value = starting_value,
        };
    }

    pub fn initRandom(game: *Game, starting_value: usize) !@This() {
        std.log.debug("randomizing stage with value {}", .{starting_value});
        const n_waves = 1;

        const waves = try game.allocator.alloc(WaveDef, n_waves);
        for (waves, 0..) |*wave, i| {
            const easy_wave = starting_value;
            const moderate_wave: usize = @intFromFloat(@as(f32, @floatFromInt(starting_value)) * 1.5);
            const difficult_wave = starting_value * 2;
            const wave_difficulty = if (i == 5 or i == 9) difficult_wave else if (i < 5) easy_wave else moderate_wave;
            wave.* = try .initRandom(game, wave_difficulty);
        }

        return .init(waves, 4, starting_value);
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

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Stage\n{} Waves\n{} Starting Value\n\n", .{ self.waves.len, self.starting_value });
        for (self.waves, 0..) |wave, i| {
            try writer.print("Wave {}: \n{f}\n\n", .{ i + 1, wave });
        }
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

fn createBody(
    allocator: std.mem.Allocator,
    body_type: Game.C.Enemy.Body.BodyType,
) Game.C.Enemy.Body {
    return .init(allocator, body_type);
}

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
    // current_stage: Stage = stages[0],
    // current_stage_index: usize = 0,
    // current_wave: Wave = stages[0].nextWave(),
    current_stage: Stage = undefined,
    current_stage_index: usize = 0,
    current_wave: Wave = undefined,
    current_value: usize = initial_value,

    pub const initial_value = 5;
    pub const merge_distance_threshold: f32 = 3;
    pub const max_stages = 3;

    pub fn init() @This() {
        return .{};
    }

    pub fn nextStage(self: *@This(), game: *Game) !void {
        self.current_stage = try .initRandom(game, self.current_value);
        std.log.debug("{f}", .{self.current_stage});
        self.current_wave = self.current_stage.nextWave();
        self.current_value += 10;
        self.current_stage_index += 1;
    }

    pub fn reset(self: *Enemy, game: *Game) !void {
        try self.nextStage(game);
        self.current_stage_index = 0;
        self.current_value = initial_value;
    }

    pub fn update(self: *Enemy, game: *Game) void {
        self.updateStage(game);
        self.updateHits(game);
        self.updateWeapons(game);
        self.updateRemoveOutOfBounds(game);
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
            if (self.current_stage_index >= max_stages) {
                game.ending();
                return;
            } else {
                game.shop();
                return;
            }
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
            const p = self.current_wave.def.position;
            // var p = self.current_wave.def.position;
            // const wonky_offset = 0.2;
            // if (self.current_wave.n_spawns_spawned % 2 == 0) {
            //     p.x += wonky_offset;
            // } else {
            //     p.x -= wonky_offset;
            // }
            break :brk p;
        };
        position = game.getAbsolutePos(position);
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        body.velocity = if (velocity_override) |v| v else enemy_def.velocity();
        body.rotation = std.math.pi;
        ctx.add(Game.C.Enemy.init(enemy_def.body, enemy_def.ai_type, enemy_def.health()));
        const enemy = ctx.get(Game.C.Enemy);
        var renderable = enemy.body.body_type.sprite(game);
        renderable.sprite.draw_layer = Game.draw_layers.enemy;
        ctx.add(renderable);
        // if (enemy_def.weapon) |weapon_type| {
        //     ctx.add(Game.C.EnemyWeapon.init(weapon_type));
        // }
        ctx.add(Game.C.DamageOnTouch{ .destroy_source = false });
        var weapon_it = enemy.weaponIterator();
        var weapon_rof_debuff = Game.C.Item.init(.initWeaponMod(.init(.initRateOfFire())));
        weapon_rof_debuff.item_type.weapon_mod.weapon_mod_type.rate_of_fire.rate_of_fire_factor = -0.5;
        var weapon_ps_debuff = Game.C.Item.init(.initWeaponMod(.init(.initProjectileSpeed())));
        weapon_ps_debuff.item_type.weapon_mod.weapon_mod_type.projectile_speed.projectile_speed_factor = -0.8;

        while (weapon_it.next()) |entry| {
            entry.weapon.weapon_mods.append(game.allocator, weapon_rof_debuff) catch unreachable;
            entry.weapon.weapon_mods.append(game.allocator, weapon_ps_debuff) catch unreachable;
        }
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
        enemy_component.health -= 1;
        game.playSound(.enemy_hit);
        if (enemy_component.health <= 0) {
            const enemy_body = enemy.getConst(Game.C.Body);
            spawnExplosion(game, enemy_body.position);
            spawnShards(game, enemy_component.*, enemy_body.position);
            game.playSound(.enemy_explosion);
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
        var n_shards = enemy.shardsDropped();

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

    fn updateWeapons(_: *Enemy, game: *Game) void {
        var it = game.entityIterator(.{Game.C.Enemy}, .{});

        while (it.next()) |ctx| {
            const enemy = ctx.get(Game.C.Enemy);

            var weapon_it = enemy.weaponIterator();
            while (weapon_it.next()) |entry| {
                updateWeapon(game, entry.item, entry.slot_index, ctx, enemy);
            }
        }

        // var it = game.entityIterator(.{ Game.C.Enemy, Game.C.EnemyWeapon }, .{});
        //
        // while (it.next()) |ctx| {
        //     const weapon = ctx.get(Game.C.EnemyWeapon);
        //
        //     if (weapon.next_shot_at < game.elapsedTime()) {
        //         shootWeapon(game, ctx, weapon);
        //     }
        // }
    }

    fn updateWeapon(
        game: *Game,
        weapon: *Game.C.Item,
        slot_index: usize,
        enemy: Game.EntityContext,
        enemy_component: *Game.C.Enemy,
    ) void {
        weapon.item_type.weapon.update();

        if (weapon.item_type.weapon.next_shoot_at <= game.elapsedTime()) {
            const body = enemy.getConst(Game.C.Body);
            const offset = enemy_component.body.offset(game, slot_index);
            const position = body.position.add(offset);
            weapon.item_type.weapon.shoot(game, weapon, position, enemy, onSpawnProjectile);
        }
    }

    fn onSpawnProjectile(enemy_ctx: Game.EntityContext, ctx: Game.EntityContext) void {
        ctx.add(Game.C.DamageOnTouch{});
        const body = ctx.get(Game.C.Body);
        body.velocity.y *= -1;
        const enemy_body = enemy_ctx.get(Game.C.Body);
        body.velocity = body.velocity.add(enemy_body.velocity);
        body.rotation = std.math.pi;
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

    fn updateRemoveOutOfBounds(_: *Enemy, game: *Game) void {
        var it = game.entityIterator(.{ Game.C.Enemy, Game.C.Body }, .{});

        while (it.next()) |ctx| {
            if (game.isOutOfBounds(ctx, .allow_top)) {
                ctx.destroy();
            }
        }

        var proj_it = game.entityIterator(.{ Game.C.DamageOnTouch, Game.C.Body }, .{});

        while (proj_it.next()) |ctx| {
            if (game.isOutOfBounds(ctx, .allow_top)) {
                ctx.destroy();
            }
        }
    }
};
