const std = @import("std");
const Lexer = @import("lex.zig");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("test.fig", .{});
    defer file.close();

    var src: [1024 * 1024 * 5]u8 = undefined;
    const file_len = try file.readAll(&src);

    const allocator = std.heap.page_allocator;
    var res = try Lexer.lex(allocator, src[0..file_len]);
    defer res.deinit();
    for (res.tokens) |token| {
        token.print();
    }
}
