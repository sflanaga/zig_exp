const std = @import("std");
const expect = std.testing.expect;
const tick = @import("./tick.zig");

pub fn spin(stat: *tick.Stat, stop: *bool) void {
    while (!stop.*) {
        _ = stat.add(1);
    }
}

test "test ticker" {
    testTicker() catch |err| {
        std.debug.print("error: {}\n", err);
    };
}

pub fn testTicker() !void {
    var statsTicker = tick.Tick.init("this is a test", std.time.ns_per_s * 1);
    const stat = try statsTicker.addStat("thing");
    try statsTicker.start();

    var spinstop = false;
    var spinthread = try std.Thread.spawn(.{}, spin, .{ stat, &spinstop });

    std.time.sleep(std.time.ns_per_s * 3 + std.time.ns_per_ms * 250);

    statsTicker.stop();

    std.time.sleep(std.time.ns_per_s * 3 + std.time.ns_per_ms * 250);

    try statsTicker.start();

    std.time.sleep(std.time.ns_per_s * 3 + std.time.ns_per_ms * 250);

    statsTicker.stop();

    spinstop = true;
    spinthread.join();

    try statsTicker.deinit();
}
