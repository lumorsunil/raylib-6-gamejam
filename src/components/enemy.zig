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
    next_basic_shot_at: f64 = basic_shot_cooldown,

    pub const hit_fade_duration = 0.2;
    pub const basic_shot_cooldown = 6;

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

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.body.slots);
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

            const body = try Body.init(game.allocator, body_type);
            const potential_n_items = @min(body.slots.len, @divFloor(value_left, 20));

            if (potential_n_items > 0) {
                const n_items = if (potential_n_items == 1) 1 else game.random().intRangeLessThan(usize, 1, potential_n_items);
                const item_value = value_left / n_items;

                if (n_items > 0) {
                    body.slots[0] = .initRandom(game, item_value, .weapon);

                    for (1..n_items) |i| {
                        const item_type: std.meta.Tag(Game.C.Item.ItemType) = if (game.random().boolean()) .weapon else .body_mod;
                        body.slots[i] = .initRandom(game, item_value, item_type);
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

            pub fn velocity(self: @This()) Game.Vector {
                return switch (self) {
                    .small => .init(0, 75),
                    .medium => .init(0, 50),
                    .large => .init(0, 25),
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
            state_machine: AIStateMachine,

            pub fn initRandom(game: *Game) @This() {
                const tag = game.random().enumValue(std.meta.Tag(AIType));

                return switch (tag) {
                    inline else => |t| @unionInit(AIType, @tagName(t), .initRandom(game)),
                };
            }
        };

        pub fn init(ai_type: AIType) @This() {
            return .{ .ai_type = ai_type };
        }

        pub fn update(self: *@This(), game: *Game, ctx: Game.EntityContext) void {
            switch (self.ai_type) {
                inline else => |*s| s.update(game, ctx),
            }
        }

        pub const AIStateMachine = struct {
            state_machine: Game.C.StateMachine = .init(initialState),

            pub fn init() @This() {
                return .{};
            }

            pub fn initRandom(game: *Game) @This() {
                return .{
                    .state_machine = .init(randomStateMachine(game)),
                };
            }

            pub fn initialState(ctx: Game.C.StateMachineContext) void {
                _ = ctx;
            }

            pub fn update(self: *@This(), _: *Game, ctx: Game.EntityContext) void {
                self.state_machine.state(.init(ctx, &self.state_machine));
            }
        };
    };
};

const AIStateMachineKey = enum {
    straight_line,
    zig_zag,
    follow_player,
    space_invader,
};

fn randomStateMachine(game: *Game) Game.C.StateFunction {
    const key = game.random().enumValue(AIStateMachineKey);

    return switch (key) {
        .straight_line => AIStraightLine.initial,
        .zig_zag => AIZigZag.initial,
        .follow_player => AIFollowPlayer.initial,
        .space_invader => AISpaceInvader.initial,
    };
}

const AIStraightLine = struct {
    pub fn initial(_: Game.C.StateMachineContext) void {}
};

const AIZigZag = struct {
    pub const State = struct {
        change_direction_at: f64 = 0,

        pub const change_duration: f64 = 1;
    };

    pub fn initial(ctx: Game.C.StateMachineContext) void {
        ctx.ctx.add(State{});
        const body = ctx.ctx.get(Game.C.Body);
        body.velocity.x = 25;
        ctx.setState(left);
        ctx.ctx.get(State).change_direction_at = ctx.elapsedTime() + State.change_duration / 2.0;
    }

    pub const left = struct {
        pub fn pre(ctx: Game.C.StateMachineContext) void {
            ctx.ctx.get(State).change_direction_at = ctx.elapsedTime() + State.change_duration;
            const body = ctx.ctx.get(Game.C.Body);
            body.velocity.x *= -1;
        }

        pub fn update(ctx: Game.C.StateMachineContext) void {
            if (ctx.ctx.get(State).change_direction_at <= ctx.elapsedTime()) {
                ctx.setState(right);
            }
        }
    };

    pub const right = struct {
        pub fn pre(ctx: Game.C.StateMachineContext) void {
            ctx.ctx.get(State).change_direction_at = ctx.elapsedTime() + State.change_duration;
            const body = ctx.ctx.get(Game.C.Body);
            body.velocity.x *= -1;
        }

        pub fn update(ctx: Game.C.StateMachineContext) void {
            if (ctx.ctx.get(State).change_direction_at <= ctx.elapsedTime()) {
                ctx.setState(left);
            }
        }
    };
};

const AISpaceInvader = struct {
    pub const State = struct {
        entering_ends_at_y: f32 = 0,
        entering_x_stop: ?f32 = null,
        hover_ends_at: f64 = 0,
    };

    pub fn initial(ctx: Game.C.StateMachineContext) void {
        ctx.ctx.add(State{});
        ctx.setState(entering);
    }

    pub const entering = struct {
        pub fn pre(ctx: Game.C.StateMachineContext) void {
            ctx.ctx.get(State).entering_ends_at_y = 32;
        }

        pub fn update(ctx: Game.C.StateMachineContext) void {
            const body = ctx.ctx.get(Game.C.Body);
            const state = ctx.ctx.get(State);

            if (state.entering_x_stop) |x_stop| {
                if (body.velocity.x < 0) {
                    if (body.position.x <= x_stop) {
                        body.velocity.x = 0;
                        state.entering_x_stop = null;
                    }
                } else if (body.position.x >= x_stop) {
                    body.velocity.x = 0;
                    state.entering_x_stop = null;
                }
            }

            if (body.position.y >= state.entering_ends_at_y) {
                if (collidesWithOtherEnemy(ctx.ctx)) {
                    state.entering_ends_at_y += 32;

                    if (state.entering_x_stop == null) {
                        if (ctx.chance(0.33)) {
                            state.entering_x_stop = body.position.x - 32;
                            body.velocity.x = -64;
                        } else if (ctx.chance(0.50)) {
                            state.entering_x_stop = body.position.x + 32;
                            body.velocity.x = 64;
                        }
                    }
                } else {
                    ctx.setState(hovering);
                }
            }
        }
    };

    fn collidesWithOtherEnemy(ctx: Game.EntityContext) bool {
        var it = ctx.game.entityIterator(.{ Game.C.Body, Game.C.Enemy }, .{});
        const hitbox = ctx.game.hitbox(ctx);

        while (it.next()) |other_ctx| {
            if (ctx.equals(other_ctx)) continue;
            const other_hitbox = ctx.game.hitbox(other_ctx);

            if (hitbox.checkCollision(other_hitbox)) {
                return true;
            }
        }

        return false;
    }

    pub const hovering = struct {
        pub fn pre(ctx: Game.C.StateMachineContext) void {
            ctx.ctx.get(State).hover_ends_at = ctx.elapsedTime() + 6;
            const body = ctx.ctx.get(Game.C.Body);
            body.velocity.y = 0;
            body.velocity.x = 0;
        }

        pub fn update(ctx: Game.C.StateMachineContext) void {
            if (ctx.ctx.get(State).hover_ends_at <= ctx.elapsedTime()) {
                ctx.setState(fall_down);
            }
        }
    };

    pub const fall_down = struct {
        pub fn pre(ctx: Game.C.StateMachineContext) void {
            const enemy = ctx.ctx.get(Game.C.Enemy);
            const body = ctx.ctx.get(Game.C.Body);
            body.velocity = enemy.body.body_type.velocity().scale(1.5);
        }

        pub fn update(_: Game.C.StateMachineContext) void {}
    };
};

const AIFollowPlayer = struct {
    pub fn initial(ctx: Game.C.StateMachineContext) void {
        _ = ctx;
    }
};
