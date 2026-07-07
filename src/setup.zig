const Game = @import("game.zig").Game;
const rl = @import("raylib");
const Logo = @import("logo.zig").Logo;

pub fn setup(self: *Game) void {
    initRaylib(self);
    initLogo(self) catch unreachable;
    initMenu(self);

    createCamera(self);
    createSpritesheet(self);
    createSystems(self);
    setupSystems(self);
    // createDefaultGrid(self) catch unreachable;

    setupEntities(self);
}

pub fn setupEntities(self: *Game) void {
    createPlayer(self);
}

fn initRaylib(self: *Game) void {
    const screen_size = self.screenSize();
    rl.initWindow(@intFromFloat(screen_size.x), @intFromFloat(screen_size.y), "Game Template");

    if (@import("builtin").cpu.arch.isWasm()) return;

    rl.setWindowPosition(24, 48);
    rl.setTargetFPS(self.fps());
}

fn initLogo(self: *Game) !void {
    try self.logo.load();
}

fn initMenu(self: *Game) void {
    self.menu.items = Game.Menu.main_menu;
}

fn createCamera(self: *Game) void {
    self.addSingleton(Game.Camera{
        .offset = .zero(),
        .target = .zero(),
        .rotation = 0,
        .zoom = self.zoom(),
    });
}

fn createSpritesheet(self: *Game) void {
    const spritesheet = rl.loadTexture("src/resources/spritesheet.png") catch unreachable;
    self.addSingleton(spritesheet);
}

fn createSystems(self: *Game) void {
    self.addSingleton(Game.S.Background.init());
    self.addSingleton(Game.S.Camera.init());
    self.addSingleton(Game.S.Controllable.init());
    self.addSingleton(Game.S.DamageOnTouch.init());
    self.addSingleton(Game.S.DestroyEntities.init());
    self.addSingleton(Game.S.Enemy.init());
    self.addSingleton(Game.S.Input.init());
    self.addSingleton(Game.S.Physics.init());
    self.addSingleton(Game.S.Player.init());
    self.addSingleton(Game.S.RelativePosition.init());
}

fn setupSystems(self: *Game) void {
    const background = self.getSingleton(Game.S.Background);
    background.setup(self);
}

fn createPlayer(self: *Game) void {
    const player = self.createEntity();
    const position = self.worldCenterBottom();
    const spritesheet = self.spritesheet();
    player.add(Game.C.Renderable.initSprite(spritesheet, .init(29, 74, 17, 31)));
    const renderable = player.get(Game.C.Renderable);
    renderable.sprite.tint = .red;
    renderable.sprite.draw_layer = Game.draw_layers.player;
    const player_size = renderable.size(1, 0);
    player.add(Game.C.Body.init(position.subtract(player_size)));
    player.add(Game.C.Controllable.init());
    player.add(Game.C.Player.init());
}

fn createDefaultGrid(self: *Game) !void {
    const grid = try Game.S.Physics.DefaultGrid.init(self.allocator, 10, 8);

    for (0..grid.width) |x| {
        for (0..grid.height) |y| {
            const cell = &grid.data[x + y * grid.width];

            if (y == grid.height - 2 and x > 0 and x < grid.width - 1) {
                cell.is_solid = true;
            } else {
                cell.is_solid = false;
            }
        }
    }

    self.physics().grid = grid;
}
