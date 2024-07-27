const std = @import("std");
const lex = @import("lex.zig");
const Intern = @import("intern.zig");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("test.fig", .{});
    defer file.close();

    var src: [1024 * 1024 * 5]u8 = undefined;
    const file_len = try file.readAll(&src);

    const allocator = std.heap.page_allocator;
    var strings = try Intern.init(allocator);
    var lexer = try lex.Lexer.init(allocator, &strings);
    var res = try lexer.lex(src[0..file_len]);
    defer res.deinit();

    for (res.tokens) |token| {
        token.print();
    }
}
