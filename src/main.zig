const std = @import("std");

// The tokenizer emits events with slices
const Token = union(enum) {
    whitespace: []u8, // whitespace to be ignored
    comment: []u8, // raw comment not incuding newline
    string: []u8, // raw string including quotes
    dec: []u8, // unparsed decimal number
    hex: []u8, // unparsed hexadecimal number
    oct: []u8, // unparsed octal number
    bin: []u8, // unparsed binary number
    ident: []u8, // raw selector name
    open: []u8, // open parenthesis
    close: []u8, // close parenthesis
};

const LexMode = enum {
    Whitespace,
    Comment,
    String,
    Zero,
    Dec,
    Hex,
    Octal,
    Binary,
    Open,
    Close,
    Ident,
};

fn tokenMode(byte: u8) LexMode {
    return switch (byte) {
        '#' => LexMode.Comment,
        '\'' => LexMode.String,
        '0' => LexMode.Zero,
        '(' => LexMode.Open,
        ')' => LexMode.Close,
        else => //
            if (isWhitespace(byte)) LexMode.Whitespace //
            else if (isDec(byte)) LexMode.Dec //
            else LexMode.Ident,
    };
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n';
}

fn isDec(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

fn isHex(byte: u8) bool {
    return isDec(byte) or byte >= 'a' and byte <= 'f' or byte >= 'A' and byte <= 'F';
}

fn isOct(byte: u8) bool {
    return byte >= '0' and byte <= '7';
}

fn isBin(byte: u8) bool {
    return byte == '0' or byte == '1';
}

const Parser = struct {
    fn parseFile(self: *Parser, filename: []const u8) !void {
        // Read the sample file and run it through tokenizer.
        const dir = std.fs.cwd();
        const buffer = try dir.readFileAlloc(std.testing.allocator, filename, 1024 * 1024);
        defer std.testing.allocator.free(buffer);
        return self.tokenize(buffer);
    }

    fn tokenize(self: *Parser, input: []const u8) void {
        var mode: LexMode = LexMode.Whitespace;
        var start: usize = 0;

        for (input) |byte, i| {
            switch (mode) {
                .Whitespace => if (!(byte == '\r' or byte == '\n' or byte == ' ' or byte == '\t')) {
                    if (i > start) {
                        self.onToken(Token{ .whitespace = input[start..i] });
                    }
                    start = i;
                    mode = tokenMode(byte);
                },
                .Comment => if (byte == '\r' or byte == '\n') {
                    self.onToken(Token{ .comment = input[start..i] });
                    start = i;
                    mode = LexMode.Whitespace;
                },
                .String => if (byte == '\'') {
                    self.onToken(Token{ .string = input[start .. i + 1] });
                    start = i + 1;
                    mode = LexMode.Whitespace;
                },
                .Zero => if (byte == 'x' or byte == 'X') {
                    mode = LexMode.Hex;
                } else if (byte == 'o' or byte == 'O') {
                    mode = LexMode.Octal;
                } else if (byte == 'b' or byte == 'B') {
                    mode = LexMode.Binary;
                } else if (byte >= '0' and byte <= '9') {
                    mode = LexMode.Dec;
                } else {
                    self.onToken(Token{ .dec = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Dec => if (!(byte >= '0' and byte <= '9')) {
                    self.onToken(Token{ .dec = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Hex => if (!(byte >= '0' and byte <= '9' or byte >= 'a' and byte <= 'f' or byte >= 'A' and byte <= 'F')) {
                    self.onToken(Token{ .hex = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Octal => if (!(byte >= '0' and byte <= '7')) {
                    self.onToken(Token{ .oct = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Binary => if (!(byte >= '0' and byte <= '1')) {
                    self.onToken(Token{ .bin = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Ident => if (isWhitespace(byte) or isDec(byte) or byte == '\'' or byte == '#') {
                    self.onToken(Token{ .ident = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Open => {
                    self.onToken(Token{ .open = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
                .Close => {
                    self.onToken(Token{ .close = input[start..i] });
                    start = i;
                    mode = tokenMode(byte);
                },
            }
        }
        // When we reach EOS, flush whatever token is leftover.
        switch (mode) {
            .Whitespace => self.onToken(Token{ .whitespace = input[start..] }),
            .Comment => self.onToken(Token{ .comment = input[start..] }),
            .String => self.onToken(Token{ .string = input[start..] }),
            .Zero => self.onToken(Token{ .dec = input[start..] }),
            .Dec => self.onToken(Token{ .dec = input[start..] }),
            .Hex => self.onToken(Token{ .hex = input[start..] }),
            .Octal => self.onToken(Token{ .oct = input[start..] }),
            .Binary => self.onToken(Token{ .bin = input[start..] }),
            .Ident => self.onToken(Token{ .ident = input[start..] }),
            .Open => self.onToken(Token{ .open = input[start..] }),
            .Close => self.onToken(Token{ .close = input[start..] }),
        }
    }

    fn onToken(self: *Parser, token: Token) void {
        const stdout = &std.io.getStdOut().outStream().stream;
        stdout.print("{}\n", .{token}) catch unreachable;
    }

    // recursive(limit=5 fields(
    //     'tree'(recursive(all(recurse)))
    //     'parents'(all(recurse)))
    // )
    // const shallowClone = Selector.recursiveLimited(5, &Selector.fielded(&[_]FieldEntry{
    //     FieldEntry.init("tree", &Selector.recursive(&Selector.all(&Selector.recurse()))),
    //     FieldEntry.init("parents", &Selector.all(&Selector.recurse())),
    // }));
    // try stdout.print("shallowClone = {}\n", .{shallowClone});
};

pub fn main() !void {
    const stdout = &std.io.getStdOut().outStream().stream;

    const parser = Parser{};
    try parser.parseFile("selectors/samples.ipldsel");

    // var hash = [_]u8{0} ** 32;
    // std.crypto.gimli.hash(hash[0..], buffer);
    // try stdout.print("hash {x}\n", .{hash[0..]});
}
