const std = @import("std");

// order between Symbol and symbols _must_ match
const symbols = [@intFromEnum(Symbol.end_comment) + 1][]const u8{
    "+", // simple ops
    "-",
    "*",
    "/",
    "%",
    "&",
    "|",
    "^",
    "!",
    "?",
    ".",
    ",",
    ":",
    "$",
    ";",
    "=", // assignments
    ":=",
    "::",
    "+=",
    "-=",
    "*=",
    "/=",
    "%=",
    "&=",
    "|=",
    "^=",
    "==", // comparisons
    "&&",
    "||",
    "!=",
    "(", // containers
    ")",
    "[",
    "]",
    "{",
    "}",
    "->", // other
    "..",
    "..=",
    "..<",
    "//",
    "/*",
    "*/",
};

pub const Symbol = enum {
    plus,
    minus,
    star,
    slash,
    mod,
    unary_and,
    unary_or,
    xor,
    bang,
    question,
    dot,
    comma,
    colon,
    dollar,
    semicolon,

    assign,
    infer_bind,
    infer_const,
    plus_assign,
    minus_assign,
    star_assign,
    slash_assign,
    mod_assign,
    and_assign,
    or_assign,
    xor_assign,

    eq,
    log_and,
    log_or,
    band_eq,

    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    l_brace,
    r_brace,

    arrow,
    range,
    range_incl,
    range_excl,
    comment,
    start_comment,
    end_comment,

    pub fn toString(self: Symbol) []const u8 {
        return symbols[@intFromEnum(self)];
    }
};

pub fn getSymbol(input: []const u8) ?Symbol {
    for (symbols, 0..) |symbol, idx| {
        if (std.mem.eql(u8, symbol, input)) {
            return @enumFromInt(idx);
        }
    }

    return null;
}

pub fn isSymbolPrefix(input: []const u8) bool {
    for (symbols) |sym| {
        if (std.mem.startsWith(u8, sym, input)) {
            return true;
        }
    }

    return false;
}
