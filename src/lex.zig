const std = @import("std");
const ArrayList = std.ArrayList;
const Intern = @import("intern.zig");
const keywords = @import("keywords.zig");
const symbols = @import("symbols.zig");

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
    int_lit, // binary, octal, hex?
    float_lit,
    none,
};

pub const TokenValue = union(Kind) {
    ident: []u8,
    keyword: keywords.Keyword,
    symbol: symbols.Symbol,
    string_lit: []u8,
    int_lit: []u8,
    float_lit: []u8,
    none: void,
};

pub const Token = struct {
    kind: Kind, // duplicative of discriminated value?
    start_line: usize,
    end_line: usize, // typically the same as start_line
    start_col: usize,
    end_col: usize,
    value: TokenValue,

    pub fn init(line: usize, col: usize) Token {
        return .{ .kind = .none, .line = line, .start_col = col, .end_col = col, .value = .{ .none = undefined } };
    }

    pub fn print(self: Token) void {
        std.debug.print("{any} {d}:{d}-{d} ", .{ self.kind, self.start_line, self.start_col, self.end_col });
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

const Mode = enum {
    ident,
    keyword,
    symbol,
    string_lit,
    int_lit,
    float_lit,
    comment,
    finished,
    none,
};

const Window = struct {
    start_idx: usize,
    start_line: usize,
    start_col: usize,
};

const Stream = struct {
    src: []const u8,
    idx: usize,
    line: usize,
    col: usize,
    prev_col: usize, // this is only used for an edge case where Stream.prev() goes back a line (e.g. with trailing commas)
    win: Window,

    fn init(src: []const u8) Stream {
        return Stream{
            .src = src,
            .idx = 0,
            .line = 1,
            .col = 1,
            .prev_col = 1,
            .win = Window{
                .start_idx = 0,
                .start_line = 1,
                .start_col = 1,
            },
        };
    }

    fn startWindow(self: *Stream) void {
        self.win = Window{
            .start_line = self.line,
            .start_col = self.col,
            .start_idx = self.idx,
        };
    }

    fn sliceWindowSubIdx(self: Stream, sub_idx: usize) []const u8 {
        return self.src[self.win.start_idx .. self.idx - sub_idx];
    }

    fn sliceWindow(self: Stream) []const u8 {
        return self.sliceWindowSubIdx(0);
    }

    fn next(self: *Stream) ?u8 {
        const ch = self.peek();
        if (ch == null) {
            return null;
        }

        self.prev_col = self.col;
        self.col += 1;
        if (ch == '\n') {
            self.line += 1;
            self.col = 1;
        }

        self.idx += 1;
        return ch;
    }

    fn peek(self: Stream) ?u8 {
        if (self.idx < self.src.len) {
            return self.src[self.idx];
        }

        return null;
    }

    fn skip(self: *Stream) void {
        _ = self.next();
    }

    // NOTE (etate): this will cause problems with col/line counting if going back more than one character, it's meant to support one specific edge case with lexing symbols
    fn prev(self: *Stream) void {
        if (self.idx == 0) {
            return;
        }

        self.idx -= 1;
        self.col = self.prev_col;
        const ch = self.src[self.idx];
        if (ch == '\n') {
            self.line -= 1;
        }
    }

    fn peekPrev(self: Stream) ?u8 {
        if (self.idx == 0) {
            return null;
        }

        return self.src[self.idx - 1];
    }
};

pub const Result = struct {
    tokens: []Token,
    strings: *Intern,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Result) void {
        self.alloc.free(self.tokens);
        self.strings.deinit();
    }
};

pub const Lexer = struct {
    alloc: std.mem.Allocator,
    mode: Mode,
    stream: Stream,
    strings: *Intern,
    tokens: ArrayList(Token),

    pub fn init(alloc: std.mem.Allocator, strings: *Intern) !Lexer {
        return Lexer{
            .alloc = alloc,
            .mode = .none,
            .stream = undefined,
            .strings = strings,
            .tokens = try ArrayList(Token).initCapacity(alloc, 100),
        };
    }

    fn lexIdent(self: *Lexer) !void {
        var stream = &self.stream;

        stream.startWindow();
        while (canStartIdent(stream.peek())) {
            stream.skip();
        }

        var tok = Token{
            .kind = .ident,
            .start_line = stream.win.start_line,
            .end_line = stream.line,
            .start_col = stream.win.start_col,
            .end_col = stream.col,
            .value = undefined,
        };

        const window = stream.sliceWindow();
        const keyword = keywords.getKeyword(window);
        if (keyword) |kw| {
            tok.kind = .keyword;
            tok.value = .{ .keyword = kw };
        } else {
            tok.value = .{ .ident = try self.strings.intern(window) };
        }

        try self.tokens.append(tok);
        self.mode = getMode(stream.peek());
    }

    fn lexComment(self: *Lexer, multiline: bool) !void {
        var stream = &self.stream;
        while (stream.next()) |ch| {
            if (multiline) {
                if (ch == '/' and stream.peekPrev() == '*') {
                    return;
                }
            } else {
                if (ch == '\n') {
                    return;
                }
            }
        }
    }

    fn lexSymbol(self: *Lexer) !void {
        var stream = &self.stream;
        stream.startWindow();

        while (symbols.isSymbolPrefix(stream.sliceWindow())) {
            stream.skip();
        }

        _ = stream.prev();
        const sym = symbols.getSymbol(stream.sliceWindow()) orelse return LexErr.InvalidSymbol;

        if (sym == .comment) {
            return self.lexComment(false);
        }

        try self.tokens.append(Token{
            .kind = .symbol,
            .start_line = stream.win.start_line,
            .end_line = stream.line,
            .start_col = stream.win.start_col,
            .end_col = stream.col,
            .value = .{ .symbol = sym },
        });

        self.mode = getMode(stream.peek());
    }

    fn lexStringLit(self: *Lexer) !void {
        var stream = &self.stream;

        stream.startWindow();
        var escaped = false;

        stream.skip(); // first character will be a quote
        while (stream.peek()) |ch| {
            defer stream.skip();

            if (ch == '\\' and !escaped) {
                escaped = true;
                continue;
            }

            if (ch == '"' and !escaped) {
                break;
            }

            escaped = false;
        }

        const window = stream.sliceWindow();
        try self.tokens.append(Token{
            .kind = .string_lit,
            .start_line = stream.win.start_line,
            .end_line = stream.line,
            .start_col = stream.win.start_col,
            .end_col = stream.col,
            .value = .{ .string_lit = try self.strings.intern(window) },
        });
        self.tokens.items[self.tokens.items.len - 1].print();
    }

    fn lexNumLit(self: *Lexer, initial_kind: Kind) !void {
        var stream = &self.stream;

        stream.startWindow();
        var kind = initial_kind;
        while (stream.peek()) |ch| {
            if (isNumeric(ch) or ch == '_') {
                stream.skip();
                continue;
            }

            if (ch == '.' and kind != .float_lit) {
                kind = .float_lit;
                stream.skip();
                continue;
            }

            if (ch == '.') {
                return LexErr.InvalidFloatLit;
            }

            break;
        }

        try self.tokens.append(Token{
            .kind = kind,
            .start_line = stream.win.start_line,
            .end_line = stream.line,
            .start_col = stream.win.start_col,
            .end_col = stream.col,
            .value = switch (kind) {
                .int_lit => .{ .int_lit = try self.strings.intern(stream.sliceWindow()) },
                .float_lit => .{ .float_lit = try self.strings.intern(stream.sliceWindow()) },
                else => return LexErr.LexFailure,
            },
        });

        self.mode = getMode(stream.peek());
    }

    pub fn lex(self: *Lexer, src: []const u8) !Result {
        self.stream = Stream.init(src);
        self.tokens.items.len = 0;

        while (self.stream.peek()) |ch| {
            self.mode = getMode(ch);

            switch (self.mode) {
                .ident => try self.lexIdent(),
                .keyword => try self.lexIdent(),
                .symbol => try self.lexSymbol(),
                .comment => try self.lexComment(false),
                .string_lit => try self.lexStringLit(),
                .int_lit => try self.lexNumLit(.int_lit),
                .float_lit => try self.lexNumLit(.float_lit),
                .none => {
                    self.stream.skip();
                    self.mode = getMode(ch);
                },
                .finished => break,
            }
        }

        return self.makeResult();
    }

    fn makeResult(self: Lexer) !Result {
        return Result{
            .alloc = self.alloc,
            .tokens = (try self.tokens.clone()).items,
            .strings = self.strings,
        };
    }
};

inline fn isAlpha(char: ?u8) bool {
    const ch = char orelse return false;

    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
}

inline fn isNumeric(char: ?u8) bool {
    const ch = char orelse return false;

    return ch >= '0' and ch <= '9';
}

inline fn validIdent(char: ?u8) bool {
    const ch = char orelse return false;

    return isAlpha(ch) or isNumeric(ch) or ch == '_';
}

inline fn canStartIdent(char: ?u8) bool {
    const ch = char orelse return false;

    return isAlpha(ch) or ch == '_';
}

inline fn isWhitespace(char: ?u8) bool {
    const ch = char orelse return false;
    return ch == ' ' or ch == '\t' or ch == '\n';
}

fn getMode(char: ?u8) Mode {
    const ch = char orelse return .finished;

    if (isWhitespace(ch)) {
        return .none;
    }

    if (canStartIdent(ch)) {
        return .ident;
    }

    if (ch == '"') {
        return .string_lit;
    }

    if (isNumeric(ch)) {
        return .int_lit;
    }

    const sym_prefix = [_]u8{ch};
    if (symbols.isSymbolPrefix(sym_prefix[0..])) {
        return .symbol;
    }

    return .none;
}

test "stream" {
    const t = std.testing;
    const input = "hello";

    var stream = Stream.init(input[0..]);
    try t.expectEqual(stream.peek(), 'h');
    try t.expectEqual(stream.next(), 'h');

    try t.expectEqual(stream.peek(), 'e');
    try t.expectEqual(stream.next(), 'e');

    try t.expectEqual(stream.peek(), 'l');
    try t.expectEqual(stream.next(), 'l');

    try t.expectEqual(stream.peek(), 'l');
    try t.expectEqual(stream.next(), 'l');

    try t.expectEqual(stream.peek(), 'o');
    try t.expectEqual(stream.next(), 'o');

    try t.expectEqual(stream.peek(), null);
    try t.expectEqual(stream.next(), null);

    stream.reset();

    try t.expectEqual(stream.peek(), 'h');
    try t.expectEqual(stream.next(), 'h');
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
