const Game = @import("../game.zig").Game;

pub const Player = struct {
    lives: usize = 3,
    shards: usize = 0,
    base_weapon: PlayerWeapon = .init(.machine_gun),
    extra_weapon: ?PlayerWeapon = null,
    weapon_ctx: Game.EntityContext = undefined,
    destroyed_at: ?f64 = null,

    pub const respawn_time = 3;

    pub fn init() @This() {
        return .{};
    }

    pub fn hit(self: *Player, game: *Game, _: usize) void {
        if (self.destroyed_at) |_| return;
        self.destroyed_at = game.elapsedTime();
        self.lives -= 1;
    }

    pub const PlayerWeapon = struct {
        weapon_type: Type,
        level: usize = 0,
        next_shoot_at: f64 = 0,
        shoot_cooldown: f64 = 0.3,

        pub const Type = enum {
            machine_gun,

            pub fn cooldown(self: Type, level: usize) f64 {
                return switch (self) {
                    .machine_gun => switch (level) {
                        0 => 0.1,
                        1 => 0.1,
                        2 => 0.2,
                        else => 0.2,
                    },
                };
            }

            pub fn levelByShards(self: Type, shards: usize) usize {
                return switch (self) {
                    .machine_gun => {
                        if (shards >= 20) return 2;
                        if (shards >= 10) return 1;
                        return 0;
                    },
                };
            }

            pub fn weaponSprite(self: Type, level: usize, game: *Game) Game.C.Renderable {
                return switch (self) {
                    .machine_gun => switch (level) {
                        0 => game.initSprite(.init(76, 55, 7, 14)),
                        1 => game.initSprite(.init(59, 55, 13, 14)),
                        2 => game.initSprite(.init(43, 55, 13, 14)),
                        else => game.initSprite(.init(76, 55, 7, 14)),
                    },
                };
            }

            pub fn shoot(self: Type, level: usize, game: *Game, position: Game.Vector) void {
                switch (self) {
                    .machine_gun => switch (level) {
                        0 => machineGunShootOne(game, position),
                        1 => machineGunShootTwo(game, position),
                        2 => machineGunShootTwo(game, position),
                        else => {},
                    },
                }
            }
        };

        fn machineGunSprite(game: *Game) Game.C.Renderable {
            var sprite = game.initSprite(.init(57, 39, 3, 8));
            sprite.sprite.tint = .sky_blue;
            return sprite;
        }

        fn machineGunShootOne(game: *Game, position: Game.Vector) void {
            const sprite = machineGunSprite(game);
            _ = spawnProjectile(game, position, .init(0, -500), sprite);
        }

        fn machineGunShootTwo(game: *Game, position: Game.Vector) void {
            const sprite = machineGunSprite(game);

            var cursor = position;
            const space_between = sprite.size(1, 0).x + 8;
            cursor.x -= space_between / 2.0;
            _ = spawnProjectile(game, cursor, .init(0, -500), sprite);

            cursor.x += space_between;
            _ = spawnProjectile(game, cursor, .init(0, -500), sprite);
        }

        pub fn init(weapon_type: Type) @This() {
            return .{ .weapon_type = weapon_type };
        }

        fn spawnProjectile(
            game: *Game,
            position: Game.Vector,
            velocity: Game.Vector,
            sprite: Game.C.Renderable,
        ) Game.EntityContext {
            const ctx = game.createEntity();
            ctx.add(Game.C.Body.init(position));
            const body = ctx.get(Game.C.Body);
            body.velocity = velocity;
            ctx.add(sprite);
            ctx.add(Game.C.PlayerProjectile.init(1));

            return ctx;
        }

        pub fn shoot(self: *@This(), game: *Game, position: Game.Vector) void {
            self.weapon_type.shoot(self.level, game, position);
            self.next_shoot_at = game.elapsedTime() + self.shoot_cooldown;
        }

        pub fn levelByShards(self: @This(), shards: usize) usize {
            return self.weapon_type.levelByShards(shards);
        }

        pub fn weaponSprite(self: @This(), game: *Game) Game.C.Renderable {
            var sprite = self.weapon_type.weaponSprite(self.level, game);
            sprite.sprite.draw_layer = Game.draw_layers.player + 1;
            return sprite;
        }
    };
};
