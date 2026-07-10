const std = @import("std");
const Io = std.Io;
const Game = @import("game.zig").Game;

pub fn main(init: std.process.Init) !void {
    var game = try Game.init(init.io, init.gpa);
    defer game.deinit();
    game.setup();
    game.run();
}
