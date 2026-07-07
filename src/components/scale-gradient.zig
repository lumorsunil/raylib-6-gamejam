pub const ScaleGradient = struct {
    delta_per_second: f32,

    pub fn init(delta_per_second: f32) @This() {
        return .{ .delta_per_second = delta_per_second };
    }
};
