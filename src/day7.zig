const std = @import("std");

const input = @embedFile("input");

const Equation = struct {
    result: u64,
    values: []u64,
};

const Operation = enum {
    add,
    mul,
    concat,

    fn apply(self: Operation, a: u64, b: u64) u64 {
        return switch (self) {
            .add => a + b,
            .mul => a * b,
            .concat => blk: {
                var digits: u64 = 1;
                var copy = b;
                while (copy / 10 > 0) : (digits += 1) {
                    copy /= 10;
                }

                break :blk a * std.math.pow(u64, 10, digits) + b;
            },
        };
    }
};

fn cartesianProduct(
    alloc: std.mem.Allocator,
    comptime array: []const Operation,
    repeat: usize,
) !std.ArrayList([]Operation) {
    const indices = try alloc.alloc(usize, repeat);
    @memset(indices, 0);

    var result = std.ArrayList([]Operation).init(alloc);

    const total = std.math.pow(usize, array.len, repeat);
    for (0..total) |_| {
        var combination = try std.ArrayList(Operation).initCapacity(alloc, repeat);
        for (0..repeat) |i| {
            try combination.append(array[indices[i]]);
        }

        try result.append(combination.items);

        var i: usize = repeat;
        while (i > 0) : (i -= 1) {
            const index = i - 1;

            indices[index] += 1;
            if (indices[index] < array.len)
                break;

            indices[index] = 0;
        }
    }

    return result;
}

fn equationPossible(combinations: []const []const Operation, equation: Equation) bool {
    for (combinations) |combination| {
        var result = equation.values[0];
        for (equation.values[1..], 0..) |value, index| {
            result = combination[index].apply(result, value);
        }

        if (result == equation.result) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    const row_count = std.mem.count(u8, input, "\n");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var equations = try std.ArrayList(Equation).initCapacity(alloc, row_count);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const result = std.mem.sliceTo(line, ':');
        var values = std.ArrayList(u64).init(alloc);
        var it = std.mem.tokenizeAny(u8, line[result.len + 1 ..], &std.ascii.whitespace);
        while (it.next()) |item| {
            const num = try std.fmt.parseInt(u64, item, 10);
            try values.append(num);
        }

        try equations.append(.{
            .result = try std.fmt.parseInt(u64, result, 10),
            .values = values.items,
        });
    }

    var part1: u64 = 0;
    var part2: u64 = 0;
    for (equations.items) |equation| {
        {
            const combinations = try cartesianProduct(alloc, &.{ .add, .mul }, equation.values.len - 1);
            if (equationPossible(combinations.items, equation)) {
                part1 += equation.result;
            }
        }
        {
            const combinations = try cartesianProduct(alloc, &.{ .add, .mul, .concat }, equation.values.len - 1);
            if (equationPossible(combinations.items, equation)) {
                part2 += equation.result;
            }
        }
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
