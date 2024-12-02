const std = @import("std");

const input = @embedFile("input");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var left_list = std.ArrayList(i32).init(alloc);
    var right_list = std.ArrayList(i32).init(alloc);

    var score = std.AutoHashMap(i32, i32).init(alloc);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var items = std.mem.tokenizeAny(u8, line, &std.ascii.whitespace);

        const left = items.next().?;
        const right = items.next().?;

        try left_list.append(try std.fmt.parseInt(i32, left, 10));

        const num = try std.fmt.parseInt(i32, right, 10);
        try right_list.append(num);

        const entry = try score.getOrPut(num);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    std.sort.pdq(i32, left_list.items, {}, std.sort.asc(i32));
    std.sort.pdq(i32, right_list.items, {}, std.sort.asc(i32));

    var distance: i64 = 0;
    var similarity: i64 = 0;
    for (left_list.items, right_list.items) |left, right| {
        distance += @abs(right - left);
        const entry = score.get(left);
        if (entry) |num| {
            similarity += left * num;
        }
    }

    std.debug.print("part1: {d}\n", .{distance});
    std.debug.print("part2: {d}\n", .{similarity});
}
