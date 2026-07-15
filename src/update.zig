const std = @import("std");
const Game = @import("game.zig").Game;
const rl = @import("raylib");

pub fn update(self: *Game) void {
    updateCoreBeforeMain(self);
    updateMain(self);
    updateCoreAfterMain(self);
}

fn updateCoreBeforeMain(self: *Game) void {
    self.updateTime();
    self.updateMusic();
    self.input().update();
}

fn updateMain(self: *Game) void {
    switch (self.screen_state) {
        .logo => updateLogo(self),
        .menu => updateMenu(self),
        .gameplay => updateGameplay(self),
        .shop => updateShop(self),
        .modification => updateModification(self),
        .ending => updateEnding(self),
        .game_over => updateGameOver(self),
    }
}

fn updateCoreAfterMain(self: *Game) void {
    const relative_position = self.getSingleton(Game.S.RelativePosition);
    relative_position.update(self);
    self.cameraSystem().update(self);
    self.destroyEntitiesSystem().update(self);
}

fn updateLogo(self: *Game) void {
    if (self.logo.transition_at <= self.elapsedTime()) {
        self.screen_state = .menu;
    }

    const input = self.input();
    if (input.isPressed(.start) or input.isPressed(.shoot)) {
        self.screen_state = .menu;
    }
}

fn updateMenu(self: *Game) void {
    const input = self.input();

    // Keyboard
    if (input.isPressed(.move_down)) {
        self.menu.moveDown();
    }
    if (input.isPressed(.move_up)) {
        self.menu.moveUp();
    }
    if (input.isPressed(.move_left)) {
        self.menu.moveLeft(self);
    }
    if (input.isPressed(.move_right)) {
        self.menu.moveRight(self);
    }
    if (input.isPressed(.shoot) or input.isPressed(.start)) {
        self.menu.execute(self);
    }

    // Mouse
    const mouse_pos = rl.getScreenToWorld2D(rl.getMousePosition(), self.camera().*);

    for (0..self.menu.items.len) |i| {
        const item_rec = self.menu.menuItemRectangle(self, i);
        if (rl.checkCollisionPointRec(mouse_pos, item_rec)) {
            self.menu.selected_item = i;

            if (rl.isMouseButtonPressed(.left)) {
                self.menu.execute(self);
            }

            return;
        }
    }

    if (self.menu.isMenu(Game.Menu.settings_menu) or self.menu.isMenu(Game.Menu.pause_settings_menu)) {
        const vol_rec = self.menu.masterVolumeRectangle(self);

        if (self.settings.is_editing_master_volume or (mouse_pos.y >= vol_rec.y and mouse_pos.y <= vol_rec.y + vol_rec.height)) {
            const ratio = ((mouse_pos.x - vol_rec.x) / vol_rec.width) * Game.Settings.max_master_volume;

            if (ratio >= 0 and ratio <= Game.Settings.max_master_volume) {
                if (rl.isMouseButtonDown(.left) and self.settings.is_editing_master_volume) {
                    self.settings.setMasterVolume(ratio);
                }

                if (rl.isMouseButtonPressed(.left)) {
                    self.settings.is_editing_master_volume = true;
                }
            }
        }

        if (rl.isMouseButtonReleased(.left)) {
            self.settings.is_editing_master_volume = false;
        }
    }
}

fn updateGameplay(self: *Game) void {
    const background = self.getSingleton(Game.S.Background);
    background.update(self);

    const input = self.input();
    if (input.isPressed(.start) or input.isPressed(.cancel)) {
        self.menu.handleEvent(self, .{ .set_menu = .pause });
        self.screen_state = .menu;
        return;
    }

    self.controllable().update(self);
    self.physics().update(self);

    const shield = self.getSingleton(Game.S.Shield);
    shield.update(self);

    const dot = self.getSingleton(Game.S.DamageOnTouch);
    dot.update(self);

    const player = self.getSingleton(Game.S.Player);
    player.update(self);
    const enemy = self.getSingleton(Game.S.Enemy);
    enemy.update(self);

    const animation = self.getSingleton(Game.S.Animation);
    animation.update(self);

    const state_machine = self.getSingleton(Game.S.StateMachine);
    state_machine.update(self);
}

fn updateShop(self: *Game) void {
    _ = self;
}

fn updateModification(self: *Game) void {
    _ = self;
}

fn updateEnding(self: *Game) void {
    if (self.ending_state.ending_ends_at <= self.elapsedTime()) {
        self.restart();
    }
}

fn updateGameOver(self: *Game) void {
    if (self.game_over.transition_at <= self.elapsedTime()) {
        self.restart();
    }
}
