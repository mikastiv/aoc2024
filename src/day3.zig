const std = @import("std");

const input = @embedFile("input");

pub fn main() !void {
    const mul = "mul(";
    const do = "do()";
    const dont = "don't()";

    var part1: i32 = 0;
    var part2: i32 = 0;
    var enable = true;

    for (input, 0..) |_, index| {
        if (std.mem.startsWith(u8, input[index..], do)) {
            enable = true;
            continue;
        }

        if (std.mem.startsWith(u8, input[index..], dont)) {
            enable = false;
            continue;
        }

        if (std.mem.startsWith(u8, input[index..], mul)) {
            const num1_start = index + mul.len;
            const comma = std.mem.indexOfScalarPos(u8, input, num1_start, ',') orelse break;
            const num2_start = comma + 1;
            const paren = std.mem.indexOfScalarPos(u8, input, num2_start, ')') orelse break;

            const num1 = std.fmt.parseInt(i32, input[num1_start..comma], 10) catch continue;
            const num2 = std.fmt.parseInt(i32, input[num2_start..paren], 10) catch continue;

            part1 += num1 * num2;
            if (enable) {
                part2 += num1 * num2;
            }
        }
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
