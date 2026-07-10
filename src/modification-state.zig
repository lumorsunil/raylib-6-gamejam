const std = @import("std");
const Game = @import("game.zig").Game;

pub const ModificationState = struct {
    selected_item: ?usize = null,
    selected_item_inventory: ?[]?Game.C.Item = null,
    is_dragging: bool = false,

    pub fn init() @This() {
        return .{};
    }

    pub fn setup(self: *@This(), _: *Game) void {
        self.selected_item = null;
        self.selected_item_inventory = null;
        self.is_dragging = false;
    }

    pub fn selectedItem(self: @This()) ?Game.C.Item {
        const ptr = self.selectedItemPtr() orelse return null;
        return ptr.*;
    }

    pub fn selectedItemPtr(self: @This()) ?*?Game.C.Item {
        const inventory = self.selected_item_inventory orelse return null;
        const i = self.selected_item orelse return null;
        return &inventory[i];
    }

    pub fn isItemSelected(self: @This(), i: usize, inventory: []?Game.C.Item) bool {
        const selected_inventory = self.selected_item_inventory orelse return false;
        const selected_item = self.selected_item orelse return false;
        return std.meta.eql(selected_inventory, inventory) and selected_item == i;
    }
};
