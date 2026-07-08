const Game = @import("../game.zig").Game;

pub const Shard = struct {
    shard_type: Type,
    enable_drag: bool = true,

    pub const Type = enum {
        small,
        medium,
        large,

        pub fn value(self: Type) usize {
            return switch (self) {
                .small => 1,
                .medium => 5,
                .large => 15,
            };
        }

        pub fn renderable(self: Type, game: *Game) Game.C.Renderable {
            return switch (self) {
                .small => {
                    var sprite = game.initSprite(.init(70, 40, 6, 3));
                    sprite.sprite.tint = .green;
                    return sprite;
                },
                .medium => {
                    var sprite = game.initSprite(.init(77, 40, 8, 8));
                    sprite.sprite.tint = .blue;
                    return sprite;
                },
                .large => {
                    var sprite = game.initSprite(.init(87, 40, 10, 9));
                    sprite.sprite.tint = .red;
                    return sprite;
                },
            };
        }

        pub fn shimmer_renderable(self: Type, game: *Game) Game.C.Renderable {
            return switch (self) {
                .small => game.initSprite(.init(70, 30, 6, 3)),
                .medium => game.initSprite(.init(77, 30, 8, 8)),
                .large => game.initSprite(.init(87, 30, 10, 9)),
            };
        }
    };

    pub fn init(shard_type: Type) @This() {
        return .{ .shard_type = shard_type };
    }

    pub fn value(self: Shard) usize {
        return self.shard_type.value();
    }

    pub fn renderable(self: Shard, game: *Game) Game.C.Renderable {
        return self.shard_type.renderable(game);
    }

    pub fn shimmer_renderable(self: Shard, game: *Game) Game.C.Renderable {
        return self.shard_type.shimmer_renderable(game);
    }
};
