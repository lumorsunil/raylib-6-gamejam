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

    setupEntities(self) catch unreachable;
}

pub fn setupEntities(self: *Game) !void {
    try createPlayer(self);
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

pub fn setupSystems(self: *Game) void {
    const background = self.getSingleton(Game.S.Background);
    background.setup(self);
}

fn createPlayer(self: *Game) !void {
    const player = self.createEntity();
    const position = self.worldCenterBottom();
    // player.add(Game.C.Renderable.initSprite(spritesheet, .init(29, 74, 17, 31)));
    // const renderable = player.get(Game.C.Renderable);
    // renderable.sprite.tint = .red;
    // renderable.sprite.draw_layer = Game.draw_layers.player;
    player.add(try Game.C.Player.init(self.allocator));
    const player_component = player.get(Game.C.Player);
    player_component.body.slots[0] = .weapon_machine_gun;
    player_component.body.slots[1] = .weapon_machine_gun;
    player_component.inventory.items[0] = .weapon_machine_gun;
    player_component.inventory.items[1] = .body_mod_shield;
    var renderable = player_component.body.body_type.sprite(self);
    renderable.sprite.draw_layer = Game.draw_layers.player;
    player.add(renderable);
    const player_size = renderable.size(1, 0);
    player.add(Game.C.Body.init(position.subtract(player_size)));
    player.add(Game.C.Controllable.init());

    // const weapon_ctx = self.createEntity();
    // weapon_ctx.add(Game.C.Body.init(.init(0, 0)));
    // weapon_ctx.add(Game.C.RelativePosition.init(player, .init(0, -8), true));
    // weapon_ctx.add(self.initSprite(.init(76, 55, 7, 14)));
    // const weapon_renderable = weapon_ctx.get(Game.C.Renderable);
    // weapon_renderable.sprite.tint = .sky_blue;
    // weapon_renderable.sprite.draw_layer = Game.draw_layers.player + 1;

    // const player_component = player.get(Game.C.Player);
    // player_component.weapon_ctx = weapon_ctx;
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

fn createDebugShards(self: *Game) void {
    const n_columns = 100;
    const n_rows = 100;
    const size = Game.Vector.init(@floatFromInt(n_columns), @floatFromInt(n_rows));

    for (0..n_columns) |x| {
        for (0..n_rows) |y| {
            const ctx = self.createEntity();
            const position_rel = Game.Vector.init(@floatFromInt(x), @floatFromInt(y)).divide(size);
            const position = self.getAbsolutePos(position_rel);
            ctx.add(Game.C.Body.init(position));
            const shard = Game.C.Shard.init(.small);
            ctx.add(shard);
            ctx.add(shard.renderable(self));
        }
    }
}
