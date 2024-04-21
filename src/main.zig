const std = @import("std");
const lex = @import("./lex.zig");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("./example.fig", .{});
    var buf: [1024 * 1024]u8 = undefined;
    const file_len = try file.readAll(&buf);

    const res = try lex.lex(std.heap.page_allocator, buf[0..file_len]);
    for (res.tokens) |tok| {
        std.log.info("{any} {d}:{d}-{d} {any}", .{ tok.kind, tok.line, tok.start_col, tok.end_col });
    }
}
