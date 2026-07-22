const Game = @import("../game.zig").Game;

pub const StateMachine = struct {
    enabled: bool = true,

    pub fn init() @This() {
        return .{};
    }

    pub fn update(_: *StateMachine, game: *Game) void {
        const zone = Game.tracyZoneN(@src(), @typeName(@This()) ++ "." ++ @src().fn_name);
        defer zone.end();

        var it = game.entityIterator(.{Game.C.StateMachine}, .{});

        while (it.next()) |ctx| {
            const state_machine = ctx.get(Game.C.StateMachine);
            state_machine.state(.init(ctx, state_machine));
        }
    }
};
