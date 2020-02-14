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

// The tokenizer emits events with slices
pub const Token = union(enum) {
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

pub fn tokenize(comptime T: type, state: T, input: []const u8, onToken: fn (state: T, token: Token) void) void {
    var mode: LexMode = LexMode.Whitespace;
    var start: usize = 0;

    for (input) |byte, i| {
        switch (mode) {
            .Whitespace => if (!(byte == '\r' or byte == '\n' or byte == ' ' or byte == '\t')) {
                if (i > start) {
                    onToken(state, Token{ .whitespace = input[start..i] });
                }
                start = i;
                mode = tokenMode(byte);
            },
            .Comment => if (byte == '\r' or byte == '\n') {
                onToken(state, Token{ .comment = input[start..i] });
                start = i;
                mode = LexMode.Whitespace;
            },
            .String => if (byte == '\'') {
                onToken(state, Token{ .string = input[start .. i + 1] });
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
                onToken(state, Token{ .dec = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Dec => if (!(byte >= '0' and byte <= '9')) {
                onToken(state, Token{ .dec = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Hex => if (!(byte >= '0' and byte <= '9' or byte >= 'a' and byte <= 'f' or byte >= 'A' and byte <= 'F')) {
                onToken(state, Token{ .hex = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Octal => if (!(byte >= '0' and byte <= '7')) {
                onToken(state, Token{ .oct = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Binary => if (!(byte >= '0' and byte <= '1')) {
                onToken(state, Token{ .bin = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Ident => if (isWhitespace(byte) or isDec(byte) or byte == '\'' or byte == '#') {
                onToken(state, Token{ .ident = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Open => {
                onToken(state, Token{ .open = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Close => {
                onToken(state, Token{ .close = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
        }
    }
    // When we reach EOS, flush whatever token is leftover.
    switch (mode) {
        .Whitespace => onToken(state, Token{ .whitespace = input[start..] }),
        .Comment => onToken(state, Token{ .comment = input[start..] }),
        .String => onToken(state, Token{ .string = input[start..] }),
        .Zero => onToken(state, Token{ .dec = input[start..] }),
        .Dec => onToken(state, Token{ .dec = input[start..] }),
        .Hex => onToken(state, Token{ .hex = input[start..] }),
        .Octal => onToken(state, Token{ .oct = input[start..] }),
        .Binary => onToken(state, Token{ .bin = input[start..] }),
        .Ident => onToken(state, Token{ .ident = input[start..] }),
        .Open => onToken(state, Token{ .open = input[start..] }),
        .Close => onToken(state, Token{ .close = input[start..] }),
    }
}
