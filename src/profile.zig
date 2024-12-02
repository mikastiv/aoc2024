const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");

const build_options = @import("build_options");

pub fn begin(comptime timer: platform.Timer) void {
    profiler = .{
        .timer_fn = platform.readTimerFn(timer),
        .timer_freq = platform.getTimerFreq(timer),
        .start = platform.readTimer(timer),
    };
}

pub fn endAndPrint() !void {
    profiler.end = profiler.timer_fn.?();

    var buffered_stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = buffered_stdout.writer();

    const total_time = profiler.end - profiler.start;
    const freq_f64: f64 = @floatFromInt(profiler.timer_freq);
    const total_f64: f64 = @floatFromInt(total_time);
    const time_ms = total_f64 / freq_f64;

    try stdout.print("\ntotal time: {d:.4}ms (Timer freq {d})\n", .{ time_ms, profiler.timer_freq });
    for (&profiler.zones) |zone| {
        if (zone.tsc_exclusive > 0) try printTimeElapsed(stdout, zone, total_time);
    }

    try buffered_stdout.flush();
}

fn typeOrVoid(comptime T: type) type {
    return if (build_options.profile) T else void;
}

pub const TimingBlock = struct {
    tsc: typeOrVoid(u64),
    old_tsc_inclusive: typeOrVoid(u64),
    index: typeOrVoid(u32),
    parent_index: typeOrVoid(?u32),

    pub fn begin(comptime label: []const u8) TimingBlock {
        return beginData(label, 0);
    }

    pub fn beginData(comptime label: []const u8, byte_count: u64) TimingBlock {
        if (build_options.profile) {
            const index = profiler.getIndex(label);

            const parent_index = if (profiler.active_zone_index) |active| active else null;
            profiler.active_zone_index = index;

            const zone = &profiler.zones[index];
            if (zone.label == null) zone.label = label;
            zone.processed_byte_count += byte_count;

            return .{
                .index = index,
                .old_tsc_inclusive = zone.tsc_inclusive,
                .parent_index = parent_index,
                .tsc = profiler.timer_fn.?(),
            };
        } else {
            return std.mem.zeroes(TimingBlock);
        }
    }

    pub fn end(self: TimingBlock) void {
        if (build_options.profile) {
            const elapsed = profiler.timer_fn.?() - self.tsc;
            profiler.active_zone_index = self.parent_index;

            const zone = &profiler.zones[self.index];

            zone.tsc_exclusive +%= elapsed;
            zone.tsc_inclusive = self.old_tsc_inclusive + elapsed;
            zone.hit_count += 1;

            if (self.parent_index) |parent_index| {
                profiler.zones[parent_index].tsc_exclusive -%= elapsed;
            }
        }
    }
};

pub const RepetitionTester = struct {
    pub const Value = struct {
        total: u64 = 0,
        min: u64 = std.math.maxInt(u64),
        max: u64 = 0,
    };

    pub const Results = struct {
        tsc: Value = .{},
        page_faults: Value = .{},
        test_count: u32 = 0,
    };

    timer_fn: *const fn () u64,
    timer_freq: u64,

    target_bytes_to_process: u64,
    try_for_tsc: u64,
    start_tsc: u64,
    accumulated_tsc: u64 = 0,
    accumulated_page_faults: u64 = 0,
    accumulated_bytes: u64 = 0,
    begin_block_count: u64 = 0,
    end_block_count: u64 = 0,

    results: Results = .{},

    pub fn init(
        comptime timer: platform.Timer,
        bytes_to_process: u64,
        seconds_to_try: u32,
    ) !RepetitionTester {
        try platform.intitializeOsPlatform();
        const freq = platform.getTimerFreq(timer);
        const timer_fn = platform.readTimerFn(timer);
        return .{
            .timer_fn = timer_fn,
            .timer_freq = freq,
            .target_bytes_to_process = bytes_to_process,
            .try_for_tsc = seconds_to_try * freq,
            .start_tsc = timer_fn(),
        };
    }

    pub fn beginTime(self: *RepetitionTester) !void {
        self.begin_block_count += 1;
        self.accumulated_tsc -%= self.timer_fn();
        self.accumulated_page_faults -%= try platform.readPageFaultCount();
    }

    pub fn endTime(self: *RepetitionTester) !void {
        self.end_block_count += 1;
        self.accumulated_tsc +%= self.timer_fn();
        self.accumulated_page_faults +%= try platform.readPageFaultCount();
    }

    pub fn update(self: *RepetitionTester) !void {
        const current_tsc = self.timer_fn();

        if (self.begin_block_count > 0) {
            if (self.begin_block_count != self.end_block_count) {
                return error.BeginEndMismatch;
            }

            if (self.accumulated_bytes != self.target_bytes_to_process) {
                return error.ProcessedBytesMismatch;
            }

            const elapsed_tsc = self.accumulated_tsc;
            const page_faults = self.accumulated_page_faults;
            self.results.test_count += 1;
            self.results.tsc.total += elapsed_tsc;
            self.results.page_faults.total += page_faults;

            if (elapsed_tsc > self.results.tsc.max) {
                self.results.tsc.max = elapsed_tsc;
            }

            if (page_faults > self.results.page_faults.max) {
                self.results.page_faults.max = page_faults;
            }

            if (page_faults < self.results.page_faults.min) {
                self.results.page_faults.min = page_faults;
            }

            if (elapsed_tsc < self.results.tsc.min) {
                self.results.tsc.min = elapsed_tsc;
                self.start_tsc = current_tsc;

                const stdout = std.io.getStdOut().writer();
                try printTime(
                    stdout,
                    "min",
                    self.accumulated_tsc,
                    self.timer_freq,
                    self.target_bytes_to_process,
                    self.results.page_faults.min,
                    false,
                );
                _ = try stdout.writeAll("                                               \r");
            }
        }

        self.accumulated_tsc = 0;
        self.accumulated_bytes = 0;
        self.begin_block_count = 0;
        self.end_block_count = 0;
        self.accumulated_page_faults = 0;
    }

    pub fn isComplete(self: *const RepetitionTester) bool {
        return (self.timer_fn() - self.start_tsc) > self.try_for_tsc;
    }

    pub fn restart(self: *RepetitionTester) void {
        self.accumulated_bytes = 0;
        self.accumulated_tsc = 0;
        self.accumulated_page_faults = 0;
        self.begin_block_count = 0;
        self.end_block_count = 0;
        self.results = .{};
        self.start_tsc = self.timer_fn();
    }

    pub fn printResults(self: *const RepetitionTester) !void {
        const stdout = std.io.getStdOut().writer();

        try printTime(
            stdout,
            "min",
            self.results.tsc.min,
            self.timer_freq,
            self.target_bytes_to_process,
            self.results.page_faults.min,
            true,
        );
        try printTime(
            stdout,
            "max",
            self.results.tsc.max,
            self.timer_freq,
            self.target_bytes_to_process,
            self.results.page_faults.max,
            true,
        );

        if (self.results.test_count == 0) @panic("nothing was tested");
        const avg_tsc = self.results.tsc.total / self.results.test_count;
        const avg_page_faults = self.results.page_faults.total / self.results.test_count;
        try printTime(
            stdout,
            "avg",
            avg_tsc,
            self.timer_freq,
            self.target_bytes_to_process,
            avg_page_faults,
            true,
        );
    }

    fn printTime(
        writer: anytype,
        comptime label: []const u8,
        time_tsc: u64,
        timer_freq: u64,
        byte_count: u64,
        page_faults: u64,
        comptime newline: bool,
    ) !void {
        if (timer_freq == 0) @panic("timer freq == 0");

        const seconds = ratio(time_tsc, timer_freq);
        try writer.print("{s}: {d} ({d:.6}ms)", .{ label, time_tsc, seconds * 1000.0 });

        const byte_count_f64: f64 = @floatFromInt(byte_count);
        if (byte_count > 0) {
            const gb = 1024.0 * 1024.0 * 1024.0;
            const bandwidth = byte_count_f64 / (seconds * gb);
            try writer.print(" {d:.2}GiB/s", .{bandwidth});
        }

        if (page_faults > 0) {
            const page_faults_f64: f64 = @floatFromInt(page_faults);
            const kb = 1024.0;
            const bytes_per_fault = byte_count_f64 / kb / page_faults_f64;
            try writer.print(" PF: {d} ({d:.3}k/fault)", .{ page_faults, bytes_per_fault });
        }

        if (newline) try writer.writeByte('\n');
    }
};

const Zone = struct {
    label: ?[]const u8,
    tsc_inclusive: u64,
    tsc_exclusive: u64,
    hit_count: u64,
    processed_byte_count: u64,
};

const Profiler = struct {
    const max_zone_count = 1024;

    hashes: [max_zone_count]u32 = std.mem.zeroes([max_zone_count]u32),
    zones: [max_zone_count]Zone = std.mem.zeroes([max_zone_count]Zone),
    count: u32 = 0,
    active_zone_index: ?u32 = null,

    timer_fn: ?*const fn () u64,
    timer_freq: u64,
    start: u64,
    end: u64 = 0,

    fn getIndex(self: *Profiler, comptime label: []const u8) u32 {
        const hash = comptime std.hash.Murmur3_32.hash(label);

        for (0..self.count) |index| {
            if (self.hashes[index] == hash) return @intCast(index);
        }

        self.hashes[self.count] = hash;

        defer self.count += 1;
        return self.count;
    }
};

var profiler = std.mem.zeroes(Profiler);

fn printTimeElapsed(writer: anytype, zone: Zone, total: u64) !void {
    const perc_exclusive = percent(zone.tsc_exclusive, total);

    try writer.print("  {?s}[{d}]: {d} ({d:.2}%", .{
        zone.label,
        zone.hit_count,
        zone.tsc_exclusive,
        perc_exclusive,
    });

    if (zone.tsc_inclusive != zone.tsc_exclusive) {
        const perc_inclusive = percent(zone.tsc_inclusive, total);
        try writer.print(", {d:.2}% with children", .{perc_inclusive});
    }
    try writer.print(")", .{});

    if (zone.processed_byte_count > 0) {
        const bytes: f64 = @floatFromInt(zone.processed_byte_count);
        const seconds = ratio(zone.tsc_inclusive, profiler.timer_freq);
        const bytes_per_second = bytes / seconds;
        const gigabytes_per_second = bytes_per_second / (1024 * 1024 * 1024);
        const megabytes = bytes / (1024 * 1024);

        try writer.print(" {d:.3}MiB at {d:.2}GiB/s", .{ megabytes, gigabytes_per_second });
    }
    try writer.print("\n", .{});
}

fn percent(x: u64, total: u64) f64 {
    return ratio(x, total) * 100.0;
}

fn ratio(a: u64, b: u64) f64 {
    const a_f64: f64 = @floatFromInt(a);
    const b_f64: f64 = @floatFromInt(b);
    return a_f64 / b_f64;
}
