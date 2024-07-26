const std = @import("std");
const ArrayList = std.ArrayList;
const t = std.testing;

const Intern = @This();
alloc: std.mem.Allocator,
strings: ArrayList([]u8),

pub fn init(alloc: std.mem.Allocator) !Intern {
    return .{
        .alloc = alloc,
        .strings = try ArrayList([]u8).initCapacity(alloc, 512),
    };
}

pub fn deinit(self: *Intern) void {
    for (self.strings.items) |str| {
        self.alloc.free(str);
    }

    self.strings.deinit();
}

pub fn intern(self: *Intern, string: []const u8) ![]u8 {
    for (self.strings.items) |str| {
        // if the ptrs match, the string is already interned
        if (string.ptr == str.ptr) {
            return str;
        }

        if (std.mem.eql(u8, string, str)) {
            return str;
        }
    }

    const new_str = try self.alloc.alloc(u8, string.len);
    @memcpy(new_str, string);
    try self.strings.append(new_str);

    return new_str;
}

pub fn len(self: Intern) usize {
    return self.strings.items.len;
}

test "intern a string" {
    var int = try Intern.init(t.allocator);
    defer int.deinit();
    var hello_raw = "hello";
    const hello_slice = hello_raw[0..];
    const hello = try int.intern(hello_slice);
    const hello2 = try int.intern(hello_slice);
    const hello3 = try int.intern(hello);

    try t.expectEqual(hello.ptr, hello2.ptr);
    try t.expectEqual(hello.ptr, hello3.ptr);
    try t.expect(hello_slice.ptr != hello.ptr);
    try t.expect(std.mem.eql(u8, hello_slice, hello));
    try t.expectEqual(int.len(), 1);
}

test "intern multiple strings" {
    var int = try Intern.init(t.allocator);
    defer int.deinit();

    const hello = try int.intern("hello");
    const world = try int.intern("world");
    const foo = try int.intern("foo");
    const bar = try int.intern("bar");

    try t.expectEqual(hello, try int.intern("hello"));
    try t.expectEqual(world, try int.intern("world"));
    try t.expectEqual(foo, try int.intern("foo"));
    try t.expectEqual(bar, try int.intern("bar"));
}
