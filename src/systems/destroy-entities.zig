const std = @import("std");
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
            updateDrawLists(game, entity);
            freeStuff(game, entity);
            game.reg.destroy(entity);
        }

        self.n_entities_to_destroy = 0;
    }

    fn updateDrawLists(game: *Game, entity: ecs.Entity) void {
        const ctx = Game.EntityContext.init(game, entity);
        const renderable = ctx.tryGet(Game.C.Renderable) orelse return;
        const list = &game.draw_layer_lists[renderable.layer()];
        const i = for (list.items, 0..) |item, i| {
            if (ctx.equals(.init(game, item))) break i;
        } else return;
        _ = game.draw_layer_lists[renderable.layer()].orderedRemove(i);
    }

    fn freeStuff(game: *Game, entity: ecs.Entity) void {
        const ctx = Game.EntityContext.init(game, entity);
        if (ctx.tryGet(Game.C.Enemy)) |enemy| {
            enemy.deinit(game.allocator);
        }
        if (ctx.tryGet(Game.C.Player)) |player| {
            player.deinit(game.allocator);
        }
        if (ctx.tryGet(Game.C.PlayerProjectile)) |player_projectile| {
            player_projectile.deinit(game.allocator);
        }
    }

    pub fn destroy(self: *DestroyEntities, entity: ecs.Entity) void {
        self.entities_to_destroy[self.n_entities_to_destroy] = entity;
        self.n_entities_to_destroy += 1;
    }
};
