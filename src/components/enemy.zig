pub const Enemy = struct {
    tier: usize = 0,
    max_health: usize = 1,
    health: usize = 1,
    hit_fade_ends_at: f64 = 0,
    is_merging: bool = false,

    pub const hit_fade_duration = 0.2;

    pub fn init(tier: usize, max_health: usize) @This() {
        return .{
            .tier = tier,
            .max_health = max_health,
            .health = max_health,
        };
    }
};
