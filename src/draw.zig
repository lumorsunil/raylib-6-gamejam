const std = @import("std");
const Game = @import("game.zig").Game;
const rl = @import("raylib");

const enable_debug_draw = true;

pub fn draw(self: *Game) void {
    switch (self.screen_state) {
        .logo => drawLogo(self),
        .menu => drawMenu(self),
        .gameplay => drawGameplay(self),
        .shop => drawShop(self),
        .modification => drawModification(self),
        .ending => drawEnding(self),
        .game_over => drawGameOver(self),
    }
}

fn drawLogo(self: *Game) void {
    rl.clearBackground(.black);
    const half_screen_y: i32 = @intFromFloat(self.screenSize().y / 2);
    const half_height = @divFloor(self.logo.texture.height, 2);
    const tint = Game.Color.white.alpha(self.logo.alpha(self.elapsedTime()));
    rl.drawTexture(self.logo.texture, 0, half_screen_y - half_height, tint);
}

fn drawFadeOverlay(self: *Game) void {
    const screen_size = self.screenSize();
    rl.drawRectangleV(.init(0, 0), screen_size, .alpha(.black, 0.8));
}

fn drawMenu(self: *Game) void {
    drawGameplay(self);
    drawFadeOverlay(self);

    var ui_camera = self.camera().*;
    ui_camera.offset = .zero();
    ui_camera.target = .zero();
    ui_camera.begin();
    drawMenuUI(self);
    ui_camera.end();
}

fn drawMenuUI(self: *Game) void {
    var cursor = self.worldSize();
    const right_lane = cursor.x * 0.7;
    cursor.x /= 2;
    cursor.y *= 0.3;
    cursor = cursor.add(self.worldPosition());
    const title_font_size = 12;
    const item_font_size = 9.0;
    drawTextCentered("MENU", .{}, title_font_size, cursor, .white);
    cursor.y += 12 + 24;

    for (self.menu.items, 0..) |item, i| {
        const is_selected = if (i == self.menu.selected_item) "> " else "";
        drawTextCentered("{s}{s}", .{ is_selected, item.label }, item_font_size, cursor, .white);
        if (std.mem.eql(u8, item.label, "MASTER VOLUME")) {
            drawVolume(self, .init(right_lane, cursor.y - item_font_size / 2.0));
        }
        cursor.y += 9 + 9;
    }
}

fn drawVolume(self: *Game, position: Game.Vector) void {
    const size_x = 50;
    rl.drawRectangleV(position, .init(size_x, 9), .dark_gray);
    const perc_x = (self.settings.master_volume / Game.Settings.max_master_volume) * size_x;
    rl.drawRectangleV(position, .init(perc_x, 9), .white);
}

fn drawGameplay(self: *Game) void {
    rl.clearBackground(.black);
    self.camera().begin();
    drawGrid(self);
    drawRenderables(self);
    // debugDraw(self);
    drawBorder(self);
    self.camera().end();
    rl.drawFPS(8, 8);

    var ui_camera = self.camera().*;
    ui_camera.offset = .zero();
    ui_camera.target = .zero();
    ui_camera.begin();
    drawHUD(self);
    // debugDrawUI(self);
    ui_camera.end();
}

fn drawShop(self: *Game) void {
    rl.clearBackground(.gray);
    self.camera().begin();
    drawBorder(self);

    const flen: f32 = @floatFromInt(self.shop_state.items.len);
    const x_step = 1.0 / (flen + 1);
    var cursor = Game.Vector.init(x_step, 0.5);
    const player = self.player();
    const player_component = player.get(Game.C.Player);

    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);

    const selected_item = self.shop_state.selectedItem();
    const selected_item_cost = selected_item.cost();
    const can_afford = selected_item_cost <= player_component.shards;
    drawSkipButton(self);
    drawBuyButton(self, selected_item_cost, can_afford);

    if (rl.isMouseButtonPressed(.left)) {
        if (rl.checkCollisionPointRec(mouse_pos, skipButtonRec(self))) {
            self.playSound(.menu_cancel);
            self.modification();
        } else if (can_afford and rl.checkCollisionPointRec(mouse_pos, buyButtonRec(self, selected_item_cost))) {
            player_component.shards -= selected_item_cost;
            _ = player_component.inventory.appendItem(selected_item);
            self.playSound(.menu_accept);
            self.modification();
        }
    }

    drawItemDescription(self, selected_item);

    for (self.shop_state.items, 0..) |item, i| {
        const empty_slot_renderable = Game.C.Item.emptySlotRenderable(self);
        const item_renderable = item.sprite(self);
        const item_size = empty_slot_renderable.size(1, 0);
        const abs_pos = self.getAbsolutePos(cursor);
        empty_slot_renderable.draw(abs_pos, 1, 0);
        item_renderable.draw(abs_pos, 1, 0);

        const cost = item.cost();
        const shard_position = abs_pos.add(.init(0, item_size.y + 8));
        const cost_color: Game.Color = if (cost > player_component.shards) .red else .white;
        drawShardCounter(self, shard_position, cost, 12, .black, cost_color);

        cursor.x += x_step;

        if (i == self.shop_state.selected_item) {
            const tl = abs_pos.subtract(empty_slot_renderable.origin(1, 0));
            rl.drawRectangleLinesEx(.init(tl.x, tl.y, item_size.x, item_size.y), 1, .yellow);
        }

        if (empty_slot_renderable.containsPoint(abs_pos, mouse_pos, 1, 0)) {
            drawItemDescription(self, item);

            if (rl.isMouseButtonPressed(.left)) {
                self.playSound(.menu_select);
                self.shop_state.selected_item = i;
            }
        }
    }

    const player_shard_position = self.getAbsolutePos(.init(0.5, 0.85));
    drawShardCounter(self, player_shard_position, player_component.shards, 14, .alpha(.black, 0), .white);

    self.camera().end();
}

fn drawShardCounter(
    self: *Game,
    position: Game.Vector,
    amount: usize,
    font_size: f32,
    bg_color: Game.Color,
    text_color: Game.Color,
) void {
    const shard = Game.C.Shard.init(.small);
    const shard_renderable = shard.renderable(self);
    const shard_rotation: f32 = @floatCast(@mod(self.elapsedTime(), std.math.pi * 2));
    const shard_size = shard_renderable.size(1, 0);

    const text_width = measureText("{}", .{amount}, font_size);
    const total_width = shard_size.x + 2 + text_width;
    const cost_offset = Game.Vector.init(total_width / 2, 0);

    const shard_position = position.subtract(cost_offset);
    const cost_tl = shard_position.subtract(shard_size.scale(0.5)).subtract(.init(0, 4));
    const padding = Game.Vector.init(4, 4);

    rl.drawRectangleV(
        cost_tl.subtract(padding),
        padding.scale(2).add(.init(total_width + 4, font_size)),
        bg_color,
    );

    shard_renderable.draw(shard_position, 1, shard_rotation);
    const cost_position = shard_position.add(.init(shard_size.x + 2, -font_size / 2));
    drawText("{}", .{amount}, font_size, cost_position, text_color);
}

const button_font_size = 10;

fn buttonRec(
    comptime fmt: []const u8,
    args: anytype,
    position: Game.Vector,
) rl.Rectangle {
    const padding = Game.Vector.init(8, 8);
    const width = measureText(fmt, args, button_font_size);
    const button_size = padding.add(.init(width, button_font_size));
    const tl = position.subtract(button_size.scale(0.5));
    return .init(tl.x, tl.y, button_size.x, button_size.y);
}

fn drawButton(
    comptime fmt: []const u8,
    args: anytype,
    position: Game.Vector,
    color: Game.Color,
    text_color: Game.Color,
) void {
    const rec = buttonRec(fmt, args, position);
    rl.drawRectangleRec(rec, color);
    drawTextCentered(fmt, args, button_font_size, position, text_color);
}

fn skipButtonRec(self: *Game) rl.Rectangle {
    const position = self.worldCenter().subtract(.init(32, -64));
    return buttonRec("SKIP", .{}, position);
}

fn drawSkipButton(self: *Game) void {
    const position = self.worldCenter().subtract(.init(32, -64));
    drawButton("SKIP", .{}, position, .red, .white);
}

fn buyButtonRec(self: *Game, cost: usize) rl.Rectangle {
    const position = self.worldCenter().subtract(.init(-32, -64));
    return buttonRec("BUY {}", .{cost}, position);
}

fn drawBuyButton(self: *Game, cost: usize, can_afford: bool) void {
    const position = self.worldCenter().subtract(.init(-32, -64));
    drawButton(
        "BUY {}",
        .{cost},
        position,
        if (can_afford) .green else .dark_gray,
        if (can_afford) .white else .light_gray,
    );
}

fn drawItemDescription(self: *Game, item: Game.C.Item) void {
    const tl = self.getAbsolutePos(.init(0.1, 0.05));
    const br = self.getAbsolutePos(.init(0.9, 0.45));
    const size = br.subtract(tl);

    rl.drawRectangleV(tl, size, .black);

    drawText("{f}", .{item}, 8, tl.add(.init(3, 3)), .white);
}

fn drawModification(self: *Game) void {
    rl.clearBackground(.gray);
    self.camera().begin();
    drawBorder(self);

    if (self.modification_state.selectedItem()) |item| {
        drawItemDescription(self, item);
    }
    drawModificationShip(self);
    drawInventory(self);
    drawDrag(self);
    drawNextLevelButton(self);

    self.camera().end();
}

fn drawModificationShip(self: *Game) void {
    const tl = self.getAbsolutePos(.init(0.1, 0.50));
    const br = self.getAbsolutePos(.init(0.9, 0.65));
    const size = br.subtract(tl);

    rl.drawRectangleV(tl, size, .black);

    const player = self.player();
    const player_component = player.get(Game.C.Player);

    const position = tl.add(size.scale(0.5));

    player_component.body.body_type.modificationSprite(self).draw(position, 2, 0);
    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);

    for (player_component.body.slots, 0..) |slot, i| {
        const item = slot orelse continue;
        const offset = player_component.body.equipOffset(self, i);
        const center = position.add(offset);
        item.sprite(self).draw(center, 2, 0);

        if (rl.isMouseButtonPressed(.left)) {
            if (item.sprite(self).containsPoint(center, mouse_pos, 2, 0)) {
                self.playSound(.menu_select);
                self.modification_state.selected_item = i;
                self.modification_state.selected_item_inventory = player_component.body.slots;
                self.modification_state.is_dragging = true;
            }
        }

        if (self.modification_state.isItemSelected(i, player_component.body.slots)) {
            const selection_border = self.initSprite(.init(93, 101, 17, 19));
            selection_border.draw(center, 2, 0);
        }
    }

    if (self.modification_state.is_dragging) {
        if (rl.isMouseButtonReleased(.left)) {
            const selected_item = self.modification_state.selectedItemPtr().?;

            for (player_component.body.slots, 0..) |*slot, i| {
                const offset = player_component.body.equipOffset(self, i);
                const center = position.add(offset);

                if (Game.C.Item.emptySlotRenderable(self).containsPoint(center, mouse_pos, 2, 0)) {
                    if (slot == selected_item) break;

                    if (canMerge(selected_item, slot)) {
                        merge(self, selected_item, slot);
                        if (slot.* == null) {
                            swapItems(self, selected_item, slot);
                        }
                    } else {
                        swapItems(self, selected_item, slot);
                    }

                    self.modification_state.selected_item = null;
                    self.modification_state.selected_item_inventory = null;

                    break;
                }
            }
        } else {
            const selected_item = self.modification_state.selectedItemPtr().?;

            for (0..player_component.body.slots.len) |i| {
                const offset = player_component.body.equipOffset(self, i);
                const center = position.add(offset);
                const slot_item = &player_component.body.slots[i];

                if (Game.C.Item.emptySlotRenderable(self).containsPoint(center, mouse_pos, 2, 0)) {
                    if (selected_item == slot_item) break;

                    if (canMerge(selected_item, slot_item)) {
                        const merge_border = self.initSprite(.init(71, 142, 19, 21));
                        merge_border.draw(center, 2, 0);
                    } else {
                        const swap_border = self.initSprite(.init(75, 101, 17, 19));
                        swap_border.draw(center, 2, 0);
                    }

                    break;
                }
            }
        }
    }
}

fn drawInventory(self: *Game) void {
    const tl = self.getAbsolutePos(.init(0.1, 0.70));
    const br = self.getAbsolutePos(.init(0.9, 0.85));
    const size = br.subtract(tl);

    const player = self.player();
    const player_component = player.get(Game.C.Player);

    rl.drawRectangleV(tl, size, .black);

    const empty_slot = Game.C.Item.emptySlotRenderable(self);

    const n_cols = Game.C.Player.Inventory.n_item_cols;
    const n_rows = Game.C.Player.Inventory.n_item_rows;
    const width = 16;
    const height = 14;
    const slot_size = Game.Vector.init(width, height);

    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);

    const start = tl.add(.init(12, 12));

    var selected_position: ?Game.Vector = null;

    for (0..n_cols) |x| {
        for (0..n_rows) |y| {
            const is_even = @mod(y, 2) == 0;
            const offset_x: f32 = if (is_even) width / 2.0 else 0;
            const offset = Game.Vector.init(
                @floatFromInt(x),
                @floatFromInt(y),
            ).multiply(slot_size).add(.init(offset_x, 0));
            const position = start.add(offset);
            empty_slot.draw(position, 1, 0);
            const i = x + y * n_cols;

            const item = player_component.inventory.items[i] orelse continue;
            item.sprite(self).draw(position, 1, 0);

            if (self.modification_state.isItemSelected(i, player_component.inventory.items)) {
                selected_position = position;
            }

            if (rl.isMouseButtonPressed(.left)) {
                if (item.sprite(self).containsPoint(position, mouse_pos, 1, 0)) {
                    self.playSound(.menu_select);
                    self.modification_state.selected_item = i;
                    self.modification_state.selected_item_inventory = player_component.inventory.items;
                    self.modification_state.is_dragging = true;
                }
            }
        }
    }

    if (self.modification_state.is_dragging) {
        if (rl.isMouseButtonReleased(.left)) {
            self.modification_state.is_dragging = false;

            const selected_item = self.modification_state.selectedItemPtr() orelse return;

            const slot_renderable = Game.C.Item.emptySlotRenderable(self);

            outer: for (0..n_cols) |x| {
                for (0..n_rows) |y| {
                    const is_even = @mod(y, 2) == 0;
                    const offset_x: f32 = if (is_even) width / 2.0 else 0;
                    const offset = Game.Vector.init(
                        @floatFromInt(x),
                        @floatFromInt(y),
                    ).multiply(slot_size).add(.init(offset_x, 0));
                    const position = start.add(offset);
                    const i = x + y * n_cols;

                    if (slot_renderable.containsPoint(position, mouse_pos, 1, 0)) {
                        const slot = &player_component.inventory.items[i];
                        if (slot == selected_item) break :outer;

                        if (canMerge(selected_item, slot)) {
                            merge(self, selected_item, slot);
                            if (slot.* == null) {
                                swapItems(self, selected_item, slot);
                            }
                        } else {
                            swapItems(self, selected_item, slot);
                        }

                        self.modification_state.selected_item = null;
                        self.modification_state.selected_item_inventory = null;

                        break :outer;
                    }
                }
            }
        } else {
            const selected_item = self.modification_state.selectedItemPtr().?;

            outer: for (0..n_cols) |x| {
                for (0..n_rows) |y| {
                    const is_even = @mod(y, 2) == 0;
                    const offset_x: f32 = if (is_even) width / 2.0 else 0;
                    const offset = Game.Vector.init(
                        @floatFromInt(x),
                        @floatFromInt(y),
                    ).multiply(slot_size).add(.init(offset_x, 0));
                    const position = start.add(offset);
                    const i = x + y * n_cols;

                    if (Game.C.Item.emptySlotRenderable(self).containsPoint(position, mouse_pos, 1, 0)) {
                        const slot_item = &player_component.inventory.items[i];
                        if (selected_item == slot_item) break;

                        if (canMerge(selected_item, slot_item)) {
                            const merge_border = self.initSprite(.init(71, 142, 19, 21));
                            merge_border.draw(position, 1, 0);
                        } else {
                            const swap_border = self.initSprite(.init(75, 101, 17, 19));
                            swap_border.draw(position, 1, 0);
                        }

                        break :outer;
                    }
                }
            }
        }
    }

    if (selected_position) |position| {
        const selection_border = self.initSprite(.init(93, 101, 17, 19));
        selection_border.draw(position, 1, 0);
    }
}

fn canMerge(a: *?Game.C.Item, b: *?Game.C.Item) bool {
    const a_ = if (a.*) |*a_| a_ else return false;
    const b_ = if (b.*) |*b_| b_ else return false;
    return a_.canMergeWith(b_.*);
}

fn merge(self: *Game, a: *?Game.C.Item, b: *?Game.C.Item) void {
    const a_ = if (a.*) |*a_| a_ else return;
    const b_ = if (b.*) |*b_| b_ else return;

    self.playSound(.menu_item_merge);

    switch (a_.merge(b_)) {
        .destroy => |item| {
            const player = self.player();
            const player_component = player.get(Game.C.Player);

            for (player_component.inventory.items) |*inv_item| {
                const inv_item_ = if (inv_item.*) |*it| it else continue;
                if (inv_item_ == item) {
                    inv_item.* = null;
                    return;
                }
            }
            for (player_component.body.slots) |*inv_item| {
                const inv_item_ = if (inv_item.*) |*it| it else continue;
                if (inv_item_ == item) {
                    inv_item.* = null;
                    return;
                }
            }
        },
    }
}

fn swapItems(self: *Game, a: *?Game.C.Item, b: *?Game.C.Item) void {
    self.playSound(.menu_item_swap);

    const copy = a.*;
    a.* = b.*;
    b.* = copy;
}

fn drawDrag(self: *Game) void {
    if (!self.modification_state.is_dragging) return;

    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);
    const item = self.modification_state.selectedItem().?;
    var sprite = item.sprite(self);
    sprite.sprite.tint = .alpha(.white, 0.5);

    sprite.draw(mouse_pos, 2, 0);
}

fn drawNextLevelButton(self: *Game) void {
    const position = self.getAbsolutePos(.init(0.5, 0.925));
    drawButton("CONTINUE", .{}, position, .green, .white);
    const button_rec = buttonRec("CONTINUE", .{}, position);
    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);
    if (rl.isMouseButtonPressed(.left)) {
        if (rl.checkCollisionPointRec(mouse_pos, button_rec)) {
            self.nextStage();
        }
    }
}

fn drawEnding(self: *Game) void {
    _ = self;
}

fn drawGameOver(self: *Game) void {
    drawGameplay(self);
    drawFadeOverlay(self);

    var ui_camera = self.camera().*;
    ui_camera.offset = .zero();
    ui_camera.target = .zero();
    ui_camera.begin();
    drawGameOverUI(self);
    ui_camera.end();
}

fn drawBorder(self: *Game) void {
    const screen_size = self.screenSize();
    const world_pos = self.worldPosition();
    const world_size = self.worldSize();
    rl.drawRectangleV(.init(0, 0), .init(world_pos.x, screen_size.y), .black);
    rl.drawRectangleV(.init(world_pos.x + world_size.x, 0), .init(screen_size.x, screen_size.y), .black);
}

fn drawGameOverUI(self: *Game) void {
    const title_font_size = 12;
    drawTextCentered("GAME OVER", .{}, title_font_size, self.worldCenter(), .white);
}

fn debugDraw(self: *Game) void {
    var it = self.entityIterator(.{ Game.C.Body, Game.C.Renderable }, .{});

    while (it.next()) |ctx| {
        const hitbox = self.hitbox(ctx);

        rl.drawRectangleV(hitbox.position(), hitbox.size(), .alpha(.red, 0.5));
    }
}

fn debugDrawUI(self: *Game) void {
    if (!enable_debug_draw) return;

    var it = self.entityIterator(.{ Game.C.Body, Game.C.Controllable }, .{});
    const font_size = 8;

    while (it.next()) |ctx| {
        const body = ctx.getConst(Game.C.Body);

        drawText("{}", .{body.position.x}, font_size, .init(8, 8 + 10), .green);
        drawText("{}", .{body.position.y}, font_size, .init(8, 8 + 20), .green);
    }
}

fn measureText(
    comptime fmt: []const u8,
    args: anytype,
    font_size: f32,
) f32 {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, fmt, args) catch unreachable;
    return @floatFromInt(rl.measureText(text, @intFromFloat(font_size)));
}

fn drawText(
    comptime fmt: []const u8,
    args: anytype,
    font_size: f32,
    position: Game.Vector,
    color: Game.Color,
) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, fmt, args) catch unreachable;
    rl.drawText(
        text,
        @intFromFloat(position.x),
        @intFromFloat(position.y),
        @intFromFloat(font_size),
        color,
    );
}

fn drawTextCentered(
    comptime fmt: []const u8,
    args: anytype,
    font_size: f32,
    position: Game.Vector,
    color: Game.Color,
) void {
    const width = measureText(fmt, args, font_size);
    var p = position;
    p.x -= width / 2;
    p.y -= font_size / 2;
    drawText(fmt, args, font_size, p, color);
}

fn lessThan(_: usize, a: usize, b: usize) bool {
    return a < b;
}

fn drawRenderables(self: *Game) void {
    var it = self.entityIterator(.{ Game.C.Renderable, Game.C.Body }, .{Game.C.Invisible});
    const n_layers = 4;

    for (0..n_layers) |layer| {
        it.reset();
        while (it.next()) |ctx| {
            const renderable = ctx.getConst(Game.C.Renderable);
            if (renderable.layer() != layer) continue;
            drawRenderable(self, ctx);
        }
    }
}

// fn drawRenderables(self: *Game) void {
//     var it = self.entityIterator(.{ Game.C.Renderable, Game.C.Body }, .{Game.C.Invisible});
//
//     var layer_map: std.array_hash_map.Auto(usize, std.ArrayList(Game.EntityContext)) = .empty;
//     defer {
//         for (layer_map.values()) |*list| {
//             list.deinit(self.allocator);
//         }
//         layer_map.deinit(self.allocator);
//     }
//
//     while (it.next()) |ctx| {
//         const renderable = ctx.getConst(Game.C.Renderable);
//         const layer = renderable.layer();
//
//         const entry = layer_map.getOrPut(self.allocator, layer) catch unreachable;
//         if (!entry.found_existing) {
//             entry.value_ptr.* = .empty;
//         }
//
//         entry.value_ptr.append(self.allocator, ctx) catch unreachable;
//     }
//     std.mem.sort(usize, layer_map.keys(), @as(usize, 0), lessThan);
//     layer_map.reIndex(self.allocator) catch unreachable;
//
//     // TODO: figure out why things are not drawn in correct order
//
//     for (layer_map.keys()) |k| {
//         const list = layer_map.get(k).?;
//         for (list.items) |ctx| {
//             drawRenderable(self, ctx);
//         }
//     }
// }

fn drawRenderable(self: *Game, ctx: Game.EntityContext) void {
    const body = ctx.get(Game.C.Body);
    var renderable = ctx.getConst(Game.C.Renderable);

    if (ctx.tryGetConst(Game.C.Player)) |player| {
        if (player.destroyed_at) |_| {
            return;
        }
    }

    if (ctx.tryGetConst(Game.C.RelativePosition)) |rel_pos| {
        if (rel_pos.anchoree.tryGetConst(Game.C.Player)) |player| {
            if (player.destroyed_at) |_| {
                return;
            }
        }
    }

    if (ctx.tryGetConst(Game.C.ScaleGradient)) |scale_gradient| {
        body.scale += scale_gradient.delta_per_second * self.deltaTime();
    }

    if (ctx.tryGetConst(Game.C.FadeGradient)) |fade_gradient| {
        renderable.sprite.tint = renderable.sprite.tint.alpha(fade_gradient.alpha(self.elapsedTime()));
    }

    renderable.draw(body.position, body.scale, body.rotation);
    drawEnemyHit(self, ctx, body.*);
    drawShardShimmer(self, ctx, body.*);
    drawShield(self, ctx, body.*);
}

fn drawEnemyHit(
    self: *Game,
    ctx: Game.EntityContext,
    body: Game.C.Body,
) void {
    if (ctx.tryGetConst(Game.C.Enemy)) |enemy| {
        const t = self.elapsedTime();
        if (enemy.hit_fade_ends_at <= t) return;

        const d = enemy.hit_fade_ends_at - t;
        const ratio: f32 = @floatCast(d / Game.C.Enemy.hit_fade_duration);

        var renderable_fade = enemy.body.body_type.hitSprite(self);
        renderable_fade.sprite.tint = .alpha(.white, ratio);
        renderable_fade.draw(body.position, body.scale, body.rotation);
    }
}

fn drawShardShimmer(
    self: *Game,
    ctx: Game.EntityContext,
    body: Game.C.Body,
) void {
    const shard = ctx.tryGetConst(Game.C.Shard) orelse return;

    const t = self.elapsedTime();

    const time_factor = 6;

    const sweep_ratio = @mod(t * time_factor, 8);
    if (sweep_ratio >= 4) return;

    const p_rel = self.getRelativePos(body.position);
    const d = 1 - @abs((sweep_ratio - 2) - p_rel.x + p_rel.y);
    const ratio: f32 = @floatCast(d);

    var renderable_fade = shard.shimmer_renderable(self);
    renderable_fade.sprite.tint = .alpha(.white, ratio);
    renderable_fade.draw(body.position, body.scale, body.rotation);
}

fn drawShield(
    self: *Game,
    ctx: Game.EntityContext,
    body: Game.C.Body,
) void {
    if (ctx.tryGet(Game.C.Player)) |player| {
        var it = player.shieldIterator();

        while (it.next()) |entry| {
            if (entry.shield.n_charges > 0) {
                entry.shield.shieldSprite(self).draw(body.position, 1, 0);
                return;
            }
        }
    }

    if (ctx.tryGet(Game.C.Enemy)) |enemy| {
        var it = enemy.shieldIterator();

        while (it.next()) |entry| {
            if (entry.shield.n_charges > 0) {
                entry.shield.shieldSprite(self).draw(body.position, 1, 0);
                return;
            }
        }
    }
}

fn drawGrid(self: *Game) void {
    const grid = self.physics().grid orelse return;

    for (0..grid.width) |x| {
        for (0..grid.height) |y| {
            if (!grid.isSolid(self, x, y)) continue;

            const size = grid.cellSize();
            const position = Game.Vector.init(
                @floatFromInt(x),
                @floatFromInt(y),
            ).multiply(size);
            rl.drawRectangleV(position, size, .light_gray);
        }
    }
}

fn drawHUD(self: *Game) void {
    const player = self.player();
    const player_component = player.getConst(Game.C.Player);
    const lives = player_component.lives;
    // const shards = player_component.shards;
    // var position = self.worldCenterTop();
    // position.y += 16;
    // drawTextCentered("LIVES={} SHARDS={}", .{ lives, shards }, 16, position, .white);
    var lives_renderable = self.initSprite(.init(76, 84, 5, 11));
    lives_renderable.sprite.tint = .red;

    var cursor = self.worldTopLeft().add(lives_renderable.size(1, 0));

    for (0..lives) |_| {
        lives_renderable.draw(cursor, 1, 0);
        cursor.x += lives_renderable.size(1, 0).x + 4;
    }

    const enemy_system = self.getSingleton(Game.S.Enemy);
    cursor = self.worldCenterTop();
    drawText("STAGE {}", .{enemy_system.current_stage_index}, 10, cursor, .white);
}
