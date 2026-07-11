pub const Background = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }
};
