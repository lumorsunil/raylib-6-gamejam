const ecs = @import("ecs");
const Game = @import("../game.zig").Game;

pub const DestroyEntities = struct {
    entities_to_destroy: [1024]ecs.Entity = undefined,
    n_entities_to_destroy: usize = 0,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(self: *DestroyEntities, game: *Game) void {
        var it = game.entityIterator(.{Game.C.DestroyAt}, .{});

        while (it.next()) |ctx| {
            const destroy_at = ctx.getConst(Game.C.DestroyAt);

            if (destroy_at.destroy_at <= game.elapsedTime()) {
                ctx.destroy();
            }
        }

        for (0..self.n_entities_to_destroy) |i| {
            const entity = self.entities_to_destroy[i];
            if (!game.reg.valid(entity)) continue;
            game.reg.destroy(entity);
        }

        self.n_entities_to_destroy = 0;
    }

    pub fn destroy(self: *DestroyEntities, entity: ecs.Entity) void {
        self.entities_to_destroy[self.n_entities_to_destroy] = entity;
        self.n_entities_to_destroy += 1;
    }
};
