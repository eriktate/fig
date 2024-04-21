const std = @import("std");
const ArrayList = std.ArrayList;
const ArenaAllocator = std.heap.ArenaAllocator;

const INTERN_SIZE = 1024 * 1024 * 512; // 512MB

pub const Intern = @This();
arena: ArenaAllocator,
table: ArrayList([]u8),

pub fn init(alloc: std.mem.Allocator) !Intern {
    var arena = ArenaAllocator.init(alloc);

    return .{
        .arena = arena,
        .table = try ArrayList([]u8).initCapacity(arena.allocator(), INTERN_SIZE),
    };
}

pub fn intern(self: *Intern, item: []u8) ![]u8 {
    for (self.table.items) |it| {
        if (std.mem.eql(u8, item, it)) {
            return it;
        }
    }

    const copy = try self.arena.allocator().alloc(u8, item.len);
    @memcpy(copy, item);
    try self.table.append(copy);
    return self.table.items[self.table.items.len - 1];
}
