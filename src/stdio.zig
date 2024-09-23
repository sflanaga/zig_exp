const std = @import("std");

var stdOBuf = std.io.bufferedWriter(std.io.getStdOut().writer());
var stdEBuf = std.io.bufferedWriter(std.io.getStdErr().writer());
pub fn flush_std_io() void {
    stdEBuf.flush() catch |err| {
        std.debug.panic("Unable to flush std err io buffer, error: {}\n", .{err});
    };
    stdOBuf.flush() catch |err| {
        std.debug.panic("Unable to flush std out io buffer, error: {}\n", .{err});
    };
}
pub fn print(comptime format: []const u8, args: anytype) void {
    stdOBuf.writer().print(format, args) catch |err| {
        std.debug.panic("Unable to write to standard out, so panic {any}\n", .{err});
    };
}

pub fn printe(comptime format: []const u8, args: anytype) void {
    stdEBuf.writer().print(format, args) catch |err| {
        std.debug.panic("Unable to write to standard out, so panic {any}\n", .{err});
    };
}
