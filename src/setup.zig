const std = @import("std");
const Game = @import("game.zig").Game;
const rl = @import("raylib");
const Logo = @import("logo.zig").Logo;
const Sound = @import("sound.zig").Sound;
const Sounds = @import("sound.zig").Sounds;
const Music = @import("music.zig").Music;
const Musics = @import("music.zig").Musics;
const Animations = @import("animation.zig").Animations;

pub fn setup(self: *Game) void {
    initRaylib(self);
    initLogo(self) catch unreachable;
    initMenu(self);

    createCamera(self);
    createSpritesheet(self);
    createSounds(self) catch unreachable;
    createMusic(self) catch unreachable;
    createAnimations(self);

    createSystems(self);
    setupSystems(self);
    // createDefaultGrid(self) catch unreachable;

    setupEntities(self) catch unreachable;

    self.playMusic(.theme);
}

pub fn setupEntities(self: *Game) !void {
    try createPlayer(self);
}

fn initRaylib(self: *Game) void {
    const screen_size = self.screenSize();
    rl.initWindow(@intFromFloat(screen_size.x), @intFromFloat(screen_size.y), "Game Template");
    rl.initAudioDevice();
    // rl.setAudioStreamBufferSizeDefault(4096);
    rl.setMasterVolume(self.settings.master_volume);
    rl.setExitKey(.null);

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

fn createSounds(self: *Game) !void {
    var sounds: Sounds = undefined;

    inline for (std.enums.values(Sound)) |sound| {
        @field(sounds, @tagName(sound)) = try rl.loadSound(sound.filename());
    }

    self.addSingleton(sounds);
}

fn createMusic(self: *Game) !void {
    self.addSingleton(@as(Musics, undefined));
    const musics = self.getSingleton(Musics);

    inline for (std.enums.values(Music)) |music| {
        @field(musics, @tagName(music)) = rl.loadMusicStream(music.filename()) catch |err| {
            std.log.err("could not load music file {s}: {}", .{ music.filename(), err });
            return;
        };
    }
}

fn createAnimations(self: *Game) void {
    const shield_recharge = self.allocator.alloc(Game.C.Renderable, 10) catch unreachable;
    shield_recharge[0] = self.initSprite(.init(432, 367, 47, 46));
    shield_recharge[1] = self.initSprite(.init(384, 367, 47, 46));
    shield_recharge[2] = self.initSprite(.init(336, 367, 47, 46));
    shield_recharge[3] = self.initSprite(.init(288, 367, 47, 46));
    shield_recharge[4] = self.initSprite(.init(240, 367, 47, 46));
    shield_recharge[5] = self.initSprite(.init(192, 367, 47, 46));
    shield_recharge[6] = self.initSprite(.init(144, 367, 47, 46));
    shield_recharge[7] = self.initSprite(.init(96, 367, 47, 46));
    shield_recharge[8] = self.initSprite(.init(48, 367, 47, 46));
    shield_recharge[9] = self.initSprite(.init(0, 367, 47, 46));

    const shield_dissipate = self.allocator.alloc(Game.C.Renderable, 3) catch unreachable;
    shield_dissipate[0] = self.initSprite(.init(336, 414, 47, 46));
    shield_dissipate[1] = self.initSprite(.init(383, 414, 47, 46));
    shield_dissipate[2] = self.initSprite(.init(430, 414, 47, 46));

    const enemy_bullet_spawn = self.allocator.alloc(Game.C.Renderable, 6) catch unreachable;
    enemy_bullet_spawn[0] = self.initSprite(.init(261, 132, 4, 6));
    enemy_bullet_spawn[1] = self.initSprite(.init(266, 132, 4, 6));
    enemy_bullet_spawn[2] = self.initSprite(.init(271, 132, 4, 6));
    enemy_bullet_spawn[3] = self.initSprite(.init(276, 132, 4, 6));
    enemy_bullet_spawn[4] = self.initSprite(.init(281, 132, 4, 6));
    enemy_bullet_spawn[5] = self.initSprite(.init(286, 132, 6, 6));

    const enemy_bullet_blue_spawn = self.allocator.alloc(Game.C.Renderable, 6) catch unreachable;
    enemy_bullet_blue_spawn[0] = self.initSprite(.init(261, 141, 4, 6));
    enemy_bullet_blue_spawn[1] = self.initSprite(.init(266, 141, 4, 6));
    enemy_bullet_blue_spawn[2] = self.initSprite(.init(271, 141, 4, 6));
    enemy_bullet_blue_spawn[3] = self.initSprite(.init(276, 141, 4, 6));
    enemy_bullet_blue_spawn[4] = self.initSprite(.init(281, 141, 4, 6));
    enemy_bullet_blue_spawn[5] = self.initSprite(.init(286, 141, 6, 6));

    const animations = Animations{
        .shield_recharge = .init(shield_recharge, 0.05),
        .shield_dissipate = .init(shield_dissipate, 0.1),
        .enemy_bullet_spawn = .init(enemy_bullet_spawn, 0.1),
        .enemy_bullet_blue_spawn = .init(enemy_bullet_blue_spawn, 0.1),
    };

    self.addSingleton(animations);
}

fn createSystems(self: *Game) void {
    self.addSingleton(Game.S.Animation.init());
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
    self.addSingleton(Game.S.Shield.init());
    self.addSingleton(Game.S.StateMachine.init());
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
    player.add(try Game.C.Player.init(self));
    const player_component = player.get(Game.C.Player);
    player_component.body.slots[0] = .weapon_machine_gun;
    player_component.body.slots[0].?.owner = player;
    // player_component.body.slots[1] = .body_mod_shield;
    // player_component.body.slots[1].?.owner = player;
    // player_component.inventory.items[0] = .weapon_machine_gun;
    // player_component.inventory.items[0].?.owner = player;
    // player_component.inventory.items[1] = .body_mod_shield;
    // player_component.inventory.items[1].?.owner = player;
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
