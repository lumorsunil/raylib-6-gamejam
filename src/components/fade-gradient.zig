pub const FadeGradient = struct {
    start_fade_at: f64,
    end_fade_at: f64,

    pub fn init(start_fade_at: f64, duration_: f64) @This() {
        return .{
            .start_fade_at = start_fade_at,
            .end_fade_at = duration_ + start_fade_at,
        };
    }

    pub fn duration(self: FadeGradient) f64 {
        return self.end_fade_at - self.start_fade_at;
    }

    pub fn alpha(self: FadeGradient, t: f64) f32 {
        const d = t - self.start_fade_at;

        if (d < 0) return 1;
        if (d >= self.duration()) return 0;

        return @floatCast(1 - d / self.duration());
    }
};
