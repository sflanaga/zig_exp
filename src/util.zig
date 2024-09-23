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

pub inline fn gf64(comptime T: type, v: T) f64 {
    switch (@typeInfo(T)) {
        .i32 => return @as(f64, @floatFromInt(v)),
        .i64 => return @as(f64, @floatFromInt(v)),
        .u32 => return @as(f64, @floatFromInt(v)),
        .u64 => return @as(f64, @floatFromInt(v)),
        else => @compileError("gf64 cannot convert this type"),
    }
}

pub inline fn cast(v: anytype) f64 {
    const T = @typeInfo(v);
    return gf64(T, v);
}

pub inline fn tof64(v: anytype) f64 {
    return @as(f64, @floatFromInt(v));
}
