const std = @import("std");

const input = @embedFile("input");

const Block = struct {
    id: u32,
    size: u32,
};

const empty = std.math.maxInt(u32);

fn processBlocks(blocks: *std.ArrayList(Block), comptime whole_blocks: bool) !void {
    var index = blocks.items.len - 1;
    var first: usize = 0;
    while (index != 0) : (index -= 1) {
        const file_block = blocks.items[index];
        if (file_block.id == empty) continue;

        const start = if (whole_blocks) 0 else first;
        for (blocks.items[start..], start..) |*block, i| {
            if (i > index) break;

            if (block.id != empty) {
                if (!whole_blocks)
                    first = i;

                continue;
            }

            if (block.size >= file_block.size) {
                blocks.items[index].id = empty;

                if (block.size == file_block.size) {
                    blocks.items[i] = file_block;
                } else {
                    block.size -= file_block.size;
                    try blocks.insert(i, file_block);
                }

                break;
            }
        }
    }
}

fn checksum(blocks: []const Block) usize {
    var sum: u64 = 0;
    var i: u32 = 0;
    for (blocks) |block| {
        if (block.id == empty) {
            i += block.size;
            continue;
        }

        for (0..block.size) |_| {
            sum += block.id * i;
            i += 1;
        }
    }

    return sum;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    const map = std.mem.trim(u8, input, &std.ascii.whitespace);

    var blocks1 = std.ArrayList(Block).init(alloc);
    var blocks2 = std.ArrayList(Block).init(alloc);

    var entries = std.mem.window(u8, map, 2, 2);
    var id: u32 = 0;
    while (entries.next()) |entry| : (id += 1) {
        const file_size = entry[0] - '0';
        for (0..file_size) |_| {
            try blocks1.append(.{ .id = id, .size = 1 });
        }
        try blocks2.append(.{ .id = id, .size = file_size });

        if (entry.len > 1 and entry[1] > 0) {
            const free_size = entry[1] - '0';
            for (0..free_size) |_| {
                try blocks1.append(.{ .id = empty, .size = 1 });
            }
            try blocks2.append(.{ .id = empty, .size = free_size });
        }
    }

    try processBlocks(&blocks1, false);
    try processBlocks(&blocks2, true);

    const part1 = checksum(blocks1.items);
    const part2 = checksum(blocks2.items);

    std.debug.print("part1: {d}\n", .{part1});
    std.debug.print("part2: {d}\n", .{part2});
}
