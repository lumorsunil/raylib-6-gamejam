const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Enemy = struct {
    // tier: usize = 0,
    max_health: f32 = 1,
    health: f32 = 1,
    hit_fade_ends_at: f64 = 0,
    // is_merging: bool = false,
    body: Body,
    ai: AI,

    pub const hit_fade_duration = 0.2;

    pub fn init(
        body: Body,
        ai_type: AI.AIType,
        max_health: f32,
    ) @This() {
        return .{
            // .tier = tier,
            .max_health = max_health,
            .health = max_health,
            .body = body,
            .ai = .init(ai_type),
        };
    }

    pub fn initRandom(game: *Game, value: usize) !@This() {
        const body = try Body.initRandom(game, value);
        return .init(body, .initRandom(game), body.maxHealth());
    }

    pub fn clone(self: @This(), allocator: std.mem.Allocator) !@This() {
        return .{
            .max_health = self.max_health,
            .health = self.health,
            .hit_fade_ends_at = self.hit_fade_ends_at,
            .body = try self.body.clone(allocator),
            .ai = self.ai,
        };
    }

    pub fn shardsDropped(self: @This()) usize {
        return self.body.shardsDropped();
    }

    pub const WeaponIterator = struct {
        enemy: *Enemy,
        index: ?usize = 0,

        pub fn init(enemy: *Enemy) @This() {
            return .{ .enemy = enemy };
        }

        pub fn next(self: *WeaponIterator) ?WeaponIteratorEntry {
            const index = if (self.index) |*index| index else return null;

            const slots = self.enemy.body.slots;
            for (index.*..slots.len) |i| {
                if (slots[i]) |*item| {
                    if (item.item_type == .weapon) {
                        index.* += 1;
                        return .{
                            .slot_index = i,
                            .item = item,
                            .weapon = &item.item_type.weapon,
                        };
                    }
                }
            }

            self.index = null;
            return null;
        }

        pub const WeaponIteratorEntry = struct {
            slot_index: usize,
            item: *Game.C.Item,
            weapon: *Game.C.Item.Weapon,
        };
    };

    pub fn weaponIterator(self: *Enemy) WeaponIterator {
        return .init(self);
    }

    pub const ShieldIterator = struct {
        enemy: *Enemy,
        index: ?usize = 0,

        pub fn init(enemy: *Enemy) @This() {
            return .{ .enemy = enemy };
        }

        pub fn next(self: *ShieldIterator) ?ShieldIteratorEntry {
            const index = if (self.index) |*index| index else return null;

            const slots = self.enemy.body.slots;
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

    pub fn shieldIterator(self: *Enemy) ShieldIterator {
        return .init(self);
    }

    pub const Body = struct {
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

        pub fn initRandom(game: *Game, value: usize) !@This() {
            std.log.debug("randomizing enemy with {} value", .{value});
            const body_type_all_candidates = comptime brk: {
                var bts: [std.enums.values(BodyType).len]BodyType = undefined;
                for (std.enums.values(BodyType), 0..) |bt, i| {
                    bts[i] = bt;
                }
                std.mem.sort(BodyType, &bts, @as(usize, 0), BodyType.lowestValue);
                break :brk bts;
            };
            var filtered_candidates_len: usize = body_type_all_candidates.len;
            for (body_type_all_candidates, 0..) |c, i| {
                if (c.shardsDropped() > value) {
                    filtered_candidates_len = i;
                    break;
                }
            }
            std.debug.assert(filtered_candidates_len > 0);
            const filtered_candidates = body_type_all_candidates[0..filtered_candidates_len];
            const body_type_i = game.random().uintLessThan(usize, filtered_candidates.len);
            const body_type = filtered_candidates[body_type_i];

            const value_left = value - body_type.shardsDropped();
            std.log.debug("body {t} picked, value left: {}", .{ body_type, value_left });

            const body = try Body.init(game.allocator, body_type);
            const potential_n_items = @min(body.slots.len, @divFloor(value_left, 20));
            std.log.debug("potential_n_items: {}", .{potential_n_items});

            if (potential_n_items > 0) {
                const n_items = if (potential_n_items == 1) 1 else game.random().intRangeLessThan(usize, 1, potential_n_items);
                const item_value = value_left / n_items;

                std.log.debug("n_items: {}", .{n_items});
                std.log.debug("item_value: {}", .{item_value});

                if (n_items > 0) {
                    body.slots[0] = .initRandom(game, item_value, .weapon);
                    std.log.debug("item added with value: {}", .{body.slots[0].?.shardsDropped()});

                    for (1..n_items) |i| {
                        const item_type: std.meta.Tag(Game.C.Item.ItemType) = if (game.random().boolean()) .weapon else .body_mod;
                        body.slots[i] = .initRandom(game, item_value, item_type);
                        std.log.debug("item added with value: {}", .{body.slots[i].?.shardsDropped()});
                    }
                }
            }

            return body;
        }

        pub fn clone(self: @This(), allocator: std.mem.Allocator) !@This() {
            const copy = @This(){
                .slots = try allocator.alloc(?Game.C.Item, self.slots.len),
                .body_type = self.body_type,
            };
            for (copy.slots, self.slots) |*new_slot, old_slot| new_slot.* = old_slot;
            return copy;
        }

        pub fn maxHealth(self: @This()) f32 {
            return switch (self.body_type) {
                .small => 4,
                .medium => 10,
                .large => 20,
            };
        }

        pub fn shardsDropped(self: @This()) usize {
            var sum = self.body_type.shardsDropped();
            for (self.slots) |slot| {
                if (slot) |item| sum += item.shardsDropped();
            }

            return sum;
        }

        pub fn offset(self: @This(), game: *Game, slot_index: usize) Game.Vector {
            const sprite = self.body_type.sprite(game);
            return self.body_type.offset(slot_index).multiply(sprite.size(1, 0)).subtract(sprite.origin(1, 0));
        }

        pub const BodyType = enum {
            small,
            medium,
            large,

            pub fn slots(self: BodyType) usize {
                return switch (self) {
                    .small => 1,
                    .medium => 2,
                    .large => 3,
                };
            }

            pub fn sprite(self: BodyType, game: *Game) Game.C.Renderable {
                return switch (self) {
                    .small => game.initSprite(.init(243, 131, 11, 10)),
                    .medium => game.initSprite(.init(201, 123, 26, 19)),
                    .large => game.initSprite(.init(195, 148, 38, 26)),
                };
            }

            pub fn hitSprite(self: BodyType, game: *Game) Game.C.Renderable {
                return switch (self) {
                    .small => game.initSprite(.init(231, 131, 11, 10)),
                    .medium => game.initSprite(.init(174, 123, 26, 19)),
                    .large => game.initSprite(.init(195, 176, 38, 26)),
                };
            }

            pub fn shardsDropped(self: @This()) usize {
                return switch (self) {
                    .small => 4,
                    .medium => 10,
                    .large => 20,
                };
            }

            pub fn offset(self: BodyType, slot_index: usize) Game.Vector {
                return switch (self) {
                    .small => switch (slot_index) {
                        0 => .init(0.5, 0.5),
                        else => unreachable,
                    },
                    .medium => switch (slot_index) {
                        0 => .init(0.2, 0.63),
                        1 => .init(0.8, 0.63),
                        else => unreachable,
                    },
                    .large => switch (slot_index) {
                        0 => .init(0.3, 0.5),
                        1 => .init(0.7, 0.5),
                        2 => .init(0.5, 0.3),
                        else => unreachable,
                    },
                };
            }

            pub fn lowestValue(_: usize, a: @This(), b: @This()) bool {
                return a.shardsDropped() < b.shardsDropped();
            }
        };
    };

    pub const AI = struct {
        ai_type: AIType,

        pub const AIType = union(enum) {
            straight_line: AIStraightLine,
            // follow_player,

            pub fn initRandom(game: *Game) @This() {
                const tag = game.random().enumValue(std.meta.Tag(AIType));
                return switch (tag) {
                    inline else => |t| @unionInit(AIType, @tagName(t), .init()),
                };
            }
        };

        pub fn init(ai_type: AIType) @This() {
            return .{ .ai_type = ai_type };
        }

        pub fn update(self: *@This(), game: *Game) void {
            switch (self.*) {
                inline else => |*s| s.update(game),
            }
        }

        pub const AIStraightLine = struct {
            pub fn init() @This() {
                return .{};
            }

            pub fn update(self: *@This(), game: *Game) void {
                _ = self;
                _ = game;
            }
        };
    };
};
