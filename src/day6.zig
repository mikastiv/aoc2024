const std = @import("std");

const input = @embedFile("input");

const Pos = packed struct {
    x: isize,
    y: isize,
};

const Dir = packed struct {
    x: isize,
    y: isize,

    fn turn(self: Dir) Dir {
        return .{
            .x = -self.y,
            .y = self.x,
        };
    }
};

fn startPos(grid: []const []const u8) ?Pos {
    for (grid, 0..) |line, y| {
        if (std.mem.indexOfScalar(u8, line, '^')) |x| {
            return .{ .x = @intCast(x), .y = @intCast(y) };
        }
    }

    return null;
}

fn countVisited(alloc: std.mem.Allocator, grid: []const []const u8, start_pos: Pos, start_dir: Dir) !usize {
    var visited = std.AutoHashMap(Pos, void).init(alloc);

    var dir = start_dir;
    var pos = start_pos;
    while (true) {
        try visited.put(pos, {});

        const next_pos: Pos = .{
            .x = pos.x + dir.x,
            .y = pos.y + dir.y,
        };

        if (next_pos.x < 0 or next_pos.x >= grid[0].len) break;
        if (next_pos.y < 0 or next_pos.y >= grid.len) break;

        if (grid[@intCast(next_pos.y)][@intCast(next_pos.x)] == '#') {
            dir = dir.turn();
        } else {
            pos = next_pos;
        }
    }

    return visited.count();
}

fn countLoops(alloc: std.mem.Allocator, grid: []const []u8, start_pos: Pos, start_dir: Dir) !usize {
    var turn_history = std.AutoHashMap(Pos, void).init(alloc);

    var loops: usize = 0;
    for (grid) |line| {
        for (line) |*char| {
            if (char.* != '.') continue;

            char.* = '#';

            var pos = start_pos;
            var dir = start_dir;
            var moved = false;
            while (true) {
                const next_pos: Pos = .{
                    .x = pos.x + dir.x,
                    .y = pos.y + dir.y,
                };

                if (next_pos.x < 0 or next_pos.x >= grid[0].len) break;
                if (next_pos.y < 0 or next_pos.y >= grid.len) break;

                if (grid[@intCast(next_pos.y)][@intCast(next_pos.x)] == '#') {
                    dir = dir.turn();

                    if (moved) {
                        const entry = try turn_history.getOrPut(pos);
                        if (entry.found_existing) {
                            loops += 1;
                            break;
                        }
                    }

                    moved = false;
                } else {
                    pos = next_pos;
                    moved = true;
                }
            }

            turn_history.clearRetainingCapacity();
            char.* = '.';
        }
    }

    return loops;
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

    const start_pos = startPos(grid) orelse return error.NoStartingPosition;
    const start_dir: Dir = .{ .x = 0, .y = -1 };

    const part1 = try countVisited(alloc, grid, start_pos, start_dir);
    const part2 = try countLoops(alloc, grid, start_pos, start_dir);

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
