const Game = @import("../game.zig").Game;

pub const EnemyWeapon = struct {
    weapon_type: WeaponType = .single_cannon,
    next_shot_at: f64 = 0,

    pub const WeaponType = enum {
        single_cannon,
        double_cannon,

        pub fn cooldown(self: WeaponType) f64 {
            return switch (self) {
                .single_cannon => 2,
                .double_cannon => 2,
            };
        }

        pub fn offset(self: WeaponType) Game.Vector {
            return switch (self) {
                .single_cannon => .init(0, 0),
                .double_cannon => .init(0, 0),
            };
        }
    };

    pub fn init(weapon_type: WeaponType) @This() {
        return .{ .weapon_type = weapon_type };
    }

    pub fn cooldown(self: @This()) f64 {
        return self.weapon_type.cooldown();
    }

    pub fn offset(self: @This()) Game.Vector {
        return self.weapon_type.offset();
    }
};
