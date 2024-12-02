const std = @import("std");
const profile = @import("profile.zig");

const input = @embedFile("input");

fn unsafeLevels(dir: i32, diff: i32) bool {
    return std.math.sign(diff) != dir or @abs(diff) < 1 or @abs(diff) > 3;
}

fn unsafeReport(levels: []const i32) bool {
    var dir: i32 = 0;

    var window = std.mem.window(i32, levels, 2, 1);
    while (window.next()) |pair| {
        const diff = pair[0] - pair[1];
        if (dir == 0) dir = std.math.sign(diff);

        if (unsafeLevels(dir, diff)) {
            return true;
        }
    }

    return false;
}

fn removeElement(items: []i32, index: usize) []i32 {
    var read_index: usize = 0;
    var write_index: usize = 0;
    while (read_index < items.len) : (read_index += 1) {
        if (index != read_index) {
            items[write_index] = items[read_index];
            write_index += 1;
        }
    }

    return items[0 .. items.len - 1];
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var reports = std.ArrayList(std.ArrayList(i32)).init(alloc);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var items = std.mem.tokenizeAny(u8, line, &std.ascii.whitespace);

        var report = std.ArrayList(i32).init(alloc);
        while (items.next()) |item| {
            const num = try std.fmt.parseInt(i32, item, 10);
            try report.append(num);
        }

        try reports.append(report);
    }

    var part1: u32 = 0;
    var part2: u32 = 0;
    for (reports.items) |report| {
        if (!unsafeReport(report.items)) {
            part1 += 1;
            continue;
        }

        for (report.items, 0..) |_, index| {
            var buffer: [8]i32 = undefined;
            const items = buffer[0..report.items.len];
            @memcpy(items, report.items);

            const slice = removeElement(items, index);

            if (!unsafeReport(slice)) {
                part2 += 1;
                break;
            }
        }
    }

    part2 += part1;

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
