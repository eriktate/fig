const std = @import("std");
const ArrayList = std.ArrayList;
const Intern = @import("./intern.zig");
const ops = @import("./ops.zig");
const keywords = @import("./keywords.zig");
const special = @import("./special.zig");

const LexError = error{
    EOF,
    InvalidOp,
    UnrecognizedSymbol,
};

const Kind = enum {
    ident,
    keyword,
    string_lit,
    int_lit,
    float_lit,
    op,
    special,
    none,
};

const Value = union(Kind) {
    ident: []u8,
    keyword: keywords.Keyword,
    string_lit: []u8,
    int_lit: usize,
    float_lit: f64,
    op: ops.Op,
    special: special.Special,
    none: void,
};

const Token = struct {
    kind: Kind,
    line: usize,
    start_col: usize,
    end_col: usize,
    val: Value,

    end_line: ?usize, // just for multiline strings

    pub fn default() Token {
        return .{
            .kind = .none,
            .line = 0,
            .start_col = 0,
            .end_col = 0,
            .val = undefined,
            .end_line = null,
        };
    }
};

const TokenReader = struct {
    input: []u8,
    idx: usize,
    line: usize,
    col: usize,

    pub fn init(input: []u8) TokenReader {
        return TokenReader{
            .input = input,
            .idx = 0,
            .line = 1,
            .col = 1,
        };
    }

    pub fn peek(self: TokenReader) ?u8 {
        if (self.input.len <= self.idx + 1) {
            return null;
        }

        return self.input[self.idx + 1];
    }

    pub fn next(self: *TokenReader) ?u8 {
        const ch = self.peek() orelse return null;

        self.idx += 1;
        if (ch == '\n') {
            self.line += 1;
            self.col = 0;

            return ch;
        }

        self.col += 1;
        return ch;
    }

    pub fn skip(self: *TokenReader) void {
        _ = self.next();
    }
};

fn isAlpha(ch: u8) bool {
    return (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122);
}

fn isNumeric(char: ?u8) bool {
    if (char) |ch| {
        return ch >= 48 and ch <= 57;
    }

    return false;
}

fn canStartIdent(char: ?u8) bool {
    if (char) |ch| {
        return isAlpha(ch) or ch == '_';
    }

    return false;
}

fn isIdent(char: ?u8) bool {
    if (char) |ch| {
        return canStartIdent(ch) or isNumeric(ch);
    }

    return false;
}

fn determineKind(reader: *TokenReader) !Kind {
    if (reader.peek()) |ch| {
        if (ch == '"') {
            return .string_lit;
        }

        if (canStartIdent(ch)) {
            return .ident;
        }

        if (isNumeric(ch)) {
            return .int_lit;
        }

        var op: [1]u8 = .{ch}; // I'm lazy and don't want to write another function
        if (ops.isOpPrefix((op[0..]))) {
            return .op;
        }

        if (ch == ' ' or ch == '\n' or ch == '\t') {
            reader.skip();
            return .none;
        }
    }

    return LexError.EOF;
}

const Lexer = struct {
    alloc: std.mem.Allocator,

    // result collections
    tokens: ArrayList(Token),
    strings: Intern,

    // current context
    token: Token,
    buf: ArrayList(u8),

    fn pushToken(self: *Lexer) !void {
        switch (self.token.kind) {
            .ident => self.token.val = .{ .ident = try self.strings.intern(self.buf.items) },
            .string_lit => self.token.val = .{ .string_lit = try self.strings.intern(self.buf.items) },
            else => {},
        }

        try self.tokens.append(self.token);
        self.token = Token.default();
        self.buf.clearRetainingCapacity();
    }

    fn lexSpecial(self: *Lexer, reader: *TokenReader) !void {
        const ch = reader.next().?;
        if (special.getSpecial(ch)) |spec| {
            self.token.kind = .special;
            self.token.end_col = reader.col + 1;
            self.token.val = .{ .special = spec };
            try self.pushToken();
        }

        return LexError.UnrecognizedSymbol;
    }

    fn lexOp(self: *Lexer, reader: *TokenReader) !void {
        while (reader.peek()) |ch| {
            var substr: [3]u8 = undefined; // 3 chars is the largest an op can be
            @memcpy(&substr, self.buf.items);
            substr[self.buf.items.len] = ch;
            if (!ops.isOpPrefix(substr[0..(self.buf.items.len + 1)])) {
                if (ops.getOp(substr[0..self.buf.items.len])) |op| {
                    self.token.kind = .op;
                    self.token.end_col = reader.col;
                    self.token.val = .{ .op = op };
                    try self.pushToken();
                    return;
                }

                return LexError.InvalidOp;
            }

            reader.skip();
            try self.buf.append(ch);
        }
    }

    fn lexFloatLit(_: *Lexer, reader: *TokenReader) !void {
        while (isNumeric(reader.peek())) {
            reader.skip();
        }
    }

    fn lexIntLit(_: *Lexer, reader: *TokenReader) !void {
        while (isNumeric(reader.peek())) {
            reader.skip();
        }
    }

    fn lexStringLit(self: *Lexer, reader: *TokenReader) !void {
        var escaped = false;
        while (reader.next()) |ch| {
            try self.buf.append(ch);
            if (ch == '\\') {
                escaped = true;
                continue;
            }

            if (!escaped and ch == '"') {
                break;
            }

            escaped = false;
        }

        self.token.end_col = reader.col;
        self.token.kind = .string_lit;
        try self.pushToken();
    }

    fn lexIdent(self: *Lexer, reader: *TokenReader) !void {
        self.token.line = reader.line;
        self.token.start_col = reader.col;

        while (isIdent(reader.peek())) {
            try self.buf.append(reader.next().?);
        }

        if (keywords.getKeyword(self.buf.items)) |kw| {
            self.token.kind = .keyword;
            self.token.val = .{ .keyword = kw };
        } else {
            self.token.kind = .ident;
        }

        self.token.end_col = reader.col;
        try self.pushToken();
    }
};

const Result = struct {
    tokens: []Token,
    strings: Intern,
};

pub fn lex(alloc: std.mem.Allocator, input: []u8) !Result {
    var lexer = Lexer{
        .alloc = alloc,
        .tokens = ArrayList(Token).init(alloc),
        .strings = try Intern.init(alloc),
        .token = Token.default(),
        .buf = try ArrayList(u8).initCapacity(alloc, 1024),
    };

    var reader = TokenReader.init(input);

    while (true) {
        switch (lexer.token.kind) {
            .ident => lexer.lexIdent(&reader),
            .string_lit => lexer.lexStringLit(&reader),
            .int_lit => lexer.lexIntLit(&reader),
            .float_lit => lexer.lexFloatLit(&reader),
            .op => lexer.lexOp(&reader),
            .special => lexer.lexSpecial(&reader),
            .keyword => lexer.lexIdent(&reader), // shouldn't ever fall here
            .none => lexer.token.kind = determineKind(&reader),
        }
    }

    return .{
        .tokens = lexer.tokens.items,
        .strings = lexer.strings,
    };
}
