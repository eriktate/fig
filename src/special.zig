const std = @import("std");

pub const Special = enum {
    l_paren, // (
    r_paren, // )
    l_bracket, // [
    r_bracket, // ]
    l_brace, // {
    r_brace, // }
    comma, // ,
    semicolon, // ;
};

const specials = [_]u8{
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    ',',
    ';',
};

pub const special_table: std.EnumArray(Special, u8) = ret: {
    var table = std.EnumArray(Special, u8).initFill();
    for (specials, 0..) |special, idx| {
        table.set(@enumFromInt(idx), special);
    }

    break :ret table;
};

pub fn getSpecial(ch: u8) ?Special {
    switch (ch) {
        '(' => .l_paren,
        ')' => .r_paren,
        '[' => .l_bracket,
        ']' => .r_bracket,
        '{' => .l_brace,
        '}' => .r_brace,
        ',' => .comma,
        ';' => .semicolon,
    }
}
