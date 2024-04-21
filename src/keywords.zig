const std = @import("std");

pub const Keyword = enum {
    _if,
    _for,
    import,
    _switch,
    u8,
    u16,
    u32,
    u64,
    u128,
    i8,
    i16,
    i32,
    i64,
    i128,
    f32,
    f64,
    byte,
    str,
    char,
    _struct,
    _enum,
    _return,
    _defer,
};

const keywords = [_][]const u8{
    "if",
    "for",
    "import",
    "switch",
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
    "byte", // alias for u8
    "str",
    "char",
    "struct",
    "type",
    "return",
    "defer",
};

pub const keyword_table: std.EnumArray(Keyword, []const u8) = ret: {
    var table = std.EnumArray(Keyword, []const u8).initUndefined();
    for (keywords, 0..) |kw, idx| {
        table.set(@enumFromInt(idx), kw);
    }

    break :ret table;
};

pub fn getKeyword(str: []u8) ?Keyword {
    var iter = keyword_table.iterator();
    while (iter.next()) |entry| {
        if (std.mem.eql(u8, entry.value, str)) {
            return entry.key;
        }
    }

    return null;
}
