const std = @import("std");
const Game = @import("../game.zig").Game;

const EnemyDef = enum {
    tier_one,
    tier_two,
    tier_three,
    tier_four,

    pub const n_tiers = std.meta.tags(@This()).len;

    pub fn tint(self: @This()) Game.Color {
        return switch (self) {
            .tier_one => .green,
            .tier_two => .blue,
            .tier_three => .red,
            .tier_four => .yellow,
        };
    }

    pub fn health(self: @This()) usize {
        return switch (self) {
            .tier_one => 2,
            .tier_two => 5,
            .tier_three => 10,
            .tier_four => 20,
        };
    }

    pub fn velocity(self: @This()) Game.Vector {
        return switch (self) {
            .tier_one => .init(0, 200),
            .tier_two => .init(0, 100),
            .tier_three => .init(0, 80),
            .tier_four => .init(0, 50),
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
            velocity: Game.Vector,
            def: EnemyDef,

            pub fn init(
                position: Game.Vector,
                velocity: Game.Vector,
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

    pub fn shouldAdvance(self: Stage, t: f64) bool {
        return self.next_wave_at <= t;
    }

    pub fn advance(self: *Stage, t: f64) void {
        self.n_waves_spawned += 1;
        self.next_wave_at = t + self.interval + self.nextWave().totalDuration();
    }

    pub fn isOver(self: *Stage) bool {
        return self.n_waves_spawned >= self.waves.len;
    }

    pub fn nextWave(self: Stage) Wave {
        return .init(self.waves[self.n_waves_spawned]);
    }
};

const at_the_back = -60;

const stages = [_]Stage{
    .init(&.{
        // .init(.init(0, 0), &.{}, 0),
        // .init(.init(200, at_the_back), &.{ .one(.tier_one), .one(.tier_one), .one(.tier_one) }, 2),
        // .init(.init(100, at_the_back), &.{ .one(.tier_one), .one(.tier_one), .one(.tier_one) }, 2),
        // .init(.init(300, at_the_back), &.{ .one(.tier_one), .one(.tier_one), .one(.tier_two) }, 2),
        .init(.init(100, at_the_back), &.{.many(&.{
            .init(.init(-100, at_the_back), .init(50, 50), .tier_one),
            .init(.init(505, at_the_back), .init(-50, 50), .tier_one),
        })}, 2),
        .init(.init(0, 0), &.{}, 0),
        .init(.init(0, 0), &.{}, 0),
        .init(.init(0, 0), &.{}, 0),
    }, 4),
};

pub const Enemy = struct {
    enabled: bool = true,
    current_stage: Stage = stages[0],
    current_stage_index: usize = 0,
    current_wave: Wave = stages[0].nextWave(),

    pub const merge_distance_threshold: f32 = 3;

    pub fn init() @This() {
        return .{};
    }

    pub fn update(self: *Enemy, game: *Game) void {
        self.updateStage(game);
        self.updateHits(game);
        self.updateMerges(game);
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
                game.ending();
                return;
            }
            self.current_stage = stages[self.current_stage_index];
        }

        self.current_wave = self.current_stage.nextWave();
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
            const wonky_offset = 32;
            if (self.current_wave.n_spawns_spawned % 2 == 0) {
                p.x += wonky_offset;
            } else {
                p.x -= wonky_offset;
            }
            break :brk p;
        };
        position = position.add(game.worldPosition());
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        body.velocity = if (velocity_override) |v| v else enemy_def.velocity();
        ctx.add(game.initSprite(.init(0, 0, 63, 27)));
        const renderable = ctx.get(Game.C.Renderable);
        renderable.sprite.tint = enemy_def.tint();
        ctx.add(Game.C.Enemy.init(@intFromEnum(enemy_def), enemy_def.health()));
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
                    hitEnemy(ctx, proj_ctx, game.elapsedTime());
                }
            }
        }
    }

    fn hitEnemy(enemy: Game.EntityContext, projectile: Game.EntityContext, t: f64) void {
        projectile.destroy();
        const enemy_component = enemy.get(Game.C.Enemy);
        enemy_component.health -|= 1;
        if (enemy_component.health == 0) {
            return enemy.destroy();
        }
        enemy_component.hit_fade_ends_at = t + Game.C.Enemy.hit_fade_duration;
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
        const position = body_a.position.lerp(body_b.position, 0.5).subtract(world_pos);
        const enemy_def: EnemyDef = @enumFromInt(enemy_a.tier + 1);

        a.destroy();
        b.destroy();

        self.spawnByEnemyDef(a.game, enemy_def, position, null);
    }
};
