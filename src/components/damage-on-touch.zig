pub const DamageOnTouch = struct {
    damage: usize = 1,
    destroy_source: bool = true,

    pub fn init() @This() {
        return .{};
    }
};
