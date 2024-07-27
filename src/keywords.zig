const std = @import("std");

const keywords = [@intFromEnum(Keyword.Trait) + 1][]const u8{
    "import",
    "if",
    "for",
    "match",
    "struct",
    "variant",
    "return",
    "inline",
    "u8",
    "u16",
    "u32",
    "u64",
    "u128",
    "i8",
    "i16",
    "i32",
    "i64",
    "i128",
    "f32",
    "f64",
    "bool",
    "byte",
    "rune", // alias for i32 representing a Unicode code point, borrowed from Go
    "type",
    "str",
    "true",
    "false",
    "extern",
    "export",
    "trait",
};

pub const Keyword = enum {
    Import,
    If,
    For,
    Match,
    Struct,
    Variant,
    Return,
    Inline,
    U8,
    U16,
    U32,
    U64,
    U128,
    I8,
    I16,
    I32,
    I64,
    I128,
    F32,
    F64,
    Bool,
    Byte,
    Rune, // alias for i32 representing a UnicodE code point, borrowed from Go
    Type,
    Str,
    True,
    False,
    Extern,
    Export,
    Trait,

    pub fn toString(self: Keyword) []const u8 {
        return keywords[@intFromEnum(self)];
    }
};

pub fn getKeyword(input: []const u8) ?Keyword {
    for (keywords, 0..) |kw, idx| {
        if (std.mem.eql(u8, kw, input)) {
            return @enumFromInt(idx);
        }
    }

    return null;
}

pub fn isKeywordPrefix(input: []const u8) bool {
    for (keywords) |kw| {
        if (std.mem.startsWith(u8, kw, input)) {
            return true;
        }
    }

    return false;
}
