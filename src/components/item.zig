const std = @import("std");
const Game = @import("../game.zig").Game;

pub const Item = struct {
    item_type: ItemType,
    tier: usize = 0,
    owner: ?Game.EntityContext = null,

    pub const weapon_machine_gun: Item = .init(.initWeapon(.init(.initMachineGun(0))));
    pub const weapon_scatter_shot: Item = .init(.initWeapon(.init(.initScatterShot(0))));
    pub const weapon_mod_damage: Item = .init(.initWeaponMod(.init(.initDamage())));
    pub const body_mod_shield: Item = .init(.initBodyMod(.init(.initShield(0))));

    pub fn init(item_type: ItemType) @This() {
        return .{ .item_type = item_type };
    }

    pub fn initRandom(
        game: *Game,
        value: usize,
        item_type: std.meta.Tag(ItemType),
    ) @This() {
        const tier = @min(2, @divFloor(value, 20));

        return switch (item_type) {
            .weapon => initRandomWeapon(game, tier),
            .weapon_mod => initRandomWeaponMod(game),
            .body_mod => initRandomBodyMod(game, tier),
        };
    }

    pub fn initRandomWeapon(game: *Game, tier: usize) @This() {
        const weapon_type = game.random().enumValue(std.meta.Tag(WeaponType));
        var item: @This() = .init(.{ .weapon = .init(switch (weapon_type) {
            inline else => |t| @unionInit(WeaponType, @tagName(t), .init(tier)),
        }) });
        item.tier = tier;
        return item;
    }

    pub fn initRandomWeaponMod(game: *Game) @This() {
        const weapon_mod_type = game.random().enumValue(std.meta.Tag(WeaponModType));
        return .init(.{ .weapon_mod = .init(switch (weapon_mod_type) {
            inline else => |t| @unionInit(WeaponModType, @tagName(t), .init()),
        }) });
    }

    pub fn initRandomBodyMod(game: *Game, tier: usize) @This() {
        const body_mod_type = game.random().enumValue(std.meta.Tag(BodyModType));
        var item: @This() = .init(.{ .body_mod = .init(switch (body_mod_type) {
            inline else => |t| @unionInit(BodyModType, @tagName(t), .init(tier)),
        }) });
        item.tier = tier;
        return item;
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

    pub fn shardsDropped(self: @This()) usize {
        return (self.tier + 1) * 20;
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
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            var modded_weapon = self.applyMods();
            self.next_shoot_at = game.elapsedTime() + modded_weapon.weapon_type.cooldown();
            switch (modded_weapon.weapon_type) {
                inline else => |*s| s.shoot(game, item, position, context, onSpawnProjectile),
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
        scatter_shot: WeaponScatterShot,
        // railgun,
        // cluster_bomb,

        pub fn initMachineGun(tier: usize) @This() {
            return .{ .machine_gun = .init(tier) };
        }

        pub fn initScatterShot(tier: usize) @This() {
            return .{ .scatter_shot = .init(tier) };
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
        rate_of_fire_factor: f32 = 1,
        projectile_speed_factor: f32 = 1,
        shop_cost: usize = 50,

        pub fn init(tier: usize) @This() {
            return switch (tier) {
                0 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.3,
                    .base_damage = 1,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 50,
                },
                1 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.25,
                    .base_damage = 2,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 100,
                },
                2 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.20,
                    .base_damage = 3,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 150,
                },
                else => unreachable,
            };
        }

        pub fn damage(self: WeaponMachineGun) f32 {
            return self.base_damage * self.damage_factor;
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn cooldown(self: @This()) f64 {
            return self.shoot_cooldown / self.rate_of_fire_factor;
        }

        pub fn sprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(113, 141, 17, 19)),
                1 => game.initSprite(.init(131, 141, 17, 19)),
                2 => game.initSprite(.init(149, 141, 17, 19)),
                else => unreachable,
            };
        }

        pub fn projectileSprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(121, 160, 1, 8)),
                1 => game.initSprite(.init(138, 160, 3, 8)),
                2 => game.initSprite(.init(155, 160, 5, 11)),
                else => unreachable,
            };
        }

        fn projectileVelocity(self: @This()) Game.Vector {
            return .init(0, -500 * self.projectile_speed_factor);
        }

        fn machineGunShootOne(
            self: @This(),
            game: *Game,
            item: Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            const velocity = self.projectileVelocity();
            _ = spawnProjectile(
                game,
                position,
                velocity,
                self.projectileSprite(game, item),
                context,
                onSpawnProjectile,
            );
        }

        fn machineGunShootTwo(
            self: @This(),
            game: *Game,
            item: Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            const sprite_ = self.projectileSprite(game, item);
            const velocity = self.projectileVelocity();

            var cursor = position;
            const space_between = sprite_.size(1, 0).x + 8;
            cursor.x -= space_between / 2.0;
            _ = spawnProjectile(game, cursor, velocity, sprite_, context, onSpawnProjectile);

            cursor.x += space_between;
            _ = spawnProjectile(game, cursor, velocity, sprite_, context, onSpawnProjectile);
        }

        pub fn shoot(
            self: *@This(),
            game: *Game,
            item: *Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            game.playSound(.machine_gun);
            switch (item.tier) {
                0 => self.machineGunShootOne(game, item.*, position, context, onSpawnProjectile),
                1 => self.machineGunShootOne(game, item.*, position, context, onSpawnProjectile),
                2 => self.machineGunShootOne(game, item.*, position, context, onSpawnProjectile),
                else => self.machineGunShootTwo(game, item.*, position, context, onSpawnProjectile),
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("Weapon: Machine Gun\n\nDamage {d:.2}", .{self.damage()});
        }
    };

    pub const WeaponScatterShot = struct {
        n_projectiles: usize = 1,
        shoot_cooldown: f64 = 0.35,
        base_damage: f32 = 1,
        damage_factor: f32 = 1,
        rate_of_fire_factor: f32 = 1,
        projectile_speed_factor: f32 = 1,
        shop_cost: usize = 50,

        pub fn init(tier: usize) @This() {
            return switch (tier) {
                0 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.35,
                    .base_damage = 1,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 50,
                },
                1 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.30,
                    .base_damage = 2,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 100,
                },
                2 => .{
                    .n_projectiles = 1,
                    .shoot_cooldown = 0.25,
                    .base_damage = 3,
                    .damage_factor = 1,
                    .rate_of_fire_factor = 1,
                    .projectile_speed_factor = 1,
                    .shop_cost = 150,
                },
                else => unreachable,
            };
        }

        pub fn damage(self: @This()) f32 {
            return self.base_damage * self.damage_factor;
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn cooldown(self: @This()) f64 {
            return self.shoot_cooldown / self.rate_of_fire_factor;
        }

        pub fn sprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(173, 227, 17, 19)),
                1 => game.initSprite(.init(197, 227, 17, 19)),
                2 => game.initSprite(.init(226, 227, 17, 19)),
                else => unreachable,
            };
        }

        pub fn projectileSprite(_: @This(), game: *Game, item: Item) Game.C.Renderable {
            return switch (item.tier) {
                0 => game.initSprite(.init(121, 160, 1, 8)),
                1 => game.initSprite(.init(138, 160, 3, 8)),
                2 => game.initSprite(.init(155, 160, 5, 11)),
                else => unreachable,
            };
        }

        fn projectileVelocity(self: @This()) Game.Vector {
            return .init(0, -500 * self.projectile_speed_factor);
        }

        fn scatterShotShootOne(
            self: @This(),
            game: *Game,
            item: Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            const offset = Game.Vector.init(0, -4);
            const velocity = self.projectileVelocity();
            const left = spawnProjectile(
                game,
                position.add(offset),
                velocity,
                self.projectileSprite(game, item),
                context,
                onSpawnProjectile,
            );
            const left_body = left.get(Game.C.Body);
            left_body.setRotation(left_body.rotation() + std.math.pi / 4.0);
            left_body.setVelocity(left_body.velocity().rotate(std.math.pi / 4.0));
            _ = spawnProjectile(
                game,
                position.add(offset),
                velocity,
                self.projectileSprite(game, item),
                context,
                onSpawnProjectile,
            );
            const right = spawnProjectile(
                game,
                position.add(offset),
                velocity,
                self.projectileSprite(game, item),
                context,
                onSpawnProjectile,
            );
            const right_body = right.get(Game.C.Body);
            right_body.setRotation(right_body.rotation() - std.math.pi / 4.0);
            right_body.setVelocity(right_body.velocity().rotate(std.math.pi / -4.0));
        }

        fn scattershotShootTwo(
            self: @This(),
            game: *Game,
            item: Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            const sprite_ = self.projectileSprite(game, item);
            const velocity = self.projectileVelocity();

            var cursor = position;
            const space_between = sprite_.size(1, 0).x + 8;
            cursor.x -= space_between / 2.0;
            _ = spawnProjectile(game, cursor, velocity, sprite_, context, onSpawnProjectile);

            cursor.x += space_between;
            _ = spawnProjectile(game, cursor, velocity, sprite_, context, onSpawnProjectile);
        }

        pub fn shoot(
            self: *@This(),
            game: *Game,
            item: *Item,
            position: Game.Vector,
            context: anytype,
            onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
        ) void {
            game.playSound(.machine_gun);
            switch (item.tier) {
                0 => self.scatterShotShootOne(game, item.*, position, context, onSpawnProjectile),
                1 => self.scatterShotShootOne(game, item.*, position, context, onSpawnProjectile),
                2 => self.scatterShotShootOne(game, item.*, position, context, onSpawnProjectile),
                else => self.scattershotShootTwo(game, item.*, position, context, onSpawnProjectile),
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
        rate_of_fire: WeaponModRateOfFire,
        projectile_speed: WeaponModProjectileSpeed,
        // projectiles,

        pub fn initDamage() @This() {
            return .{ .damage = .init() };
        }

        pub fn initRateOfFire() @This() {
            return .{ .rate_of_fire = .init() };
        }

        pub fn initProjectileSpeed() @This() {
            return .{ .projectile_speed = .init() };
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
        damage_factor: f32 = 0.5,
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

    pub const WeaponModRateOfFire = struct {
        rate_of_fire_factor: f32 = 0.5,
        shop_cost: usize = 30,

        pub fn init() @This() {
            return .{};
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn sprite(_: @This(), game: *Game, _: Item) Game.C.Renderable {
            return game.initSprite(.init(95, 162, 17, 19));
        }

        pub fn apply(self: @This(), weapon_type: *WeaponType) void {
            switch (weapon_type.*) {
                inline else => |*s| {
                    if (@hasField(@TypeOf(s.*), "rate_of_fire_factor")) {
                        s.rate_of_fire_factor += self.rate_of_fire_factor;
                    }
                },
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("Weapon Mod: Rate of Fire\n\nRate of Fire +{d:.0}%", .{self.rate_of_fire_factor * 100});
        }
    };

    pub const WeaponModProjectileSpeed = struct {
        projectile_speed_factor: f32 = 0.5,
        shop_cost: usize = 15,

        pub fn init() @This() {
            return .{};
        }

        pub fn cost(self: @This()) usize {
            return self.shop_cost;
        }

        pub fn sprite(_: @This(), game: *Game, _: Item) Game.C.Renderable {
            return game.initSprite(.init(163, 182, 17, 19));
        }

        pub fn apply(self: @This(), weapon_type: *WeaponType) void {
            switch (weapon_type.*) {
                inline else => |*s| {
                    if (@hasField(@TypeOf(s.*), "projectile_speed_factor")) {
                        s.projectile_speed_factor += self.projectile_speed_factor;
                    }
                },
            }
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            return writer.print("Weapon Mod: Projectile Speed\n\nProjectile Speed +{d:.0}%", .{self.projectile_speed_factor * 100});
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

        pub fn initShield(tier: usize) @This() {
            return .{ .shield = .init(tier) };
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
        regenerate_charge_duration: f64 = 6,
        regenerate_charge_at: f64 = 0,
        n_charges: usize = 1,
        shop_cost: usize = 70,

        pub fn init(tier: usize) @This() {
            return switch (tier) {
                0 => .{
                    .charges_max = 1,
                    .regenerate_charge_duration = 6,
                    .regenerate_charge_at = 0,
                    .n_charges = 1,
                    .shop_cost = 70,
                },
                1 => .{
                    .charges_max = 2,
                    .regenerate_charge_duration = 6,
                    .regenerate_charge_at = 0,
                    .n_charges = 2,
                    .shop_cost = 140,
                },
                2 => .{
                    .charges_max = 3,
                    .regenerate_charge_duration = 6,
                    .regenerate_charge_at = 0,
                    .n_charges = 3,
                    .shop_cost = 210,
                },
                else => unreachable,
            };
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

        pub fn shieldSprite(_: @This(), game: *Game) Game.C.Renderable {
            return game.initSprite(.init(10, 210, 47, 46));
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
    context: anytype,
    onSpawnProjectile: *const fn (@TypeOf(context), Game.EntityContext) void,
) Game.EntityContext {
    const ctx = game.createEntity();
    const body = ctx.addBody(position);
    body.setVelocity(velocity);
    ctx.add(sprite);
    onSpawnProjectile(context, ctx);
    // ctx.add(Game.C.PlayerProjectile.init(1));

    return ctx;
}
