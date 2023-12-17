pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []T,
        idx: usize,

        fn init(slice: []T) Self {
            return .{
                .slice = slice,
                .idx = 0,
            };
        }

        fn next(self: *Self) ?T {
            if (peek(self)) |result| {
                self.idx += 1;
                return result;
            }

            return null;
        }

        fn peek(self: *Self) ?T {
            if (self.idx < self.slice.len) {
                return self.slice[self.idx];
            }

            return null;
        }

        fn skip(self: *Self) void {
            _ = self.next();
        }

        fn reset(self: *Iterator) void {
            self.idx = 0;
        }
    };
}
