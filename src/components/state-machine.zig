const Game = @import("../game.zig").Game;

pub const StateFunction = *const fn (StateMachineContext) void;
pub const StateFunctionNoPtr = fn (StateMachineContext) void;

pub const StateMachineContext = struct {
    ctx: Game.EntityContext,
    state_machine: *StateMachine,

    pub fn init(ctx: Game.EntityContext, state_machine: *StateMachine) @This() {
        return .{
            .ctx = ctx,
            .state_machine = state_machine,
        };
    }

    pub fn setState(self: @This(), new_state: anytype) void {
        if (@TypeOf(new_state) == StateFunction or @TypeOf(new_state) == StateFunctionNoPtr) {
            self.state_machine.state = new_state;
        } else {
            if (@hasDecl(new_state, "pre")) {
                new_state.pre(self);
            }

            self.state_machine.state = new_state.update;
        }
    }

    pub fn elapsedTime(self: @This()) f64 {
        return self.ctx.game.elapsedTime();
    }

    pub fn deltaTime(self: @This()) f32 {
        return self.ctx.game.deltaTime();
    }

    pub fn chance(self: @This(), probability: f32) bool {
        return self.ctx.game.random().float(f32) <= probability;
    }
};

pub const StateMachine = struct {
    state: StateFunction,

    pub fn init(state: StateFunction) @This() {
        return .{ .state = state };
    }
};
