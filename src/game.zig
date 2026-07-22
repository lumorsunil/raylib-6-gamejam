const std = @import("std");
const ecs = @import("ecs");
const rl = @import("raylib");
const emscripten = std.os.emscripten;
const Sound = @import("sound.zig").Sound;
const Sounds = @import("sound.zig").Sounds;
const Music = @import("music.zig").Music;
const Musics = @import("music.zig").Musics;
const AnimationKey = @import("animation.zig").AnimationKey;
const AnimationType = @import("animation.zig").AnimationType;
const Animations = @import("animation.zig").Animations;
const Animation = @import("animation.zig").Animation;
const Ending = @import("ending.zig").Ending;

const Mode = enum { dev, prod };

const mode: Mode = .prod;

pub const Game = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    reg: ecs.Registry,
    random_io: std.Random.IoSource,
    screen_state: ScreenState = if (mode == .prod) .menu else .debug,
    logo: Logo = .init(0),
    menu: Menu = .init(),
    settings: Settings = .init(),
    shop_state: Shop,
    modification_state: ModificationState = .init(),
    game_over: GameOver = .init(0),
    wants_to_quit: bool = false,
    ending_state: Ending = .init(),
    current_music: ?rl.Music = null,
    elapsed_time: f64 = 0,
    delta_time: f32 = 0,
    physics_frames: usize = 0,
    rem_time: f32 = 0,
    is_paused: bool = false,
    draw_layer_lists: [4]std.ArrayList(ecs.Entity) = undefined,

    pub const max_physics_frames = 1;

    pub const ScreenState = enum {
        logo,
        menu,
        gameplay,
        shop,
        modification,
        ending,
        game_over,
        debug,
    };

    pub const ztracy = @import("ztracy");

    pub const Logo = @import("logo.zig").Logo;
    pub const Menu = @import("menu.zig").Menu;
    pub const Settings = @import("settings.zig").Settings;
    pub const Shop = @import("shop.zig").Shop;
    pub const ModificationState = @import("modification-state.zig").ModificationState;
    pub const GameOver = @import("game-over.zig").GameOver;

    pub const Camera = rl.Camera2D;
    pub const Vector = rl.Vector2;
    pub const Color = rl.Color;
    pub const Texture = rl.Texture2D;

    pub const C = @import("components.zig");
    pub const S = @import("systems.zig");

    pub fn init(io: std.Io, allocator: std.mem.Allocator) !@This() {
        return .{
            .io = io,
            .allocator = allocator,
            .reg = .init(allocator),
            .random_io = .{ .io = io },
            .shop_state = try .init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        const player_ctx = self.player();
        const player_component = player_ctx.get(Game.C.Player);
        player_component.deinit(self.allocator);
        self.physics().deinit(self.allocator);
        self.shop_state.deinit(self.allocator);
        const animations = self.getSingleton(Animations);
        inline for (std.meta.fields(Animations)) |field| {
            self.allocator.free(@field(animations, field.name).frames);
        }
        self.reg.deinit();
        rl.closeAudioDevice();
        rl.closeWindow();
    }

    pub const ZoneCtx = struct {
        ctx: ztracy.ZoneCtx,

        pub fn init(ctx: ztracy.ZoneCtx) @This() {
            return .{ .ctx = ctx };
        }

        pub fn end(self: @This()) void {
            self.ctx.End();
        }
    };

    pub fn tracyZoneN(comptime src: std.builtin.SourceLocation, label: [*:0]const u8) ZoneCtx {
        return .init(ztracy.ZoneN(src, label));
    }

    pub fn tracyZoneNC(
        comptime src: std.builtin.SourceLocation,
        label: [*:0]const u8,
        color: Color,
    ) ZoneCtx {
        return .init(ztracy.ZoneNC(src, label, @bitCast(color.toInt())));
    }

    var emscripten_game_ptr: *Game = undefined;

    pub fn run(self: *@This()) void {
        if (@import("builtin").cpu.arch.isWasm()) {
            emscripten_game_ptr = self;
            emscripten.emscripten_set_main_loop(emscripten_loop, 0, 1);
        } else {
            while (!rl.windowShouldClose() and !self.wants_to_quit) self.loop();
        }
    }

    fn emscripten_loop() callconv(.c) void {
        loop(emscripten_game_ptr);
    }

    fn loop(self: *@This()) void {
        self.update();
        rl.beginDrawing();
        self.draw();
        rl.endDrawing();
    }

    pub const setup = @import("setup.zig").setup;
    pub const update = @import("update.zig").update;
    pub const draw = @import("draw.zig").draw;

    pub fn zoom(_: @This()) f32 {
        if (mode == .dev) {
            return 3;
        } else {
            return 2;
        }
    }

    pub fn fps(_: @This()) u8 {
        return 60;
    }

    pub fn physicsFps(_: @This()) u8 {
        return 60;
    }

    pub fn physicsTimeStep(self: @This()) f32 {
        return 1.0 / @as(f32, self.physicsFps());
    }

    pub fn elapsedTime(self: @This()) f64 {
        return self.elapsed_time;
    }

    pub fn elapsedRealTime(_: @This()) f64 {
        return rl.getTime();
    }

    pub fn deltaTime(self: @This()) f32 {
        return self.delta_time;
    }

    pub fn deltaRealTime(_: @This()) f32 {
        return rl.getFrameTime();
    }

    pub fn screenSize(_: @This()) Vector {
        if (mode == .dev) {
            return .init(1080, 1080);
        } else {
            return .init(720, 720);
        }
    }

    pub fn worldSize(self: @This()) Vector {
        if (mode == .dev) {
            const base_x = 608;
            const base_y = 1080;
            const z = self.zoom();
            return .init(base_x / z, base_y / z);
        } else {
            const base_x = 405;
            const base_y = 720;
            const z = self.zoom();
            return .init(base_x / z, base_y / z);
        }
    }

    pub fn getAbsolutePos(self: @This(), position: Vector) Vector {
        return position.multiply(self.worldSize()).add(self.worldPosition());
    }

    pub fn getRelativePos(self: @This(), position: Vector) Vector {
        return position.subtract(self.worldPosition()).divide(self.worldSize());
    }

    pub fn worldCenter(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos);
    }

    pub fn worldCenterBottom(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos).multiply(.init(1, 2));
    }

    pub fn worldCenterTop(self: @This()) Vector {
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        return world_size.scale(0.5).add(world_pos).multiply(.init(1, 0));
    }

    pub fn worldTopLeft(self: @This()) Vector {
        return self.getAbsolutePos(.init(0, 0));
    }

    pub fn worldPosition(self: @This()) Vector {
        const screen_size = self.screenSize().scale(1 / self.zoom());
        const world_size = self.worldSize();
        return .init(screen_size.x / 2 - world_size.x / 2, 0);
    }

    pub fn addSingleton(self: *@This(), singleton: anytype) void {
        self.reg.singletons().add(singleton);
    }

    pub fn getSingleton(self: *@This(), comptime T: type) *T {
        return self.reg.singletons().get(T);
    }

    pub fn getSingletonConst(self: *@This(), comptime T: type) T {
        return self.reg.singletons().getConst(T);
    }

    fn singletonFn(comptime T: type) fn (*Game) *T {
        return struct {
            pub fn get(self: *Game) *T {
                return self.getSingleton(T);
            }
        }.get;
    }

    fn singletonConstFn(comptime T: type) fn (*Game) T {
        return struct {
            pub fn get(self: *Game) T {
                return self.getSingletonConst(T);
            }
        }.get;
    }

    pub const camera = singletonFn(Camera);
    pub const cameraSystem = singletonFn(Game.S.Camera);
    pub const input = singletonFn(Game.S.Input);
    pub const physics = singletonFn(Game.S.Physics);
    pub const controllable = singletonFn(Game.S.Controllable);
    pub const destroyEntitiesSystem = singletonFn(Game.S.DestroyEntities);
    pub const spritesheet = singletonConstFn(Texture);

    pub fn initSprite(self: *@This(), source: rl.Rectangle) Game.C.Renderable {
        return .initSprite(self.spritesheet(), source);
    }

    pub fn createEntity(self: *@This()) EntityContext {
        return .init(self, self.reg.create());
    }

    pub fn destroyEntity(self: *@This(), entity: ecs.Entity) void {
        const destroy_entities = self.getSingleton(Game.S.DestroyEntities);
        destroy_entities.destroy(entity);
    }

    pub fn getOneByTag(self: *@This(), comptime T: type) EntityContext {
        var it = self.entityIterator(.{T}, .{});
        return it.next().?;
    }

    pub fn tryGetOneByTag(self: *@This(), comptime T: type) ?EntityContext {
        var it = self.entityIterator(.{T}, .{});
        return it.next();
    }

    pub const EntityContext = struct {
        game: *Game,
        entity: ecs.Entity,

        pub fn init(game: *Game, entity: ecs.Entity) @This() {
            return .{ .game = game, .entity = entity };
        }

        pub fn equals(self: EntityContext, other: EntityContext) bool {
            return self.entity.index == other.entity.index and self.entity.version == other.entity.version;
        }

        pub fn has(self: EntityContext, comptime T: type) bool {
            return self.game.reg.has(T, self.entity);
        }

        pub fn get(self: EntityContext, comptime T: type) *T {
            return self.game.reg.get(T, self.entity);
        }

        pub fn getConst(self: EntityContext, comptime T: type) T {
            return self.game.reg.getConst(T, self.entity);
        }

        pub fn tryGet(self: EntityContext, comptime T: type) ?*T {
            return self.game.reg.tryGet(T, self.entity);
        }

        pub fn tryGetConst(self: EntityContext, comptime T: type) ?T {
            return self.game.reg.tryGetConst(T, self.entity);
        }

        pub fn getOrAdd(self: EntityContext, comptime T: type) *T {
            return self.tryGet(T) orelse brk: {
                self.add(@as(T, undefined));
                break :brk self.get(T);
            };
        }

        pub fn add(self: EntityContext, component: anytype) void {
            if (@TypeOf(component) == Game.C.Renderable) {
                return self.addRenderable(component);
            }
            return self.game.reg.addOrReplace(self.entity, component);
        }

        pub fn remove(self: EntityContext, comptime T: type) void {
            return self.game.reg.removeIfExists(T, self.entity);
        }

        pub fn destroy(self: EntityContext) void {
            self.game.destroyEntity(self.entity);
        }

        pub fn valid(self: EntityContext) bool {
            return self.game.reg.valid(self.entity);
        }

        pub fn addBody(self: @This(), position: Vector) *Game.C.Body {
            const body = Game.C.Body.init(self, position);
            self.add(body);
            return self.get(Game.C.Body);
        }

        pub fn addRenderable(self: @This(), renderable: Game.C.Renderable) void {
            self.game.reg.addOrReplace(self.entity, renderable);
            self.game.draw_layer_lists[renderable.layer()].append(self.game.allocator, self.entity) catch unreachable;
        }
    };

    fn EntityIterator(comptime includes: anytype, comptime excludes: anytype) type {
        const View, const Iterator = comptime brk: {
            if (includes.len == 1 and excludes.len == 0) break :brk .{ ecs.BasicView(includes[0]), ecs.utils.ReverseSliceIterator(ecs.Entity) };
            break :brk .{ ecs.MultiView(includes, excludes), ecs.MultiView(includes, excludes).Iterator };
        };

        return struct {
            game: *Game,
            view: View,
            it: ?Iterator = null,

            pub fn init(game: *Game, view: View) @This() {
                return .{ .game = game, .view = view };
            }

            pub fn next(self: *@This()) ?EntityContext {
                const it = self.getIt();
                const entity = it.next() orelse return null;
                return .init(self.game, entity);
            }

            pub fn reset(self: *@This()) void {
                const it = self.getIt();
                it.reset();
            }

            fn getIt(self: *@This()) *Iterator {
                if (self.it) |*it| return it;
                self.it = self.view.entityIterator();
                return &(self.it.?);
            }
        };
    }

    pub fn entityIterator(
        self: *@This(),
        comptime includes: anytype,
        comptime excludes: anytype,
    ) EntityIterator(includes, excludes) {
        return .init(self, self.reg.view(includes, excludes));
    }

    pub fn random(self: *@This()) std.Random {
        return self.random_io.interface();
    }

    pub fn hitbox(_: *@This(), ctx: EntityContext) Game.C.Hitbox {
        const body = ctx.get(Game.C.Body);
        var hitbox_component = ctx.tryGetConst(Game.C.Hitbox) orelse {
            const renderable = ctx.get(Game.C.Renderable);
            const size = renderable.size(1, body.rotation());
            const origin = renderable.origin(1, body.rotation());
            const position = body.position().subtract(origin);

            return .init(position, size);
        };

        const origin = hitbox_component.size().scale(0.5);
        const position = body.position().subtract(origin).add(hitbox_component.position());
        hitbox_component.setPosition(position);

        return hitbox_component;
    }

    pub fn player(self: *Game) EntityContext {
        return self.getOneByTag(Game.C.Player);
    }

    pub fn gameOver(self: *Game) void {
        self.game_over = .init(self.elapsedTime());
        self.screen_state = .game_over;
    }

    pub fn restart(self: *Game) void {
        self.playMusic(.theme);
        self.menu.setMenu(Menu.main_menu);
        self.screen_state = .menu;
        self.destroyAllEntities();
        @import("setup.zig").setupEntities(self) catch unreachable;
        @import("setup.zig").setupSystems(self);
        const enemy_system = self.getSingleton(Game.S.Enemy);
        enemy_system.reset(self) catch unreachable;
    }

    fn destroyAllEntities(self: *Game) void {
        var it = self.reg.entities();

        while (it.next()) |entity| {
            self.destroyEntity(entity);
        }

        self.destroyEntitiesSystem().update(self);
    }

    pub fn ending(self: *Game) void {
        self.screen_state = .ending;
        self.ending_state.setup(self);
    }

    pub const OutOfBoundsRules = enum {
        all_directions,
        allow_bottom,
        allow_top,
    };

    pub fn isOutOfBounds(self: *Game, ctx: EntityContext, rules: OutOfBoundsRules) bool {
        const hitbox_ = self.hitbox(ctx);
        const world_pos = self.worldPosition();
        const world_size = self.worldSize();

        if (hitbox_.right() - world_pos.x <= 0) return true;
        if (rules != .allow_top and hitbox_.bottom() - world_pos.y <= 0) return true;
        if (hitbox_.left() - world_pos.x - world_size.x >= 0) return true;
        if (rules != .allow_bottom and hitbox_.top() - world_pos.y - world_size.y >= 0) return true;

        return false;
    }

    pub const draw_layers: struct {
        background: usize,
        enemy: usize,
        player: usize,
    } = .{
        .background = 0,
        .enemy = 1,
        .player = 2,
    };

    pub fn shop(self: *Game) void {
        self.playMusic(.shop);
        self.screen_state = .shop;
        self.shop_state.setup(self) catch unreachable;
    }

    pub fn modification(self: *Game) void {
        self.screen_state = .modification;
        self.modification_state.setup(self);
    }

    pub fn startGame(self: *Game) void {
        self.modification();
        // self.screen_state = .gameplay;
        // self.nextStage();
    }

    pub fn unpause(self: *Game) void {
        self.screen_state = .gameplay;
    }

    pub fn nextStage(self: *Game) void {
        self.screen_state = .gameplay;
        const enemy_system = self.getSingleton(Game.S.Enemy);
        enemy_system.nextStage(self) catch unreachable;
        switch (enemy_system.current_stage_index) {
            1 => self.playMusic(.stage_1),
            2 => self.playMusic(.stage_2),
            3 => self.playMusic(.stage_3),
            4 => self.playMusic(.stage_1),
            5 => self.playMusic(.stage_2),
            6 => self.playMusic(.stage_3),
            7 => self.playMusic(.stage_1),
            8 => self.playMusic(.stage_2),
            9 => self.playMusic(.stage_3),
            10 => self.playMusic(.stage_1),
            11 => self.playMusic(.stage_2),
            12 => self.playMusic(.stage_3),
            else => {},
        }
        enemy_system.setup(self);

        var it = self.entityIterator(.{Game.C.Body}, .{ Game.C.Player, Game.C.Background });
        while (it.next()) |ctx| ctx.destroy();
    }

    pub fn updateMusic(self: *Game) void {
        const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
        defer zone.end();

        const music = self.current_music orelse return;
        rl.updateMusicStream(music);
    }

    pub fn getMusic(self: *Game, comptime music: Music) rl.Music {
        const musics = self.getSingleton(Musics);
        return @field(musics, @tagName(music));
    }

    pub fn playMusic(self: *Game, comptime music_key: Music) void {
        const music = self.getMusic(music_key);
        rl.playMusicStream(music);
        self.current_music = music;
    }

    pub fn isMusicPlaying(self: *Game, comptime music: Music) bool {
        return rl.isMusicStreamPlaying(self.getMusic(music));
    }

    pub fn getSound(self: *Game, comptime sound: Sound) rl.Sound {
        const sounds = self.getSingleton(Sounds);
        return @field(sounds, @tagName(sound));
    }

    pub fn playSound(self: *Game, comptime sound: Sound) void {
        rl.playSound(self.getSound(sound));
    }

    pub fn isSoundPlaying(self: *Game, comptime sound: Sound) bool {
        return rl.isSoundPlaying(self.getSound(sound));
    }

    pub fn getAnimation(self: *Game, comptime animation: AnimationKey) AnimationType {
        const animations = self.getSingleton(Animations);
        return @field(animations, @tagName(animation));
    }

    pub fn newAnimation(
        self: *Game,
        comptime animation_key: AnimationKey,
        is_looping: bool,
    ) Animation {
        var animation: Animation = .init(self.getAnimation(animation_key));
        animation.is_looping = is_looping;
        animation.start(self.elapsedTime());
        return animation;
    }

    pub fn pauseTime(self: *@This()) void {
        self.is_paused = true;
    }

    pub fn unpauseTime(self: *@This()) void {
        self.is_paused = false;
    }

    pub fn updateTime(self: *@This()) void {
        const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
        defer zone.end();

        if (self.is_paused) return;
        const time_step = self.physicsTimeStep();
        var dt = self.deltaRealTime();
        const f_last_physics_frames: f32 = @floatFromInt(self.physics_frames);
        self.elapsed_time += f_last_physics_frames * time_step;
        const f_desired_physics_frames: f32 = @divFloor(dt + self.rem_time, time_step);
        const f_physics_frames: f32 = @min(max_physics_frames, f_desired_physics_frames);
        const physics_delta_time = f_physics_frames * time_step;
        const f_desired_delta = f_desired_physics_frames - f_physics_frames;
        dt -= f_desired_delta * time_step;
        self.physics_frames = @intFromFloat(f_physics_frames);
        self.rem_time -= physics_delta_time - dt;
        self.delta_time = physics_delta_time;
    }
};
