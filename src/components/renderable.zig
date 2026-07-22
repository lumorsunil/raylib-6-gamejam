const std = @import("std");
const Game = @import("../game.zig").Game;
const rl = @import("raylib");

pub const Renderable = union(enum) {
    rectangle: Rectangle,
    sprite: Sprite,
    polygon: Polygon,
    player: Player,
    enemy: Enemy,
    shard: Shard,

    pub fn draw(
        self: Renderable,
        ctx: ?Game.EntityContext,
        position: Game.Vector,
        scale: f32,
        rotation: f32,
    ) void {
        const zone = Game.tracyZoneN(@src(), @src().fn_name);
        defer zone.end();
        switch (self) {
            inline else => |s| s.draw(ctx, position, scale, rotation),
        }
    }

    pub fn size(self: Renderable, scale: f32, rotation: f32) Game.Vector {
        return switch (self) {
            inline else => |s| s.size(rotation).scale(scale),
        };
    }

    pub fn layer(self: Renderable) usize {
        return switch (self) {
            inline else => |s| s.layer(),
        };
    }

    pub fn origin(self: Renderable, scale: f32, rotation: f32) Game.Vector {
        return self.size(scale, rotation).scale(0.5);
    }

    pub fn containsPoint(
        self: Renderable,
        position: Game.Vector,
        point: Game.Vector,
        scale: f32,
        rotation: f32,
    ) bool {
        const size_ = self.size(scale, rotation);
        const p = position.subtract(self.origin(scale, rotation));
        const rec = rl.Rectangle.init(p.x, p.y, size_.x, size_.y);
        return rl.checkCollisionPointRec(point, rec);
    }

    pub fn initRectangle(rec_size: Game.Vector, color: Game.Color) @This() {
        return .{ .rectangle = .{ .rec_size = rec_size, .color = color } };
    }

    pub fn initSprite(texture: rl.Texture2D, source: rl.Rectangle) @This() {
        return .{ .sprite = .{ .texture = texture, .source = source } };
    }

    pub fn initPolygon(points: []const Game.Vector, scale: f32, thickness: f32) @This() {
        return .{ .polygon = .{ .points = points, .scale = scale, .thickness = thickness } };
    }

    pub const Rectangle = struct {
        rec_size: Game.Vector,
        color: Game.Color,

        pub fn draw(
            self: Rectangle,
            _: ?Game.EntityContext,
            position: Game.Vector,
            _: f32,
            rotation: f32,
        ) void {
            rl.drawRectanglePro(.init(
                position.x,
                position.y,
                self.rec_size.x,
                self.rec_size.y,
            ), .init(0, 0), rotation, self.color);
        }

        pub fn size(self: Rectangle, _: f32) Game.Vector {
            return self.rec_size;
        }

        pub fn layer(_: Rectangle) usize {
            return 0;
        }
    };

    pub const Sprite = struct {
        texture: rl.Texture2D,
        source: rl.Rectangle,
        tint: rl.Color = .white,
        draw_layer: usize = 1,

        pub fn draw(
            self: Sprite,
            _: ?Game.EntityContext,
            position: Game.Vector,
            scale: f32,
            rotation: f32,
        ) void {
            const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
            defer zone.end();

            var dest = self.source;
            dest.x = position.x;
            dest.y = position.y;
            dest.width *= scale;
            dest.height *= scale;
            const origin_ = origin(.{ .sprite = self }, scale, rotation);
            rl.drawTexturePro(self.texture, self.source, dest, origin_, rotation * 180 / std.math.pi, self.tint);
        }

        pub fn size(self: Sprite, _: f32) Game.Vector {
            return .init(self.source.width, self.source.height);
        }

        pub fn layer(self: Sprite) usize {
            return self.draw_layer;
        }
    };

    pub const Polygon = struct {
        points: []const Game.Vector,
        thickness: f32 = 1,
        scale: f32 = 1,
        color: Game.Color = .white,

        pub fn draw(
            self: Polygon,
            _: ?Game.EntityContext,
            position: Game.Vector,
            _: f32,
            rotation: f32,
        ) void {
            for (0..self.points.len) |i| {
                const start = self.points[i].scale(self.scale).rotate(rotation).add(position);
                const end = self.points[(i + 1) % self.points.len].scale(self.scale).rotate(rotation).add(position);
                rl.drawLineEx(start, end, self.thickness, self.color);
            }
        }

        pub fn size(self: Polygon, rotation: f32) Game.Vector {
            var min_x = std.math.inf(f32);
            var max_x = -std.math.inf(f32);
            var min_y = std.math.inf(f32);
            var max_y = -std.math.inf(f32);

            for (self.points) |p| {
                const rp = p.rotate(rotation);
                min_x = @min(min_x, rp.x);
                max_x = @max(max_x, rp.x);
                min_y = @min(min_y, rp.y);
                max_y = @max(max_y, rp.y);
            }

            const min_max = Game.Vector.init(max_x - min_x, max_y - min_y);

            return min_max.scale(self.scale);
        }

        pub fn layer(_: Polygon) usize {
            return 0;
        }
    };

    pub const Player = struct {
        sprite: Sprite,

        pub fn draw(
            self: Player,
            maybe_ctx: ?Game.EntityContext,
            position: Game.Vector,
            scale: f32,
            rotation: f32,
        ) void {
            const ctx = maybe_ctx orelse return;
            const player_component = ctx.get(Game.C.Player);
            if (player_component.destroyed_at) |_| {
                return;
            }

            self.sprite.draw(maybe_ctx, position, scale, rotation);

            var shield_it = player_component.shieldIterator();

            var has_shield_item = false;
            while (shield_it.next()) |entry| {
                has_shield_item = true;
                if (entry.shield.n_charges > 0) {
                    if (player_component.shield_animation.isDone()) {
                        entry.shield.shieldSprite(ctx.game).draw(null, position, 1, 0);
                    } else {
                        player_component.shield_animation.currentFrame().draw(null, position, 1, 0);
                    }
                    return;
                }
            }

            if (has_shield_item and !player_component.shield_animation.isDone()) {
                player_component.shield_animation.currentFrame().draw(null, position, 1, 0);
            }
        }

        pub fn size(self: Player, rotation: f32) Game.Vector {
            return self.sprite.size(rotation);
        }

        pub fn layer(self: Player) usize {
            return self.sprite.layer();
        }
    };

    pub const Enemy = struct {
        sprite: Sprite,

        pub fn draw(
            self: Enemy,
            maybe_ctx: ?Game.EntityContext,
            position: Game.Vector,
            scale: f32,
            rotation: f32,
        ) void {
            self.sprite.draw(maybe_ctx, position, scale, rotation);

            const ctx = maybe_ctx orelse return;
            const enemy = ctx.get(Game.C.Enemy);
            const t = ctx.game.elapsedTime();
            if (enemy.hit_fade_ends_at <= t) return;

            const d = enemy.hit_fade_ends_at - t;
            const ratio: f32 = @floatCast(d / Game.C.Enemy.hit_fade_duration);

            var renderable_fade = enemy.body.body_type.hitSprite(ctx.game);
            renderable_fade.sprite.tint = .alpha(.white, ratio);
            renderable_fade.draw(null, position, scale, rotation);

            var shield_it = enemy.shieldIterator();

            while (shield_it.next()) |entry| {
                if (entry.shield.n_charges > 0) {
                    entry.shield.shieldSprite(ctx.game).draw(null, position, 1, 0);
                    return;
                }
            }
        }

        pub fn size(self: Enemy, rotation: f32) Game.Vector {
            return self.sprite.size(rotation);
        }

        pub fn layer(self: Enemy) usize {
            return self.sprite.layer();
        }
    };

    pub const Shard = struct {
        sprite: Sprite,

        pub fn draw(
            self: Shard,
            maybe_ctx: ?Game.EntityContext,
            position: Game.Vector,
            scale: f32,
            rotation: f32,
        ) void {
            const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
            defer zone.end();

            const ctx = maybe_ctx orelse return;

            self.sprite.draw(maybe_ctx, position, scale, rotation);

            const shard = ctx.getConst(Game.C.Shard);

            const t = ctx.game.elapsedTime();
            const time_factor = 6;

            const sweep_ratio = @mod(t * time_factor, 8);
            if (sweep_ratio >= 4) return;

            const p_rel = ctx.game.getRelativePos(position);
            const d = 1 - @abs((sweep_ratio - 2) - p_rel.x + p_rel.y);
            const ratio: f32 = @floatCast(d);
            if (ratio == 0) return;

            var renderable_fade = shard.shimmer_renderable(ctx.game);
            renderable_fade.sprite.tint = .alpha(.white, ratio);
            renderable_fade.draw(null, position, scale, rotation);
        }

        pub fn size(self: Shard, rotation: f32) Game.Vector {
            return self.sprite.size(rotation);
        }

        pub fn layer(self: Shard) usize {
            return self.sprite.layer();
        }
    };
};
