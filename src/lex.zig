const std = @import("std");
const ArrayList = std.ArrayList;
const Intern = @import("intern.zig");

// order between Symbol and symbols _must_ match
const symbols = [@intFromEnum(Symbol.range_excl) + 1][]const u8{
    "+", //simple ops
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
    "->", // random
    "..",
    "..=",
    "..<",
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

    pub fn toString(self: Symbol) []const u8 {
        return symbols[@intFromEnum(self)];
    }
};

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
    "rune",
    "type",
    "str",
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
    Rune, // alias for i32 representing a Unicode code point, borrowed from Go
    Type,
    Str,
    Trait,

    pub fn toString(self: Keyword) []const u8 {
        return keywords[@intFromEnum(self)];
    }
};

const LexErr = error{
    LexFailure,
    InvalidSymbol,
    NumericIdent,
    InvalidFloatLit,
};

pub const Kind = enum {
    ident,
    keyword,
    symbol,
    string_lit,
    int_lit,
    float_lit,
    none,
};

pub const TokenValue = union(Kind) {
    ident: []u8,
    keyword: Keyword,
    symbol: Symbol,
    string_lit: []u8,
    int_lit: []u8,
    float_lit: []u8,
    none: void,
};

pub const Token = struct {
    kind: Kind,
    line: usize,
    start_col: usize,
    end_col: usize,
    value: TokenValue,

    pub fn init(line: usize, col: usize) Token {
        return .{ .kind = .none, .line = line, .start_col = col, .end_col = col, .value = .{ .none = undefined } };
    }

    pub fn print(self: Token) void {
        std.debug.print("{any} {d}:{d}-{d} ", .{ self.kind, self.line, self.start_col, self.end_col });
        switch (self.value) {
            .ident => |str| std.debug.print("{s}\n", .{str}),
            .symbol => |sym| std.debug.print("{s}\n", .{sym.toString()}),
            .string_lit => |str| std.debug.print("{s}\n", .{str}),
            .int_lit => |int| std.debug.print("{s}\n", .{int}),
            .float_lit => |float| std.debug.print("{s}\n", .{float}),
            .keyword => |kw| std.debug.print("{s}\n", .{kw.toString()}),
            else => undefined,
        }
    }
};

const Reader = struct {
    src: []const u8,
    line: usize,
    col: usize,
    idx: usize,

    fn init(src: []const u8) Reader {
        return .{
            .src = src,
            .idx = 0,
            .col = 1,
            .line = 1,
        };
    }

    fn next(self: *Reader) ?u8 {
        if (peek(self)) |result| {
            if (result == '\n') {
                self.line += 1;
                self.col = 0;
            }

            self.idx += 1;
            self.col += 1;
            return result;
        }

        return null;
    }

    fn peek(self: *Reader) ?u8 {
        if (self.idx < self.src.len) {
            return self.src[self.idx];
        }

        return null;
    }

    fn skip(self: *Reader) void {
        _ = self.next();
    }

    fn reset(self: *Reader) void {
        self.idx = 0;
        self.line = 1;
        self.col = 1;
    }
};

const Mode = enum {
    ident,
    keyword,
    symbol,
    string_lit,
    int_lit,
    float_lit,
    none,
};

const Context = struct {
    mode: Mode,
    line: usize,
    col: usize,
    reader: Reader,
    strings: Intern,
    alloc: std.mem.Allocator,

    tokens: ArrayList(Token),
    token: Token,
    str: ArrayList(u8),

    pub fn init(alloc: std.mem.Allocator) !Context {
        return .{
            .mode = .none,
            .line = 0,
            .col = 0,
            .tokens = try ArrayList(Token).initCapacity(alloc, 512),
            .strings = try Intern.init(alloc),
            .alloc = alloc,
            .reader = undefined,
            .token = Token.init(0, 0),
            .str = try ArrayList(u8).initCapacity(alloc, 512),
        };
    }

    pub fn deinit(self: Context) void {
        self.str.deinit();
    }

    pub fn pushToken(self: *Context) !void {
        if (self.token.kind != .none) {
            try self.tokens.append(self.token);
            // self.token.print();
        }

        self.token = Token.init(self.reader.line, self.reader.col);
    }
};

inline fn isAlpha(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
}

inline fn isNumeric(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

inline fn validIdent(ch: u8) bool {
    return isAlpha(ch) or isNumeric(ch) or ch == '_';
}

inline fn canStartIdent(ch: u8) bool {
    return isAlpha(ch) or ch == '_';
}

inline fn isWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\n';
}

fn canStartSymbol(ch: u8) bool {
    for (symbols) |sym| {
        if (sym[0] == ch) {
            return true;
        }
    }

    return false;
}

fn findFirstSymbol(str: []u8) ?Symbol {
    for (symbols, 0..) |sym, id| {
        if (std.mem.startsWith(u8, sym, str)) {
            return @enumFromInt(id);
        }
    }

    return null;
}

fn getMode(ch: u8) Mode {
    if (canStartIdent(ch)) {
        return .ident;
    }

    if (ch == '"') {
        return .string_lit;
    }

    if (isNumeric(ch)) {
        return .int_lit;
    }

    if (isWhitespace(ch)) {
        return .none;
    }

    if (canStartSymbol(ch)) {
        return .symbol;
    }

    return .none;
}

fn findSymbol(str: []u8) ?Symbol {
    for (symbols, 0..) |sym, id| {
        if (std.mem.eql(u8, sym, str)) {
            return @enumFromInt(id);
        }
    }

    return null;
}

fn findKeyword(str: []u8) ?Keyword {
    for (keywords, 0..) |keyword, id| {
        if (std.mem.eql(u8, keyword, str)) {
            return @enumFromInt(id);
        }
    }

    return null;
}

fn lexIdent(ctx: *Context) !void {
    while (ctx.reader.peek()) |ch| {
        if (validIdent(ch)) {
            try ctx.str.append(ch);
            ctx.reader.skip();
            continue;
        }

        if (findKeyword(ctx.str.items)) |keyword| {
            ctx.token.kind = .keyword;
            ctx.token.value = .{ .keyword = keyword };
        } else {
            ctx.token.kind = .ident;
            ctx.token.value = .{ .ident = try ctx.strings.intern(ctx.str.items) };
        }
        ctx.token.end_col = ctx.reader.col;
        ctx.str.items.len = 0;
        ctx.mode = getMode(ch);
        return;
    }
}

fn lexStringLit(ctx: *Context) !void {
    var escaped = true; // starting with true so that the starting quote doesn't short circuit

    while (ctx.reader.next()) |ch| {
        if (ch == '\\' and !escaped) {
            escaped = true;
            try ctx.str.append(ch);
            continue;
        }

        if (escaped or ch != '"') {
            try ctx.str.append(ch);
            escaped = false;
            continue;
        }

        // ctx.reader.skip();
        try ctx.str.append(ch);
        ctx.token.kind = .string_lit;
        ctx.token.end_col = ctx.reader.col;
        ctx.token.value = .{ .string_lit = try ctx.strings.intern(ctx.str.items) };
        ctx.str.items.len = 0;
        ctx.mode = .none;
        return;
    }
}

fn lexNumLit(ctx: *Context, initial_kind: Kind) !void {
    var kind = initial_kind;

    while (ctx.reader.peek()) |ch| {
        if (isNumeric(ch) or ch == '_') {
            try ctx.str.append(ch);
            ctx.reader.skip();
            continue;
        }

        if (ch == '.' and kind == .int_lit) {
            kind = .float_lit;
            try ctx.str.append(ch);
            ctx.reader.skip();
            continue;
        }

        if (ch == '.' and kind == .float_lit) {
            return LexErr.InvalidFloatLit;
        }

        if (validIdent(ch)) {
            return LexErr.NumericIdent;
        }

        ctx.token.kind = kind;
        ctx.token.end_col = ctx.reader.col;
        var value = try ctx.strings.intern(ctx.str.items);
        ctx.token.value = if (kind == .int_lit) .{ .int_lit = value } else .{ .float_lit = value };
        ctx.str.items.len = 0;
        ctx.mode = getMode(ch);
        return;
    }
}

fn lexSymbol(ctx: *Context) !void {
    var symbol: Symbol = undefined;
    while (ctx.reader.peek()) |ch| {
        try ctx.str.append(ch);
        if (findFirstSymbol(ctx.str.items)) |sym| {
            symbol = sym;
            ctx.reader.skip();
            continue;
        }

        break;
    }

    if (ctx.reader.peek()) |ch| {
        ctx.str.items.len -= 1;

        if (symbol == .dot and isNumeric(ch)) {
            return lexNumLit(ctx, .float_lit);
        }
    }

    if (symbol == undefined or !std.mem.eql(u8, ctx.str.items, symbol.toString())) {
        return LexErr.InvalidSymbol;
    }

    ctx.token.kind = .symbol;
    ctx.token.value = .{ .symbol = symbol };
    ctx.token.end_col = ctx.reader.col;
    ctx.str.items.len = 0;
    ctx.mode = .none;
    return;
}

pub const Result = struct {
    tokens: []Token,
    strings: Intern,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Result) void {
        self.alloc.free(self.tokens);
        self.strings.deinit();
    }
};

pub fn lex(alloc: std.mem.Allocator, input: []const u8) anyerror!Result {
    var ctx = (try Context.init(alloc));
    ctx.reader = Reader.init(input);

    std.debug.print("Starting lex:\n{s}\n", .{input});
    while (ctx.reader.peek()) |ch| {
        try switch (ctx.mode) {
            .none => {
                ctx.mode = getMode(ch);
                if (ctx.mode == .none) {
                    ctx.reader.skip();
                }
            },
            .ident, .keyword => lexIdent(&ctx),
            .string_lit => lexStringLit(&ctx),
            .int_lit => lexNumLit(&ctx, .int_lit),
            .float_lit => lexNumLit(&ctx, .float_lit),
            .symbol => lexSymbol(&ctx),
        };

        // always attempt to push a token if we have one
        try ctx.pushToken();
    }

    std.debug.print("Finished lex\n", .{});
    return .{ .tokens = ctx.tokens.items, .strings = ctx.strings, .alloc = ctx.alloc };
}

test "reader" {
    const t = std.testing;
    const input = "hello";

    var reader = Reader.init(input[0..]);
    try t.expectEqual(reader.peek(), 'h');
    try t.expectEqual(reader.next(), 'h');

    try t.expectEqual(reader.peek(), 'e');
    try t.expectEqual(reader.next(), 'e');

    try t.expectEqual(reader.peek(), 'l');
    try t.expectEqual(reader.next(), 'l');

    try t.expectEqual(reader.peek(), 'l');
    try t.expectEqual(reader.next(), 'l');

    try t.expectEqual(reader.peek(), 'o');
    try t.expectEqual(reader.next(), 'o');

    try t.expectEqual(reader.peek(), null);
    try t.expectEqual(reader.next(), null);

    reader.reset();

    try t.expectEqual(reader.peek(), 'h');
    try t.expectEqual(reader.next(), 'h');
}

// test "lex" {
//     const t = std.testing;

//     const src =
//         \\std :: import("std");
//         \\
//         \\main :: () {
//         \\  std.printf("hello world\n");
//         \\}
//     ;

//     const tokens = try lex(t.allocator, src[0..]);
//     for (tokens) |token| {
//         token.print();
//     }
//     t.allocator.free(tokens);
// }
