const std = @import("std");
const myio = @import("src/stdio.zig");

const print = myio.print;
const printe = myio.printe;
const flush_std_io = myio.flush_std_io;

// var totalSize = std.atomic.Value(u64).init(0);
var totalSize: u64 = 0;
var maxFileSize: u64 = 0;

const rootFilters = [_][]const u8{ "/proc", "/dev", "/sys" };

pub fn startsWithAny(s: []const u8, prefixes_list: []const []const u8) bool {
    // Loop through the list of prefixes
    for (prefixes_list) |prefix| {
        if (std.mem.startsWith(u8, s, prefix)) {
            return true;
        }
    }
    return false;
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

    // print("Total size: {d}\n", .{totalSize.load(.seq_cst)});
    print("Total size: {}\n", .{std.fmt.fmtIntSizeBin(totalSize)});
    return;
}

pub fn recursePath(fullPathDir: []u8, depth: i32) !void {
    if (startsWithAny(fullPathDir, &rootFilters)) {
        return;
    }

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
        switch (entry.kind) {
            .file => {
                if (statFile(absPath)) |stat| {
                    totalSize += stat.size;
                    if (stat.size > maxFileSize) {
                        maxFileSize = stat.size;
                        printe("newmax: {s} at {d}\n", .{ absPath, maxFileSize });
                    }
                } else |err| {
                    printe("error: cannot stat file: {s}, err: {}\n", .{ absPath, err });
                }
            },
            else => {},
        }
        if (entry.kind == std.fs.Dir.Entry.Kind.directory) {
            try recursePath(absPath, depth + 1);
        }
    }
    return;
}
pub const StatFileError = std.fs.File.OpenError || std.fs.Dir.StatError;

pub fn statFile(path: []u8) !std.fs.File.Stat {
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        printe("error: statFile on {s} with error: {}\n", .{ path, err });
        return err;
    };
    defer file.close();
    const stat = try file.stat();
    return stat;
}
