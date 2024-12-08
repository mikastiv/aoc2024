const std = @import("std");

const input = @embedFile("input");
const line_ends = if (std.mem.indexOf(u8, input, "\r\n") != null) "\r\n" else "\n";

const RulesMap = std.AutoHashMap(struct { u32, u32 }, void);
const UpdateList = std.ArrayList(std.ArrayList(u32));

fn lessThan(ctx: *const RulesMap, a: u32, b: u32) bool {
    const pair1 = .{ a, b };
    const pair2 = .{ b, a };

    const entry1 = ctx.get(pair1);
    const entry2 = ctx.get(pair2);

    return entry1 != null and entry2 == null;
}

fn parseRules(alloc: std.mem.Allocator, lines: []const u8) !RulesMap {
    var rules = RulesMap.init(alloc);

    var rule_lines = std.mem.tokenizeSequence(u8, lines, line_ends);
    while (rule_lines.next()) |line| {
        const slice1 = std.mem.sliceTo(line, '|');
        const slice2 = line[slice1.len + 1 ..];

        const page1 = try std.fmt.parseInt(u32, slice1, 10);
        const page2 = try std.fmt.parseInt(u32, slice2, 10);

        try rules.putNoClobber(.{ page1, page2 }, {});
    }

    return rules;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var parts = std.mem.tokenizeSequence(u8, input, line_ends ++ line_ends);
    const rules = try parseRules(alloc, parts.next().?);

    var part1: u32 = 0;
    var part2: u32 = 0;
    var updates = try std.BoundedArray(u32, 32).init(0);
    var update_lines = std.mem.tokenizeSequence(u8, parts.next().?, line_ends);
    while (update_lines.next()) |line| {
        updates.clear();

        var items = std.mem.tokenizeScalar(u8, line, ',');
        while (items.next()) |item| {
            const num = try std.fmt.parseInt(u32, item, 10);
            try updates.append(num);
        }

        const part: *u32 = blk: {
            if (std.sort.isSorted(u32, updates.constSlice(), &rules, lessThan)) {
                break :blk &part1;
            } else {
                std.sort.insertion(u32, updates.slice(), &rules, lessThan);
                break :blk &part2;
            }
        };

        const middle = updates.constSlice().len / 2;
        part.* += updates.constSlice()[middle];
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
