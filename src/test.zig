const std = @import("std");
const expect = std.testing.expect;
const tick = @import("./tick.zig");

pub fn testTicker() !void {
    var statsTicker = tick.Tick.init("this is a test", std.time.ns_per_s * 1);
    const stat = try statsTicker.addStat("thing");
    try statsTicker.start();
    // printe("tick: {any}\n", .{tick});
    // tick.start() catch |err| {
    //     printe("error starting tic: {}\n", .{err});
    // };
    for (0..400_000_000) |i| {
        _ = i;
        // stat.add(1);
        _ = stat.add(1);
    }

    std.time.sleep(std.time.ns_per_s * 3);
    try statsTicker.stop();
}
