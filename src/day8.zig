const std = @import("std");

const input = @embedFile("input");

const Pos = @Vector(2, isize);
const AntennasMap = std.AutoHashMap(u8, std.ArrayList(Pos));

fn setAntinode(grid: []const []u8, pos: Pos) bool {
    if (pos[0] >= 0 and pos[0] < grid[0].len and
        pos[1] >= 0 and pos[1] < grid.len)
    {
        grid[@intCast(pos[1])][@intCast(pos[0])] = '#';
        return true;
    }

    return false;
}

fn setAntinodesWithHarmonics(grid: []const []u8, start_pos: Pos, delta: Pos) void {
    var pos = start_pos;
    while (true) : (pos += delta) {
        if (!setAntinode(grid, pos))
            break;
    }
}

fn parseAntennas(alloc: std.mem.Allocator, grid: []const []const u8) !AntennasMap {
    var antennas = std.AutoHashMap(u8, std.ArrayList(Pos)).init(alloc);
    for (grid, 0..) |line, y| {
        for (line, 0..) |char, x| {
            if (std.ascii.isAlphanumeric(char)) {
                const pos: Pos = .{ @intCast(x), @intCast(y) };
                const entry = try antennas.getOrPut(char);
                if (entry.found_existing) {
                    try entry.value_ptr.append(pos);
                } else {
                    entry.value_ptr.* = std.ArrayList(Pos).init(alloc);
                    try entry.value_ptr.append(pos);
                }
            }
        }
    }

    return antennas;
}

pub fn main() !void {
    const row_count = std.mem.count(u8, input, "\n");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var grid = try alloc.alloc([]u8, row_count);

    var lines = std.mem.tokenizeAny(u8, input, &std.ascii.whitespace);
    var index: usize = 0;
    while (lines.next()) |line| : (index += 1) {
        grid[index] = try alloc.dupe(u8, line);
    }

    const antennas = try parseAntennas(alloc, grid);

    {
        var it = antennas.valueIterator();
        while (it.next()) |freq| {
            for (freq.items[0 .. freq.items.len - 1], 0..) |a, y| {
                for (freq.items[y + 1 ..]) |b| {
                    const delta = b - a;
                    _ = setAntinode(grid, a - delta);
                    _ = setAntinode(grid, b + delta);
                }
            }
        }
    }

    var part1: usize = 0;
    for (grid) |line| {
        part1 += std.mem.count(u8, line, "#");
    }

    {
        var it = antennas.valueIterator();
        while (it.next()) |freq| {
            for (freq.items[0 .. freq.items.len - 1], 0..) |a, y| {
                for (freq.items[y + 1 ..]) |b| {
                    const delta = b - a;
                    setAntinodesWithHarmonics(grid, a, -delta);
                    setAntinodesWithHarmonics(grid, b, delta);
                }
            }
        }
    }

    var part2: usize = 0;
    for (grid) |line| {
        part2 += std.mem.count(u8, line, "#");
    }

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
