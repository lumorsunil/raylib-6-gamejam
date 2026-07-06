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

fn drawMenu(self: *Game) void {
    drawGameplay(self);

    const world_pos = self.worldPosition();
    const world_size = self.worldSize();
    rl.drawRectangleV(world_pos, world_size, .alpha(.black, 0.8));

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
    rl.clearBackground(.dark_gray);
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

    const world_pos = self.worldPosition();
    const world_size = self.worldSize();
    rl.drawRectangleV(world_pos, world_size, .alpha(.black, 0.8));

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

fn drawRenderables(self: *Game) void {
    var it = self.entityIterator(.{ Game.C.Renderable, Game.C.Body }, .{Game.C.Invisible});

    while (it.next()) |ctx| {
        const body = ctx.getConst(Game.C.Body);
        const renderable = ctx.getConst(Game.C.Renderable);

        renderable.draw(body.position, body.rotation);

        if (ctx.tryGetConst(Game.C.Enemy)) |enemy| {
            const t = self.elapsedTime();
            if (enemy.hit_fade_ends_at <= t) continue;

            const d = enemy.hit_fade_ends_at - t;
            const ratio: f32 = @floatCast(d / Game.C.Enemy.hit_fade_duration);

            var renderable_fade = renderable;
            renderable_fade.sprite.tint = .alpha(.white, ratio);
            renderable_fade.sprite.source = .init(63, 0, 63, 27);
            renderable_fade.draw(body.position, body.rotation);
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
    var position = self.worldCenterTop();
    position.y += 16;
    drawTextCentered("LIVES={}", .{lives}, 16, position, .white);
}
