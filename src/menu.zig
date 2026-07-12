const std = @import("std");
const Game = @import("game.zig").Game;
const rl = @import("raylib");

pub const Menu = struct {
    selected_item: usize = 0,
    items: []const MenuItem = &.{},

    pub const title_pos_rel = Game.Vector.init(0.5, 0.3);
    pub const item_font_size = 9.0;

    pub fn init() @This() {
        return .{};
    }

    pub fn isMenu(self: @This(), menu: []const MenuItem) bool {
        return std.meta.eql(self.items, menu);
    }

    pub fn menuItemRectangle(self: @This(), game: *Game, menu_item: usize) rl.Rectangle {
        var cursor = game.getAbsolutePos(title_pos_rel);
        cursor.y += 12 + 24;
        cursor.y += 18 * @as(f32, @floatFromInt(menu_item));

        if (self.isMenu(settings_menu) or self.isMenu(pause_settings_menu)) {
            if (menu_item > 0) {
                cursor.y += 18;
            }
        }

        const size = Game.Vector.init(128, 12);
        const tl = cursor.subtract(size.scale(0.5));

        return .init(tl.x, tl.y, size.x, size.y);
    }

    pub fn masterVolumeRectangle(self: @This(), game: *Game) rl.Rectangle {
        var position = self.menuItemRectangle(game, 0);
        position.y += 18;
        return .init(position.x, position.y, 128, 9);
    }

    pub fn moveUp(self: *Menu) void {
        if (self.selected_item == 0) {
            self.selected_item = self.items.len - 1;
        } else {
            self.selected_item -= 1;
        }
    }

    pub fn moveDown(self: *Menu) void {
        self.selected_item += 1;
        self.selected_item %= self.items.len;
    }

    pub fn moveLeft(self: *Menu, game: *Game) void {
        const menu_item = self.items[self.selected_item];
        self.handleEvent(game, menu_item.left_event);
    }

    pub fn moveRight(self: *Menu, game: *Game) void {
        const menu_item = self.items[self.selected_item];
        self.handleEvent(game, menu_item.right_event);
    }

    pub fn execute(self: *Menu, game: *Game) void {
        self.handleEvent(game, self.items[self.selected_item].event);
    }

    pub fn setMenu(self: *Menu, menu_items: []const MenuItem) void {
        self.items = menu_items;
        self.selected_item = 0;
    }

    pub fn handleEvent(self: *Menu, game: *Game, event: MenuEvent) void {
        switch (event) {
            .none => {},
            .set_menu => |new_menu| self.setMenu(switch (new_menu) {
                .main => main_menu,
                .settings => settings_menu,
                .pause => pause_menu,
                .pause_settings => pause_settings_menu,
            }),
            .lower_master_volume => game.settings.lowerMasterVolume(),
            .raise_master_volume => game.settings.raiseMasterVolume(),
            .test_volume => game.settings.testVolume(game),
            .start_game => game.startGame(),
            .unpause => game.unpause(),
            .quit => game.wants_to_quit = true,
        }
    }

    pub const MenuEvent = union(enum) {
        none,
        set_menu: MenuType,
        lower_master_volume,
        raise_master_volume,
        test_volume,
        start_game,
        unpause,
        quit,
    };

    pub const MenuType = enum {
        main,
        settings,
        pause,
        pause_settings,
    };

    pub const MenuItem = struct {
        label: []const u8,
        event: MenuEvent = .none,
        left_event: MenuEvent = .none,
        right_event: MenuEvent = .none,
    };

    pub const main_menu: []const MenuItem = &.{
        .{ .label = "START", .event = .start_game },
        .{ .label = "SETTINGS", .event = .{ .set_menu = .settings } },
        .{ .label = "QUIT", .event = .quit },
    };

    pub const pause_menu: []const MenuItem = &.{
        .{ .label = "CONTINUE", .event = .unpause },
        .{ .label = "SETTINGS", .event = .{ .set_menu = .pause_settings } },
        .{ .label = "QUIT", .event = .quit },
    };

    pub const core_settings_menu: []const MenuItem = &.{
        .{ .label = "MASTER VOLUME", .left_event = .lower_master_volume, .right_event = .raise_master_volume },
        .{ .label = "TEST VOLUME", .event = .test_volume },
    };

    pub const settings_menu: []const MenuItem = core_settings_menu ++ .{
        MenuItem{ .label = "BACK", .event = .{ .set_menu = .main } },
    };

    pub const pause_settings_menu: []const MenuItem = core_settings_menu ++ .{
        MenuItem{ .label = "BACK", .event = .{ .set_menu = .pause } },
    };
};
