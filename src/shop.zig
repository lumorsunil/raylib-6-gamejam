const std = @import("std");
const Game = @import("game.zig").Game;

pub const Shop = struct {
    items: []Game.C.Item,
    available_weapons: std.ArrayList(Game.C.Item) = .empty,
    available_weapon_mods: std.ArrayList(Game.C.Item) = .empty,
    available_body_mods: std.ArrayList(Game.C.Item) = .empty,
    selected_item: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .items = try allocator.alloc(Game.C.Item, 3),
        };
    }

    pub fn deinit(self: *Shop, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
        self.available_weapons.deinit(allocator);
        self.available_weapon_mods.deinit(allocator);
        self.available_body_mods.deinit(allocator);
    }

    pub fn setup(self: *Shop, game: *Game) !void {
        try self.populateAvailableItems(game);
        self.populatePurchasableItems();
    }

    fn populateAvailableItems(self: *Shop, game: *Game) !void {
        try self.debugPopulateAvailableItems(game);
    }

    fn populatePurchasableItems(self: *Shop) void {
        self.items[0] = self.available_weapons.items[0];
        self.items[1] = self.available_weapon_mods.items[0];
        self.items[2] = self.available_body_mods.items[0];
    }

    fn debugPopulateAvailableItems(self: *Shop, game: *Game) !void {
        const allocator = game.allocator;

        self.available_weapons.clearRetainingCapacity();
        self.available_weapon_mods.clearRetainingCapacity();
        self.available_body_mods.clearRetainingCapacity();

        try self.available_weapons.append(allocator, .initRandom(game, 0, .weapon));
        try self.available_weapon_mods.append(allocator, .initRandom(game, 0, .weapon_mod));
        try self.available_body_mods.append(allocator, .initRandom(game, 0, .body_mod));
    }

    pub fn selectedItem(self: @This()) Game.C.Item {
        return self.items[self.selected_item];
    }
};
