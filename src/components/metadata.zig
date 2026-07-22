pub const Metadata = struct {
    created_at: f64,

    pub fn init(created_at: f64) @This() {
        return .{
            .created_at = created_at,
        };
    }
};
