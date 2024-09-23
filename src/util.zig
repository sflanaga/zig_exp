const std = @import("std");
const printe = @import("./stdio.zig").printe;

pub fn statFile(path: []u8) !std.fs.File.Stat {
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        printe("error: statFile on {s} with error: {}\n", .{ path, err });
        return err;
    };
    defer file.close();
    const stat = try file.stat();
    return stat;
}
