const std = @import("std");
const rl = @import("raylib");

pub const Music = enum {
    theme,
    stage_1,
    stage_2,
    stage_3,
    shop,

    pub fn filename(self: Music) [:0]const u8 {
        return switch (self) {
            .theme => "src/resources/rlgj-theme.ogg",
            .stage_1 => "src/resources/rlgj-stage-1.ogg",
            .stage_2 => "src/resources/rlgj-stage-2.ogg",
            .stage_3 => "src/resources/rlgj-stage-3.mp3",
            .shop => "src/resources/rlgj-shop.mp3",
        };
    }
};

pub const Musics = std.enums.EnumFieldStruct(Music, rl.Music, null);
