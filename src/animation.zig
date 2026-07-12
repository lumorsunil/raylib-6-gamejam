const std = @import("std");
const Game = @import("game.zig").Game;

pub const AnimationKey = enum {
    shield_recharge,
    shield_dissipate,
    enemy_bullet_spawn,
    enemy_bullet_blue_spawn,
};

pub const Animations = std.enums.EnumFieldStruct(AnimationKey, AnimationType, null);

pub const AnimationType = struct {
    frames: []const Game.C.Renderable,
    frame_duration: f64 = 0.2,

    pub fn init(frames: []const Game.C.Renderable, frame_duration: f64) @This() {
        return .{ .frames = frames, .frame_duration = frame_duration };
    }
};

pub const Animation = struct {
    animation: AnimationType,
    current_frame: usize = 0,
    is_looping: bool = true,
    next_frame_at: f64 = 0.2,

    pub fn init(animation: AnimationType) @This() {
        return .{ .animation = animation, .next_frame_at = animation.frame_duration };
    }

    pub fn start(self: *@This(), t: f64) void {
        self.current_frame = 0;
        self.next_frame_at = t + self.animation.frame_duration;
    }

    pub fn currentFrame(self: @This()) Game.C.Renderable {
        return self.animation.frames[self.current_frame];
    }

    pub fn lastFrame(self: @This()) Game.C.Renderable {
        return self.animation.frames[self.animation.frames.len - 1];
    }

    pub fn isDone(self: @This()) bool {
        if (self.is_looping) return false;
        return self.current_frame >= self.animation.frames.len;
    }

    pub fn update(self: *@This(), t: f64) void {
        if (self.next_frame_at <= t) {
            self.next_frame_at = t + self.animation.frame_duration;
            self.current_frame += 1;
            if (self.is_looping) self.current_frame %= self.animation.frames.len;
        }
    }
};
