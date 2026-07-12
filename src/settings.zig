const Game = @import("game.zig").Game;
const rl = @import("raylib");

pub const Settings = struct {
    master_volume: f32 = 0.05,
    is_editing_master_volume: bool = false,

    pub const max_master_volume = 0.5;
    pub const min_master_volume = 0;
    pub const master_volume_step = 0.01;

    pub fn init() @This() {
        return .{};
    }

    pub fn setMasterVolume(self: *Settings, new_master_volume: f32) void {
        const new_volume = @min(max_master_volume, @max(min_master_volume, new_master_volume));
        self.master_volume = new_volume;
        rl.setMasterVolume(new_volume);
    }

    pub fn lowerMasterVolume(self: *Settings) void {
        self.setMasterVolume(self.master_volume - master_volume_step);
    }

    pub fn raiseMasterVolume(self: *Settings) void {
        self.setMasterVolume(self.master_volume + master_volume_step);
    }

    pub fn testVolume(_: *Settings, game: *Game) void {
        game.playSound(.enemy_explosion);
    }
};
