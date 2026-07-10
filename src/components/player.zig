const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Player = struct {
    lives: usize = 3,
    shards: usize = 0,
    body: PlayerBody,
    // base_weapon: PlayerWeapon = .init(.weapon_machine_gun),
    // extra_weapon: ?PlayerWeapon = null,
    // weapon_ctx: Game.EntityContext = undefined,
    destroyed_at: ?f64 = null,
    inventory: Inventory,

    pub const respawn_time = 3;

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .body = try .init(allocator, .two),
            .inventory = try .init(allocator),
        };
    }

    pub fn hit(self: *Player, game: *Game, _: usize) void {
        if (self.destroyed_at) |_| return;
        self.destroyed_at = game.elapsedTime();
        self.lives -= 1;
    }

    pub const WeaponIterator = struct {
        player: *Player,
        index: ?usize = 0,

        pub fn init(player: *Player) @This() {
            return .{ .player = player };
        }

        pub fn next(self: *WeaponIterator) ?WeaponIteratorEntry {
            const index = if (self.index) |*index| index else return null;

            const slots = self.player.body.slots;
            for (index.*..slots.len) |i| {
                if (slots[i]) |*item| {
                    if (item.item_type == .weapon) {
                        index.* += 1;
                        return .{ .slot_index = i, .item = item };
                    }
                }
            }

            self.index = null;
            return null;
        }

        pub const WeaponIteratorEntry = struct {
            slot_index: usize,
            item: *Game.C.Item,
        };
    };

    pub fn weaponIterator(self: *Player) WeaponIterator {
        return .init(self);
    }

    pub const PlayerBody = struct {
        slots: []?Game.C.Item,
        body_type: BodyType,

        pub fn init(allocator: std.mem.Allocator, body_type: BodyType) !@This() {
            const slots = try allocator.alloc(?Game.C.Item, body_type.slots());
            for (slots) |*item| item.* = null;
            return .{
                .slots = slots,
                .body_type = body_type,
            };
        }

        pub fn offset(self: @This(), game: *Game, slot_index: usize) Game.Vector {
            const sprite = self.body_type.sprite(game);
            return self.body_type.offset(slot_index).multiply(sprite.size(1, 0)).subtract(sprite.origin(1, 0));
        }

        pub const BodyType = enum {
            two,
            three,

            pub fn slots(self: BodyType) usize {
                return switch (self) {
                    .two => 2,
                    .three => 3,
                };
            }

            pub fn sprite(self: BodyType, game: *Game) Game.C.Renderable {
                return switch (self) {
                    .two => game.initSprite(.init(186, 47, 31, 27)),
                    .three => game.initSprite(.init(199, 81, 33, 33)),
                };
            }

            pub fn modificationSprite(self: BodyType, game: *Game) Game.C.Renderable {
                return switch (self) {
                    .two => game.initSprite(.init(219, 47, 33, 27)),
                    .three => game.initSprite(.init(199, 81, 33, 33)),
                };
            }

            pub fn offset(self: BodyType, slot_index: usize) Game.Vector {
                return switch (self) {
                    .two => switch (slot_index) {
                        0 => .init(-0.02, 0.63),
                        1 => .init(1.02, 0.63),
                        else => unreachable,
                    },
                    .three => switch (slot_index) {
                        0 => .init(0.3, 0.5),
                        1 => .init(0.7, 0.5),
                        2 => .init(0.5, 0.3),
                        else => unreachable,
                    },
                };
            }
        };
    };

    pub const PlayerWeapon = struct {
        item: Game.C.Item,
        // weapon_type: Type,
        // level: usize = 0,
        next_shoot_at: f64 = 0,
        shoot_cooldown: f64 = 0.3,

        // pub const Type = enum {
        //     machine_gun,
        //
        //     pub fn cooldown(self: Type, level: usize) f64 {
        //         return switch (self) {
        //             .machine_gun => switch (level) {
        //                 0 => 0.1,
        //                 1 => 0.1,
        //                 2 => 0.2,
        //                 else => 0.2,
        //             },
        //         };
        //     }
        //
        //     pub fn levelByShards(self: Type, shards: usize) usize {
        //         return switch (self) {
        //             .machine_gun => {
        //                 if (shards >= 20) return 2;
        //                 if (shards >= 10) return 1;
        //                 return 0;
        //             },
        //         };
        //     }
        //
        //     pub fn weaponSprite(self: Type, level: usize, game: *Game) Game.C.Renderable {
        //         return switch (self) {
        //             .machine_gun => switch (level) {
        //                 0 => game.initSprite(.init(76, 55, 7, 14)),
        //                 1 => game.initSprite(.init(59, 55, 13, 14)),
        //                 2 => game.initSprite(.init(43, 55, 13, 14)),
        //                 else => game.initSprite(.init(76, 55, 7, 14)),
        //             },
        //         };
        //     }
        //
        //     pub fn shoot(self: Type, level: usize, game: *Game, position: Game.Vector) void {
        //         switch (self) {
        //             .machine_gun => switch (level) {
        //                 0 => machineGunShootOne(game, position),
        //                 1 => machineGunShootTwo(game, position),
        //                 2 => machineGunShootTwo(game, position),
        //                 else => {},
        //             },
        //         }
        //     }
        // };

        // fn machineGunSprite(game: *Game) Game.C.Renderable {
        //     var sprite = game.initSprite(.init(57, 39, 3, 8));
        //     sprite.sprite.tint = .sky_blue;
        //     return sprite;
        // }

        // fn machineGunShootOne(game: *Game, position: Game.Vector) void {
        //     const sprite = machineGunSprite(game);
        //     _ = spawnProjectile(game, position, .init(0, -500), sprite);
        // }

        // fn machineGunShootTwo(game: *Game, position: Game.Vector) void {
        //     const sprite = machineGunSprite(game);
        //
        //     var cursor = position;
        //     const space_between = sprite.size(1, 0).x + 8;
        //     cursor.x -= space_between / 2.0;
        //     _ = spawnProjectile(game, cursor, .init(0, -500), sprite);
        //
        //     cursor.x += space_between;
        //     _ = spawnProjectile(game, cursor, .init(0, -500), sprite);
        // }

        // pub fn init(weapon_type: Type) @This() {
        //     return .{ .weapon_type = weapon_type };
        // }

        pub fn init(item: Game.C.Item) @This() {
            return .{ .item = item };
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

    pub const Inventory = struct {
        items: []?Game.C.Item,

        pub const n_items_max = n_item_cols * n_item_rows;
        pub const n_item_cols = 9;
        pub const n_item_rows = 3;

        pub fn init(allocator: std.mem.Allocator) !@This() {
            const items = try allocator.alloc(?Game.C.Item, n_items_max);
            for (items) |*item| item.* = null;
            return .{ .items = items };
        }

        /// Returns false if inventory was full
        pub fn appendItem(
            self: *Inventory,
            new_item: Game.C.Item,
        ) bool {
            for (self.items) |*item| {
                if (item.* == null) {
                    item.* = new_item;
                    return true;
                }
            }

            return false;
        }
    };
};
