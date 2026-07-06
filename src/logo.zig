const Game = @import("game.zig").Game;
const rl = @import("raylib");

pub const Logo = struct {
    fade_in_at: f64,
    fully_fade_in_at: f64,
    fade_out_at: f64,
    fully_fade_out_at: f64,
    transition_at: f64,
    texture: Game.Texture = undefined,

    pub const logo_filename = "src/resources/logo.png";

    pub fn init(t: f64) Logo {
        return .{
            .fade_in_at = t + 1,
            .fully_fade_in_at = t + 2,
            .fade_out_at = t + 5,
            .fully_fade_out_at = t + 6,
            .transition_at = t + 7,
        };
    }

    pub fn load(self: *Logo) !void {
        self.texture = try rl.loadTexture(logo_filename);
    }

    pub fn alpha(self: Logo, t: f64) f32 {
        if (self.fully_fade_out_at <= t) return 0;
        if (self.fade_out_at <= t) {
            return @floatCast(1 - (t - self.fade_out_at) / self.fade_out_duration());
        }
        if (self.fully_fade_in_at <= t) return 1;
        if (self.fade_in_at <= t) {
            return @floatCast((t - self.fade_in_at) / self.fade_in_duration());
        }
        return 0;
    }

    fn fade_in_duration(self: Logo) f64 {
        return self.fully_fade_in_at - self.fade_in_at;
    }

    fn fade_out_duration(self: Logo) f64 {
        return self.fully_fade_out_at - self.fade_out_at;
    }
};
