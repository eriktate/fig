const std = @import("std");
const ArrayList = std.ArrayList;
const lex = @import("lex.zig");
const iter = @import("iterator.zig");

const ParseErr = error{
    UnexpectedToken,
    ExpectedToken,
    ExpectedExpr,
};

const BinOp = enum {
    add,
    sub,
    div,
    mul,
    mod,
    dot,
    assign,
    bitAnd,
    bitOr,
    logAnd,
    logOr,
    constAssign,
    addAssign,
    subAssign,
    mulAssign,
    divAssign,
    modAssign,
    andAssign,
    orAssign,
    xorAssign,
};

const UnaryOp = enum {
    not,
    neg,
    ref,
    deref,
};

const TypeKind = enum {
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
    Rune,
    Str,
    Struct,
    Func,
    Infer,
};

const Type = union(TypeKind) {
    U8: void,
    U16: void,
    U32: void,
    U64: void,
    U128: void,
    I8: void,
    I16: void,
    I32: void,
    I64: void,
    I128: void,
    F32: void,
    F64: void,
    Bool: void,
    Byte: void,
    Rune: void,
    Str: void,
    Struct: []u8,
    Func: []u8,
    Infer: void,
};

const BindDecl = struct {
    ident: []u8,
    type: Type,
};

const BindExpr = struct {
    decl: BindDecl,
    value: Expr,
};

const BinExpr = struct {
    left: Expr,
    right: Expr,
    op: BinOp,
};

const UnaryExpr = struct {
    op: UnaryOp,
    expr: Expr,
};

const GroupExpr = struct {
    inner: Expr,
};

const CallExpr = struct {
    ident: []u8,
    args: []Expr,
};

const StructDecl = struct {
    ident: []u8,
    fields: []BindDecl, // might need something specific for exprs that evaluate to types
};

const FuncDecl = struct {
    params: []BindDecl,
    return_type: Type,
};

const IdentExpr = struct {
    ident: []u8,
};

const StringLitExpr = struct {
    val: []u8,
};

const IntLitExpr = struct {
    val: usize,
};

const FloatLitExpr = struct {
    val: f64,
};

const ExprKind = enum {
    bind,
    binary,
    unary,
    group,
    call,
    func,
    stmt,
    strct,
    ident,
    int_lit,
    float_lit,
    string_lit,
};

const Statement = struct {
    expr: Expr,
};

const Expr = union(ExprKind) {
    bind: BindExpr,
    binary: BinExpr,
    unary: UnaryExpr,
    group: GroupExpr,
    call: CallExpr,
    strct: StructDecl,
    ident: IdentExpr,
    int_lit: IntLitExpr,
    float_lit: FloatLitExpr,
    string_lit: StringLitExpr,
};

pub const Mode = enum {
    unknown,
};

pub const Scope = enum {
    file,
    func,
};

fn requireToken(kind: lex.Kind, token: ?lex.Token) !lex.Token {
    if (token) |tok| {
        if (tok.kind != kind) {
            return ParseErr.UnexpectedToken;
        }

        return tok;
    }

    return ParseErr.ExpectedToken;
}

pub const Parser = struct {
    alloc: std.mem.Allocator,
    mode: Mode,
    scope: Scope,
    tokens: iter.Iterator(lex.Token),
    exprs: ArrayList(Expr),

    pub fn init(alloc: std.mem.Allocator, tokens: []lex.Token) Parser {
        return .{
            .alloc = alloc,
            .mode = .unknown,
            .tokens = iter.Iterator(lex.Token).init(tokens),
        };
    }

    fn parseKeyword(kw: lex.Keyword) Expr {}

    fn parseString(string: []u8) Expr {}

    fn parseInt(int: []u8) Expr {}

    fn parseFloat(float: []u8) Expr {}

    fn parseUnary(sym: lex.Symbol) !Expr {
        return switch (sym) {
            .bang => .{ .unary = .{ .op = .neg } },
            .minus => .{ .unary = .{ .op = .neg } },
            .star => .{ .unary = .{ .op = .deref } },
            .bit_and => .{ .unary = .{ .op = .ref } },
            else => ParseErr.UnexpectedToken,
        };
    }

    fn parseCall(self: Parser) Expr {}

    fn parseExpr(self: Parser) Expr {
        var token = self.tokens.peek();
        if (token == null) {
            return ParseErr.ExpectedExpr;
        }

        var tok = token.?;
        var left = switch (tok.value) {
            .ident => |ident| IdentExpr{ .ident = ident },
            .symbol => |sym| parseUnary(sym),
            .int_lit => |int| parseInt(tok),
            .float_lit => |float| parseFloat(tok),
            .string_lit => |string| parseString(string),
            .keyword => |kw| parseKeyword(kw),
        };

        self.tokens.skip();
        if (self.tokens.peek()) |bin_op| {
            if (bin_op.kind == sym)
        }
    }

    fn parseBinding(self: Parser) !void {
        var ident = try requireToken(.ident, self.tokens.next());
        var const_sym = try requireToken(.symbol, self.tokens.next());
        if (const_sym.value.symbol != .infer_const) {
            return ParseErr.ExpectedToken;
        }

        var value = try self.parseExpr();
    }

    fn parse(self: Parser) !void {
        switch (self.scope) {
            // at file scope, bindings are the only expected statements
            .file => parseBinding(),
            .func => parseFunc(),
        }
    }
};

pub fn parse(alloc: std.mem.Allocator, tokens: []lex.Token) !void {
    var parser = Parser.init(alloc);
    for (tokens) |token| {
        switch (parser.mode) {
            .unknown => parser.parseUnknown(token),
        }
    }
}
