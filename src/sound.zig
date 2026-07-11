const std = @import("std");
const rl = @import("raylib");

pub const Sound = enum {
    machine_gun,

    shield_hit,
    shield_recharge,

    player_explosion,
    enemy_explosion,
    enemy_hit,

    pickup_shard,

    menu_accept,
    menu_cancel,
    menu_select,
    menu_item_merge,
    menu_item_swap,

    pub fn filename(self: Sound) [:0]const u8 {
        return switch (self) {
            .machine_gun => "src/resources/rlgj-machine-gun.wav",
            .shield_hit => "src/resources/rlgj-shield-hit.wav",
            .shield_recharge => "src/resources/rlgj-shield-recharge.wav",
            .player_explosion => "src/resources/rlgj-player-explosion.wav",
            .enemy_explosion => "src/resources/rlgj-enemy-explosion.wav",
            .enemy_hit => "src/resources/rlgj-enemy-hit.wav",
            .pickup_shard => "src/resources/rlgj-shard.wav",
            .menu_accept => "src/resources/rlgj-accept.wav",
            .menu_cancel => "src/resources/rlgj-cancel.wav",
            .menu_select => "src/resources/rlgj-item-select.wav",
            .menu_item_merge => "src/resources/rlgj-item-merge.wav",
            .menu_item_swap => "src/resources/rlgj-item-swap.wav",
        };
    }
};

pub const Sounds = std.enums.EnumFieldStruct(Sound, rl.Sound, null);
