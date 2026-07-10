const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Item = struct {
    item_type: ItemType,
    tier: usize = 0,

    pub const weapon_machine_gun: Item = .init(.initWeapon(.init(.initMachineGun())));
    pub const weapon_mod_damage: Item = .init(.initWeaponMod(.init(.initDamage())));
    pub const body_mod_shield: Item = .init(.initBodyMod(.init(.initShield())));

    pub fn init(item_type: ItemType) @This() {
        return .{ .item_type = item_type };
    }

    pub fn cost(self: @This()) usize {
        return self.item_type.cost();
    }

    pub fn emptySlotRenderable(game: *Game) Game.C.Renderable {
        return game.initSprite(.init(156, 39, 17, 19));
    }

    pub fn sprite(self: @This(), game: *Game) Game.C.Renderable {
        return switch (self.item_type) {
            inline else => |s| s.sprite(game, self),
        };
    }

    pub fn canMergeWith(self: @This(), other: @This()) bool {
        return switch (self.item_type) {
            .weapon => |s| {
                if (other.item_type == .weapon_mod) return true;
                if (other.item_type != .weapon) return false;
                return s.canMergeWith(other.item_type.weapon, self, other);
            },
            .weapon_mod => {
                return other.item_type == .weapon;
            },
            .body_mod => |s| {
                if (other.item_type != .body_mod) return false;
                return s.canMergeWith(other.item_type.body_mod, self, other);
            },
        };
    }

    pub const MergeEvent = union(enum) {
        destroy: *Item,
    };

    pub fn merge(self: *@This(), other: *@This()) MergeEvent {
        return switch (self.item_type) {
            .weapon => |*s| {
                if (other.item_type == .weapon_mod) {
                    other.item_type.weapon_mod.apply(s);
                    return .{ .destroy = other };
                }
                self.tier += 1;
                return .{ .destroy = other };
            },
            .weapon_mod => |s| {
                s.apply(&other.item_type.weapon);
                return .{ .destroy = self };
            },
            .body_mod => {
                self.tier += 1;
                return .{ .destroy = other };
            },
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        return writer.print("{f}", .{self.item_type});
    }

    pub const ItemType = union(enum) {
        weapon: Weapon,
        weapon_mod: WeaponMod,
        body_mod: BodyMod,

        pub fn initWeapon(weapon: Weapon) @This() {
            return .{ .weapon = weapon };
        }

        pub fn initWeaponMod(weapon_mod: WeaponMod) @This() {
            return .{ .weapon_mod = weapon_mod };
        }

        pub fn initBodyMod(body_mod: BodyMod) @This() {
            return .{ .body_mod = body_mod };
        }

        pub fn cost(self: @This()) usize {
            return switch (self) {
                inline else => |s| s.cost(),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return switch (self) {
                inline else => |s| writer.print("{f}", .{s}),
            };
        }
    };

    pub const Weapon = struct {
        weapon_type: WeaponType,
        weapon_mods: std.ArrayList(Item) = .empty,
        next_shoot_at: f64 = 0,
        shoot_cooldown: f64 = 0.3,

        pub fn init(weapon_type: WeaponType) @This() {
            return .{ .weapon_type = weapon_type };
        }

        pub fn cost(self: @This()) usize {
            var sum = self.weapon_type.cost();
            for (self.weapon_mods.items) |mod| {
                sum += mod.cost();
            }
            return sum;
        }

        pub fn sprite(self: @This(), game: *Game, item: Game.C.Item) Game.C.Renderable {
            return switch (self.weapon_type) {
                inline else => |s| s.sprite(game, item),
            };
        }

        pub fn update(self: *@This()) void {
            const modded_weapon = self.applyMods();
            self.shoot_cooldown = modded_weapon.weapon_type.cooldown();
        }

        pub fn shoot(
            self: *@This(),
            game: *Game,
            item: *Game.C.Item,
            position: Game.Vector,
        ) void {
            self.next_shoot_at = game.elapsedTime() + self.shoot_cooldown;
            switch (self.weapon_type) {
                inline else => |*s| s.shoot(game, item, position),
            }
        }

        pub fn applyMods(self: @This()) @This() {
            var weapon: @This() = self;

            for (self.weapon_mods.items) |mod| {
                mod.item_type.weapon_mod.apply(&weapon);
            }

            return weapon;
        }

        pub fn canMergeWith(self: @This(), other: @This(), item: Item, other_item: Item) bool {
            if (std.meta.activeTag(self.weapon_type) != other.weapon_type) return false;
            if (item.tier >= 2) return false;
            if (item.tier != other_item.tier) return false;
            return true;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("{f}", .{self.weapon_type});
        }
    };

    pub const WeaponType = union(enum) {
        machine_gun: WeaponMachineGun,
        // scatter_shot,
        // railgun,
        // cluster_bomb,

        pub fn initMachineGun() @This() {
            return .{ .machine_gun = .init() };
        }

        pub fn cost(self: @This()) usize {
            return switch (self) {
                inline else => |s| s.cost(),
            };
        }

        pub fn cooldown(self: @This()) f64 {
            return switch (self) {
                inline else => |s| s.cooldown(),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return switch (self) {
                inline else => |s| writer.print("{f}", .{s}),
            };
        }
    };

    pub const WeaponMachineGun = struct {
        n_projectiles: usize = 1,
        shoot_cooldown: f64 = 0.3,
        base_damage: f32 = 1,
        damage_factor: f32 = 1,
        shop_cost: usize = 50,

        pub fn init() @This() {
            return .{};
        }

        pub fn damage(self: WeaponMachineGun) f32 {
            return self.base_damage * self.damage_factor;
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn cooldown(self: @This()) f64 {
            return self.shoot_cooldown;
        }

        pub fn sprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(113, 141, 17, 19)),
                1 => game.initSprite(.init(131, 141, 17, 19)),
                2 => game.initSprite(.init(149, 141, 17, 19)),
                else => unreachable,
            };
        }

        fn machineGunShootOne(self: @This(), game: *Game, item: Item, position: Game.Vector) void {
            _ = spawnProjectile(game, position, .init(0, -500), self.sprite(game, item));
        }

        fn machineGunShootTwo(self: @This(), game: *Game, item: Item, position: Game.Vector) void {
            const sprite_ = self.sprite(game, item);

            var cursor = position;
            const space_between = sprite_.size(1, 0).x + 8;
            cursor.x -= space_between / 2.0;
            _ = spawnProjectile(game, cursor, .init(0, -500), sprite_);

            cursor.x += space_between;
            _ = spawnProjectile(game, cursor, .init(0, -500), sprite_);
        }

        pub fn shoot(self: *@This(), game: *Game, item: *Item, position: Game.Vector) void {
            switch (item.tier) {
                0 => self.machineGunShootOne(game, item.*, position),
                else => self.machineGunShootTwo(game, item.*, position),
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("Weapon: Machine Gun\n\nDamage {d:.2}", .{self.damage()});
        }
    };

    pub const WeaponMod = struct {
        weapon_mod_type: WeaponModType,

        pub fn init(weapon_mod_type_: WeaponModType) @This() {
            return .{ .weapon_mod_type = weapon_mod_type_ };
        }

        pub fn cost(self: @This()) usize {
            return self.weapon_mod_type.cost();
        }

        pub fn sprite(self: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (self.weapon_mod_type) {
                inline else => |s| s.sprite(game, item),
            };
        }

        pub fn apply(self: @This(), weapon: *Weapon) void {
            self.applyToWeaponType(&weapon.weapon_type);
        }

        fn applyToWeaponType(self: @This(), weapon_type: *WeaponType) void {
            switch (self.weapon_mod_type) {
                inline else => |s| s.apply(weapon_type),
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("{f}", .{self.weapon_mod_type});
        }
    };

    pub const WeaponModType = union(enum) {
        damage: WeaponModDamage,
        // rate_of_fire,
        // projectiles,

        pub fn initDamage() @This() {
            return .{ .damage = .init() };
        }

        pub fn cost(self: @This()) usize {
            return switch (self) {
                inline else => |s| s.cost(),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return switch (self) {
                inline else => |s| writer.print("{f}", .{s}),
            };
        }
    };

    pub const WeaponModDamage = struct {
        damage_factor: f32 = 0.2,
        shop_cost: usize = 30,

        pub fn init() @This() {
            return .{};
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn sprite(_: @This(), game: *Game, _: Item) Game.C.Renderable {
            return game.initSprite(.init(95, 143, 17, 19));
        }

        pub fn apply(self: @This(), weapon_type: *WeaponType) void {
            switch (weapon_type.*) {
                inline else => |*s| {
                    if (@hasField(@TypeOf(s.*), "damage_factor")) {
                        s.damage_factor += self.damage_factor;
                    }
                },
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("Weapon Mod: Damage\n\nDamage +{d:.0}%", .{self.damage_factor * 100});
        }
    };

    pub const BodyMod = struct {
        body_mod_type: BodyModType,

        pub fn init(body_mod_type_: BodyModType) @This() {
            return .{ .body_mod_type = body_mod_type_ };
        }

        pub fn cost(self: @This()) usize {
            return self.body_mod_type.cost();
        }

        pub fn sprite(self: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (self.body_mod_type) {
                inline else => |s| s.sprite(game, item),
            };
        }

        pub fn canMergeWith(self: @This(), other: @This(), item: Item, other_item: Item) bool {
            if (std.meta.activeTag(self.body_mod_type) != other.body_mod_type) return false;
            if (item.tier >= 2) return false;
            if (item.tier != other_item.tier) return false;
            return true;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("{f}", .{self.body_mod_type});
        }
    };

    pub const BodyModType = union(enum) {
        shield: BodyModShield,
        // evasion,

        pub fn initShield() @This() {
            return .{ .shield = .init() };
        }

        pub fn cost(self: @This()) usize {
            return switch (self) {
                inline else => |s| s.cost(),
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return switch (self) {
                inline else => |s| writer.print("{f}", .{s}),
            };
        }
    };

    pub const BodyModShield = struct {
        charges_max: usize = 1,
        regenerate_charge_duration: f64 = 3,
        n_charges: usize = 1,
        shop_cost: usize = 70,

        pub fn init() @This() {
            return .{};
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn sprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(113, 121, 17, 19)),
                1 => game.initSprite(.init(131, 121, 17, 19)),
                2 => game.initSprite(.init(149, 121, 17, 19)),
                else => unreachable,
            };
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("Body Mod: Shield\n\nCharges max: {}\nRegenerate duration: {d:.2}s", .{
                self.charges_max,
                self.regenerate_charge_duration,
            });
        }
    };
};

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
