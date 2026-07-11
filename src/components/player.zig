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
    invincibility_ends_at: f64 = 0,
    inventory: Inventory,

    pub const respawn_time = 3;
    pub const grace_period_duration = 1;

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .body = try .init(allocator, .two),
            .inventory = try .init(allocator),
        };
    }

    pub fn hit(self: *Player, game: *Game, _: usize) void {
        if (self.destroyed_at) |_| return;

        if (self.invincibility_ends_at > game.elapsedTime()) {
            return;
        }

        var shield_it = self.shieldIterator();

        while (shield_it.next()) |entry| {
            if (entry.shield.n_charges > 0) {
                entry.shield.n_charges -= 1;
                entry.shield.regenerate_charge_at = game.elapsedTime() + entry.shield.regenerate_charge_duration;
                self.invincibility_ends_at = game.elapsedTime() + grace_period_duration;
                game.playSound(.shield_hit);
                return;
            }
        }

        game.playSound(.player_explosion);
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

    pub const ShieldIterator = struct {
        player: *Player,
        index: ?usize = 0,

        pub fn init(player: *Player) @This() {
            return .{ .player = player };
        }

        pub fn next(self: *ShieldIterator) ?ShieldIteratorEntry {
            const index = if (self.index) |*index| index else return null;

            const slots = self.player.body.slots;
            for (index.*..slots.len) |i| {
                if (slots[i]) |*item| {
                    if (item.item_type == .body_mod and item.item_type.body_mod.body_mod_type == .shield) {
                        index.* += 1;
                        return .{
                            .slot_index = i,
                            .item = item,
                            .shield = &item.item_type.body_mod.body_mod_type.shield,
                        };
                    }
                }
            }

            self.index = null;
            return null;
        }

        pub const ShieldIteratorEntry = struct {
            slot_index: usize,
            item: *Game.C.Item,
            shield: *Game.C.Item.BodyModShield,
        };
    };

    pub fn shieldIterator(self: *Player) ShieldIterator {
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

        pub fn gameplayOffset(self: @This(), game: *Game, slot_index: usize) Game.Vector {
            const sprite = self.body_type.sprite(game);
            return self.body_type.gameplayOffset(slot_index).multiply(sprite.size(1, 0)).subtract(sprite.origin(1, 0));
        }

        pub fn equipOffset(self: @This(), game: *Game, slot_index: usize) Game.Vector {
            const sprite = self.body_type.sprite(game);
            return self.body_type.equipOffset(slot_index).multiply(sprite.size(1, 0)).subtract(sprite.origin(1, 0));
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

            pub fn gameplayOffset(self: BodyType, slot_index: usize) Game.Vector {
                return switch (self) {
                    .two => switch (slot_index) {
                        0 => .init(0.1, 0.63),
                        1 => .init(0.9, 0.63),
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

            pub fn equipOffset(self: BodyType, slot_index: usize) Game.Vector {
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
