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
        return if (self.x == 1 or self.x == -1) .{
            .y = self.x,
            .x = 0,
        } else .{
            .x = -self.y,
            .y = 0,
        };
    }
};

fn startPos(grid: []const []const u8) ?Pos {
    for (grid, 0..) |line, y| {
        if (std.mem.indexOfAny(u8, line, "^v<>")) |x| {
            return .{ .x = @intCast(x), .y = @intCast(y) };
        }
    }

    return null;
}

fn startDir(grid: []const []const u8, pos: Pos) Dir {
    return switch (grid[@intCast(pos.y)][@intCast(pos.x)]) {
        '^' => .{ .x = 0, .y = -1 },
        'v' => .{ .x = 0, .y = 1 },
        '<' => .{ .x = -1, .y = 0 },
        '>' => .{ .x = 1, .y = 0 },
        else => unreachable,
    };
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
    const start_dir = startDir(grid, start_pos);

    var visited = std.AutoHashMap(Pos, void).init(alloc);
    {
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
    }

    const part1 = visited.count();

    var turn_history = std.AutoHashMap(Pos, void).init(alloc);

    var part2: usize = 0;
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

                    const entry = try turn_history.getOrPut(pos);
                    if (entry.found_existing and moved) {
                        part2 += 1;
                        break;
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

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
