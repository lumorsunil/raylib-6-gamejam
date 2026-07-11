const Game = @import("../game.zig").Game;
const rl = @import("raylib");

pub const Background = struct {
    next_body_at: f64 = 0,

    pub const spawn_rate_min = 0.05;
    pub const spawn_rate_variance = 6;
    pub const velocity_y_min = 10;
    pub const velocity_y_variance = 0;
    pub const star_alpha_variance = 0.5;
    pub const star_alpha_min = 0.3;
    pub const star_brightness_variance = 0.3;
    pub const star_brightness_min = 0.2;

    pub const sprite_sources: []const rl.Rectangle = &.{
        .init(10, 132, 1, 1), // small star
        .init(14, 131, 3, 4), // straight star
        .init(19, 131, 4, 4), // angled star
        .init(27, 127, 18, 17), // earth
        .init(47, 127, 18, 17), // mars
        .init(8, 143, 15, 11), // galaxy
    };

    pub const sprite_sources_weights: []const f32 = &.{
        500, // normal star
        100, // straight star
        100, // angled star
        1, // earth
        1, // mars
        5, // galaxy
    };

    pub const sprite_sources_types: []const SpriteType = &.{
        .star, // normal star
        .star, // straight star
        .star, // angled star
        .planet, // earth
        .planet, // mars
        .galaxy, // galaxy
    };

    pub const SpriteType = enum { star, galaxy, planet };

    pub fn init() @This() {
        return .{};
    }

    pub fn setup(self: *Background, game: *Game) void {
        const simulate_total_time = 30;
        var t: f64 = 0;
        const fps = game.fps();
        const time_step: f64 = 1.0 / @as(f64, fps);

        var ctxs: [1024]Game.EntityContext = undefined;
        var n_ctxs: usize = 0;

        while (t < simulate_total_time) {
            if (self.next_body_at <= t) {
                const ctx = self.spawnBody(game, t);
                ctxs[n_ctxs] = ctx;
                n_ctxs += 1;
            }

            for (0..n_ctxs) |i| {
                const body = ctxs[i].get(Game.C.Body);
                body.position = body.position.add(body.velocity.scale(@floatCast(time_step)));
            }

            t += time_step;
        }

        self.next_body_at = 0;
    }

    pub fn update(self: *Background, game: *Game) void {
        const t = game.elapsedTime();

        if (self.next_body_at <= t) {
            _ = self.spawnBody(game, t);
        }
    }

    fn spawnBody(self: *Background, game: *Game, t: f64) Game.EntityContext {
        self.next_body_at = t + game.random().float(f64) * spawn_rate_variance + spawn_rate_min;

        const world_size = game.worldSize();
        const world_pos = game.worldPosition();

        const ctx = game.createEntity();
        var position = Game.Vector.init(game.random().float(f32), 0);
        position = position.multiply(world_size).add(world_pos);
        ctx.add(Game.C.Body.init(position));
        const body = ctx.get(Game.C.Body);
        body.velocity.y = game.random().float(f32) * velocity_y_variance + velocity_y_min;
        ctx.add(randomSprite(game));
        ctx.add(Game.C.Background.init());

        return ctx;
    }

    fn randomColor(game: *Game) Game.Color {
        return .fromHSV(
            game.random().float(f32) * 360,
            game.random().float(f32),
            game.random().float(f32) * star_brightness_variance + star_brightness_min,
        );
    }

    fn randomAlpha(game: *Game) f32 {
        _ = game;
        return 1;
        // return game.random().float(f32) * star_alpha_variance + star_alpha_min;
    }

    fn randomSprite(game: *Game) Game.C.Renderable {
        const i = game.random().weightedIndex(f32, sprite_sources_weights);
        var sprite = game.initSprite(sprite_sources[i]);
        sprite.sprite.draw_layer = Game.draw_layers.background;
        if (sprite_sources_types[i] != .planet) {
            const color = randomColor(game);
            const alpha = randomAlpha(game);
            sprite.sprite.tint = .alpha(color, alpha);
        }
        return sprite;
    }
};
