const std = @import("std");

const input = @embedFile("input");

fn equationPossible(result: u64, values: []const u64, comptime use_concat: bool) bool {
    if (values.len == 1)
        return result == values[0];

    const last = values[values.len - 1];
    const next_values = values[0 .. values.len - 1];

    if (result > last and equationPossible(result - last, next_values, use_concat))
        return true;

    if (result % last == 0 and equationPossible(result / last, next_values, use_concat))
        return true;

    if (use_concat) {
        var buf_a: [32]u8 = undefined;
        var buf_b: [32]u8 = undefined;
        const slice_a = std.fmt.bufPrintIntToSlice(&buf_a, result, 10, .lower, .{});
        const slice_b = std.fmt.bufPrintIntToSlice(&buf_b, last, 10, .lower, .{});
        if (slice_a.len > slice_b.len and std.mem.endsWith(u8, slice_a, slice_b)) {
            const new_result = std.fmt.parseInt(u64, slice_a[0 .. slice_a.len - slice_b.len], 10) catch unreachable;
            if (equationPossible(new_result, next_values, use_concat))
                return true;
        }
    }

    return false;
}

pub fn main() !void {
    var part1: u64 = 0;
    var part2: u64 = 0;
    var values = try std.BoundedArray(u64, 32).init(0);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        values.clear();

        const result_slice = std.mem.sliceTo(line, ':');
        const result = try std.fmt.parseInt(u64, result_slice, 10);

        var it = std.mem.tokenizeAny(u8, line[result_slice.len + 1 ..], &std.ascii.whitespace);
        while (it.next()) |item| {
            const num = try std.fmt.parseInt(u64, item, 10);
            try values.append(num);
        }

        if (equationPossible(result, values.constSlice(), false)) part1 += result;
        if (equationPossible(result, values.constSlice(), true)) part2 += result;
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
