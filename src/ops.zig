const std = @import("std");

pub const Op = enum {
    eq, // ==
    gt, // >
    lt, // <
    gte, // >=
    lte, // <=
    neq, // !=
    log_and, // &&
    log_or, // ||
    ref, // &
    bin_or, // |
    xor, // ^
    plus, // +
    minus, // -
    deref, // *
    div, // /
    mod, // %
    bind, // :
    assign, // =
    infer_assign, // :=
    const_assign, // ::
    mul_assign, // *=
    div_assign, // /=
    mod_assign, // %=
    plus_assign, // +=
    minus_assign, // -=
    and_assign, // &=
    or_assign, // |=
    xor_assign, // ^=
    arrow, // ->
    range_incl, // ..=
    range_excl, // ..<
    spread, // ...<
    bang, // !
    dot, // .
};

const ops = [_][]const u8{
    "==",
    ">",
    "<",
    ">=",
    "<=",
    "!=",
    "&&",
    "||",
    "&",
    "|",
    "^",
    "+",
    "-",
    "*",
    "/",
    "%",
    ":",
    "=",
    ":=",
    "::",
    "*=",
    "%=",
    "+=",
    "-=",
    "&=",
    "|=",
    "^=",
    "->",
    "..=",
    "..<",
    "...",
    "!",
    ".",
};

pub const op_table: std.EnumArray(Op, []const u8) = ret: {
    var table = std.EnumArray(Op, []const u8).initUndefined();
    for (ops, 0..) |op, idx| {
        table.set(@enumFromInt(idx), op);
    }

    break :ret table;
};

pub fn isOpPrefix(str: []u8) bool {
    var iter = op_table.iterator();
    while (iter.next()) |entry| {
        if (std.mem.eql(u8, str, entry.value[0..str.len])) {
            return entry.key;
        }
    }

    return null;
}

pub fn getOp(str: []u8) ?Op {
    var iter = op_table.iterator();
    while (iter.next()) |entry| {
        if (std.mem.eql(u8, entry.value, str)) {
            return entry.key;
        }
    }

    return null;
}
