const std = @import("std");
const profile = @import("profile.zig");

const input = @embedFile("input");

const RulesMap = std.AutoHashMap(struct { u32, u32 }, void);

fn lessThan(ctx: *const RulesMap, a: u32, b: u32) bool {
    const pair1 = .{ a, b };
    const pair2 = .{ b, a };

    const entry1 = ctx.get(pair1);
    const entry2 = ctx.get(pair2);

    return entry1 != null and entry2 == null;
}

pub fn main() !void {
    profile.begin(.Rdtsc);

    const line_ends = comptime if (std.mem.indexOf(u8, input, "\r\n") != null) "\r\n" else "\n";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var parts = std.mem.tokenizeSequence(u8, input, line_ends ++ line_ends);
    const rules_input = parts.next().?;
    const updates_input = parts.next().?;

    var rules = RulesMap.init(alloc);

    var rule_lines = std.mem.tokenizeSequence(u8, rules_input, line_ends);
    while (rule_lines.next()) |line| {
        const slice1 = std.mem.sliceTo(line, '|');
        const slice2 = line[slice1.len + 1 ..];

        const page1 = try std.fmt.parseInt(u32, slice1, 10);
        const page2 = try std.fmt.parseInt(u32, slice2, 10);

        try rules.putNoClobber(.{ page1, page2 }, {});
    }

    var updates = std.ArrayList(std.ArrayList(u32)).init(alloc);

    var update_lines = std.mem.tokenizeSequence(u8, updates_input, line_ends);
    while (update_lines.next()) |line| {
        var items = std.mem.tokenizeScalar(u8, line, ',');

        var list = std.ArrayList(u32).init(alloc);
        while (items.next()) |item| {
            const num = try std.fmt.parseInt(u32, item, 10);
            try list.append(num);
        }

        try updates.append(list);
    }

    var part1: u32 = 0;
    var part2: u32 = 0;
    for (updates.items) |update| {
        var ptr: *u32 = undefined;
        if (std.sort.isSorted(u32, update.items, &rules, lessThan)) {
            ptr = &part1;
        } else {
            std.sort.insertion(u32, update.items, &rules, lessThan);
            ptr = &part2;
        }

        const middle = update.items.len / 2;
        ptr.* += update.items[middle];
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});

    try profile.endAndPrint();
}