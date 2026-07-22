const std = @import("std");
const Allocator = std.mem.Allocator;
const ecs = @import("ecs");

pub const PlayerProjectile = struct {
    damage: f32,
    piercing_charges: usize,
    entities_hit: std.ArrayList(ecs.Entity) = .empty,

    pub fn init(damage: f32, piercing_charges: usize) @This() {
        return .{ .damage = damage, .piercing_charges = piercing_charges };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.entities_hit.deinit(allocator);
    }
};
