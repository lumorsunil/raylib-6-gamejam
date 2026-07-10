const Game = @import("../game.zig").Game;
const rl = @import("raylib");

pub const Controllable = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *Controllable, game: *Game) void {
        var it = game.entityIterator(.{ Game.C.Controllable, Game.C.Body, Game.C.Renderable }, .{});
        const input = game.input();

        while (it.next()) |ctx| {
            const body = ctx.get(Game.C.Body);
            const controllable = ctx.get(Game.C.Controllable);
            const player = ctx.getConst(Game.C.Player);

            if (player.destroyed_at != null) return;

            body.velocity.x = input.left_x_axis * controllable.speed;
            body.velocity.y = input.left_y_axis * controllable.speed;

            if (input.isDown(.move_right)) {
                body.velocity.x += controllable.speed;
            }
            if (input.isDown(.move_up)) {
                body.velocity.y -= controllable.speed;
            }
            if (input.isDown(.move_left)) {
                body.velocity.x -= controllable.speed;
            }
            if (input.isDown(.move_down)) {
                body.velocity.y += controllable.speed;
            }

            if (rl.isWindowFocused()) {
                const mouse_screen = rl.getMousePosition();
                const mouse_world = rl.getScreenToWorld2D(mouse_screen, game.camera().*);

                body.position.x = mouse_world.x;
                body.position.y = mouse_world.y;
            }
        }
    }
};
