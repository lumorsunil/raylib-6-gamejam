const std = @import("std");
const Game = @import("game.zig").Game;
const rl = @import("raylib");

const enable_debug_draw = true;

pub fn draw(self: *Game) void {
    switch (self.screen_state) {
        .logo => drawLogo(self),
        .menu => drawMenu(self),
        .gameplay => drawGameplay(self),
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
    const screen_size = self.screenSize();
    const world_pos = self.worldPosition();
    const world_size = self.worldSize();
    rl.drawRectangleV(.init(0, 0), .init(world_pos.x, screen_size.y), .black);
    rl.drawRectangleV(.init(world_pos.x + world_size.x, 0), .init(screen_size.x, screen_size.y), .black);
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
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, fmt, args) catch unreachable;
    const width = rl.measureText(text, @intFromFloat(font_size));
    const zoomed_width: f32 = @floatFromInt(width);
    var p = position;
    p.x -= zoomed_width / 2;
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
    drawEnemyHit(self, ctx, body.*, renderable);
    drawShardShimmer(self, ctx, body.*);
}

fn drawEnemyHit(
    self: *Game,
    ctx: Game.EntityContext,
    body: Game.C.Body,
    renderable: Game.C.Renderable,
) void {
    if (ctx.tryGetConst(Game.C.Enemy)) |enemy| {
        const t = self.elapsedTime();
        if (enemy.hit_fade_ends_at <= t) return;

        const d = enemy.hit_fade_ends_at - t;
        const ratio: f32 = @floatCast(d / Game.C.Enemy.hit_fade_duration);

        var renderable_fade = renderable;
        renderable_fade.sprite.tint = .alpha(.white, ratio);
        renderable_fade.sprite.source = .init(158, 5, 31, 17);
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
}
