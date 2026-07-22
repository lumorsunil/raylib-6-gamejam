const std = @import("std");
const Game = @import("game.zig").Game;

pub fn main(init: std.process.Init) !void {
    const zone = Game.tracyZoneNC(@src(), @src().fn_name, .red);
    defer zone.end();

    var game = try Game.init(init.io, init.gpa);
    defer game.deinit();
    game.setup();
    game.run();
}
