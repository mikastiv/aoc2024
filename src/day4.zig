const std = @import("std");

const input = @embedFile("input");

fn down(grid: []const []const u8, x: usize, y: usize, comptime word: []const u8) bool {
    inline for (word, 0..) |char, i| {
        if (y + i >= grid.len) return false;
        if (grid[y + i][x] != char) return false;
    }

    return true;
}

fn diagRight(grid: []const []const u8, x: usize, y: usize, comptime word: []const u8) bool {
    inline for (word, 0..) |char, i| {
        if (y + i >= grid.len) return false;
        if (x + i >= grid[0].len) return false;
        if (grid[y + i][x + i] != char) return false;
    }

    return true;
}

fn diagLeft(grid: []const []const u8, x: usize, y: usize, comptime word: []const u8) bool {
    inline for (word, 0..) |char, i| {
        if (y + i >= grid.len) return false;
        if (i > x) return false;
        if (grid[y + i][x - i] != char) return false;
    }

    return true;
}

pub fn main() !void {
    const row_count = std.mem.count(u8, input, "\n");

    var grid = try std.heap.page_allocator.alloc([]const u8, row_count);

    var lines = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
    var index: usize = 0;
    while (lines.next()) |line| : (index += 1) {
        grid[index] = line;
    }

    var part1: usize = 0;
    var part2: usize = 0;
    for (grid, 0..) |line, y| {
        part1 += std.mem.count(u8, line, "XMAS");
        part1 += std.mem.count(u8, line, "SAMX");

        for (line, 0..) |_, x| {
            if (down(grid, x, y, "XMAS")) part1 += 1;
            if (down(grid, x, y, "SAMX")) part1 += 1;
            if (diagRight(grid, x, y, "XMAS")) part1 += 1;
            if (diagRight(grid, x, y, "SAMX")) part1 += 1;
            if (diagLeft(grid, x, y, "XMAS")) part1 += 1;
            if (diagLeft(grid, x, y, "SAMX")) part1 += 1;

            if (x + 2 < line.len) {
                const first_cross = diagRight(grid, x, y, "MAS") or diagRight(grid, x, y, "SAM");
                const second_cross = diagLeft(grid, x + 2, y, "MAS") or diagLeft(grid, x + 2, y, "SAM");
                if (first_cross and second_cross) {
                    part2 += 1;
                }
            }
        }
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
