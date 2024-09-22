const std = @import("std");
const printe = std.debug.print;
// const print = printe;

var stdbuf = std.io.bufferedWriter(std.io.getStdOut().writer());

// const stdwr = stdbuf.writer();

pub fn flush_std_io() void {
    stdbuf.flush() catch |err| {
        std.debug.panic("Unable to flush std io buffer, error: {}\n", .{err});
    };
}
pub fn print(comptime format: []const u8, args: anytype) void {
    stdbuf.writer().print(format, args) catch |err| {
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

    try recursePath(absPath, 0);

    // recursePath(absPath, 0) catch |err| {
    //     printe("Top level failure: {any}\n", .{err});
    //     return;
    // };

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
    while (try iterator.next()) |entry| {
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
        // switch (entry.kind) {
        //     .directory => try recursePath(abs_path, depth + 1),
        //     else => {},
        // }

        if (entry.kind == std.fs.Dir.Entry.Kind.directory) {
            try recursePath(absPath, depth + 1);
        }
    }
    return;
}
