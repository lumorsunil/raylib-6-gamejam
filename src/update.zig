const Game = @import("game.zig").Game;

pub fn update(self: *Game) void {
    updateCoreBeforeMain(self);
    updateMain(self);
    updateCoreAfterMain(self);
}

fn updateCoreBeforeMain(self: *Game) void {
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
}

fn updateGameplay(self: *Game) void {
    const background = self.getSingleton(Game.S.Background);
    background.update(self);

    const input = self.input();
    if (input.isPressed(.start)) {
        self.menu.handleEvent(self, .{ .set_menu = .pause });
        self.screen_state = .menu;
        return;
    }

    self.controllable().update(self);
    self.physics().update(self);

    const dot = self.getSingleton(Game.S.DamageOnTouch);
    dot.update(self);

    const player = self.getSingleton(Game.S.Player);
    player.update(self);
    const enemy = self.getSingleton(Game.S.Enemy);
    enemy.update(self);
}

fn updateShop(self: *Game) void {
    _ = self;
}

fn updateModification(self: *Game) void {
    _ = self;
}

fn updateEnding(self: *Game) void {
    _ = self;
}

fn updateGameOver(self: *Game) void {
    if (self.game_over.transition_at <= self.elapsedTime()) {
        self.restart();
    }
}
