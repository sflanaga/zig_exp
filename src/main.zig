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

pub const FakedError = error{
    Fake1,
    ExtraArtificial,
    TrustMeImAnError,
};

pub fn main() !void {
    defer flush_std_io();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        printe("Usage: {s} <directory_path>\n", .{args[0]});
        return;
    }

    const dirPath = args[1];
    printe("Args \"{s}\" \n", .{dirPath});

    var outBuf: [4096]u8 = undefined;

    const absPath = try std.fs.cwd().realpath(dirPath, &outBuf);

    recursePath(absPath, 0) catch |err| {
        printe("Top level failure: {any}\n", .{err});
        return;
    };

    return;
}

pub fn recursePath(fullPathDir: []u8, depth: i32) !void {
    var dir = std.fs.openDirAbsolute(fullPathDir, .{ .iterate = true }) catch |err| {
        printe("error: during open dir \"{s}\", err: \"{}\"\n", .{ fullPathDir, err });
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    var pathBuf: [4096]u8 = undefined;
    while (iterator.next() catch |err| {
        printe("error on next directory item under {s}, so giving up on it, error {}\n", .{ fullPathDir, err });
        return;
    }) |entry| {
        const entryType = switch (entry.kind) {
            .file => "F",
            .directory => "D",
            else => continue,
        };
        // const abs_path = try std.fs.realpath(entry.name, &out_buf);
        const absPath = dir.realpath(entry.name, &pathBuf) catch |err| {
            // note this error does happen, and is not strictly necessary - bug?
            // but zig is singular is provided a system call way of simply catting a path - just bizare
            printe("error: create full path error on entry \"{s}\" under dir: \"{s}\" due to error: {}\n", .{ entry.name, fullPathDir, err });
            continue;
        };
        print("{d} {s}: {s}\n", .{ depth, entryType, absPath });
        if (entry.kind == std.fs.Dir.Entry.Kind.directory) {
            try recursePath(absPath, depth + 1);
        }
    }
    return;
}
