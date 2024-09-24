const std = @import("std");
const expect = std.testing.expect;

const printe = @import("./stdio.zig").printe;
const tof64 = @import("./util.zig").tof64;

var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
const allocator = gpa.allocator();
// const allocator = std.testing.allocator;

pub const Stat = struct {
    val: std.atomic.Value(i64),
    lastSample: i64,
    name: []const u8,
    fn init(name: []const u8) Stat {
        return Stat{
            .val = std.atomic.Value(i64).init(0),
            .lastSample = 0,
            .name = name,
        };
    }
    pub fn add(self: *Stat, val: i64) i64 {
        return self.val.fetchAdd(val, .seq_cst);
    }
};

pub const Tick = struct {
    thread: ?std.Thread,
    stopper: std.Thread.ResetEvent,
    intervalNs: u64,
    msg: []const u8,
    stats: std.ArrayList(Stat),
    pub fn init(msg: []const u8, intervalNs: u64) Tick {
        return Tick{
            .thread = null,
            .stopper = std.Thread.ResetEvent{},
            .intervalNs = intervalNs,
            .msg = msg,
            .stats = std.ArrayList(Stat).init(allocator), //.init(std.heap.page_allocator),
        };
    }
    pub fn deinit(self: *Tick) !void {
        if (self.thread) |_| {
            self.stop();
        }
        self.stats.deinit();
    }

    pub fn addStat(self: *Tick, name: []const u8) !*Stat {
        try self.stats.append(Stat.init(name));
        return &self.stats.items[self.stats.items.len - 1];
    }
    pub fn start(self: *Tick) !void {
        self.stopper.reset();
        self.thread = try std.Thread.spawn(.{}, tickerThreadShim, .{self});
        return;
    }
    pub fn stop(self: *Tick) void {
        if (self.thread) |thread| {
            self.stopper.set();
            thread.join();
            self.thread = null;
            self.stopper.reset();
        } // else if thread is not running this who cares, its stopped
    }
    fn testmod(self: *Tick) !void {
        for (self.stats.items, 0..) |v, i| {
            // v.lastSample = 5;
            _ = v;
            self.stats.items[i].lastSample = 8;
        }
        for (self.stats.items, 0..) |v, i| {
            printe("ls: {d}\n", .{v.lastSample});
            _ = i;
        }
    }
};

fn tickerThreadShim(self: *Tick) void {
    // printe("self tick {}\n", .{self});
    tickerThreadFunc(self) catch |err| {
        printe("ticker thread exiting due to error: {}\n", .{err});
    };
    return;
}

fn timeoutOrKeepRunning(self: *Tick) bool { // return FALSE if set here
    if (self.stopper.timedWait(self.intervalNs)) {
        return !self.stopper.isSet();
    } else |_| {
        // error here - no matter the error - stop running in ticker
        return true;
    }
}

fn tickerThreadFunc(self: *Tick) !void {
    const startTime = try std.time.Instant.now();
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var wr = fbs.writer();
    while (timeoutOrKeepRunning(self)) {
        const deltaTime = tof64((try std.time.Instant.now()).since(startTime)) / tof64(std.time.ns_per_s);
        fbs.reset();
        try wr.print("{d:3.3}s|{s}:  ", .{ deltaTime, self.msg });
        for (self.stats.items) |*v| {
            const sample = v.*.val.load(.seq_cst);
            const delta = sample - v.*.lastSample;
            const rate = tof64(delta) * tof64(std.time.ns_per_s) / tof64(self.intervalNs);
            v.*.lastSample = sample;
            try wr.print("[{s}: {d}/s {d}]", .{ v.*.name, rate, sample });
        }
        printe("{s}\n", .{fbs.getWritten()});
    }
    const runtime = (try std.time.Instant.now()).since(startTime);
    fbs.reset();
    const allDeltaTime = tof64((try std.time.Instant.now()).since(startTime)) / tof64(std.time.ns_per_s);

    try wr.print("{d:3.3}s| OVERALL {s}: ", .{ allDeltaTime, self.msg });
    for (self.stats.items) |*v| {
        const sample = v.*.val.load(.seq_cst);
        const delta = sample;
        const rate = tof64(delta) * tof64(std.time.ns_per_s) / tof64(runtime);
        v.*.lastSample = sample;
        try wr.print("[{s}: {d}/s {d}]", .{ v.*.name, rate, sample });
    }
    printe("{s}\n", .{fbs.getWritten()});
    return;
}

fn somethreadfunc() void {
    var x: i32 = 0;
    while (true) {
        x += 1;
        printe("x = {d}\n", .{x});
        std.time.sleep(std.time.ns_per_s * 1);
    }
}
