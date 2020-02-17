const Id = enum {
    Whitespace, // whitespace to be ignored
        Comment, // raw comment not incuding newline
        String, // raw string including quotes
        Decimal, // unparsed decimal number
        Hexadecimal, // unparsed hexadecimal number
        Octal, // unparsed octal number
        Binary, // unparsed binary number
        Identifier, // raw selector name
        Open, // open parenthesis
        Close, // close parenthesis
        Unknown // unexpected characters
};

// The tokenizer emits events with slices
pub const Token = struct {
    id: Id,
    slice: []const u8,
};

pub fn readNext(input: []const u8) Token {
    if (input.len > 0) {
        if (readToken(input)) |token| return token;
        var i: usize = 1;
        while (input.len - i >= 1) : (i += 1) {
            if (readToken(input[i..])) |_| {
                return Token{ .id = .Unknown, .slice = input[0..i] };
            }
        }
    }
    return Token{ .id = .Unknown, .slice = input };
}

// Sorted by longest first, then lexical within same length.
const identifiers = .{
    "condition",
    "recursive",
    "recurse",
    "fields",
    "index",
    "match",
    "range",
    "union",
    "all",
    ".",
    "*",
    "~",
    "c",
    "f",
    "i",
    "r",
    "R",
    "u",
};

// This assumes input is at least one byte long.  Sending in an empty slice will crash.
fn readToken(input: []const u8) ?Token {
    { // Tokenize Parentheses
        if (input[0] == '(') return Token{ .id = .Open, .slice = input[0..1] };
        if (input[0] == ')') return Token{ .id = .Close, .slice = input[0..1] };
    }
    { // Tokenize Integers
        if (input[0] == '0' and input.len >= 3) {
            if ((input[1] == 'b' or input[1] == 'B') and isBin(input[2])) {
                var i: usize = 2;
                while (i < input.len and isBin(input[i])) i += 1;
                return Token{ .id = .Binary, .slice = input[0..i] };
            }
            if ((input[1] == 'o' or input[1] == 'O') and isOct(input[2])) {
                var i: usize = 2;
                while (i < input.len and isOct(input[i])) i += 1;
                return Token{ .id = .Octal, .slice = input[0..i] };
            }
            if ((input[1] == 'x' or input[1] == 'X') and isHex(input[2])) {
                var i: usize = 2;
                while (i < input.len and isHex(input[i])) i += 1;
                return Token{ .id = .Hexadecimal, .slice = input[0..i] };
            }
        }
        if (isDec(input[0])) {
            var i: usize = 1;
            while (i < input.len and isDec(input[i])) i += 1;
            return Token{ .id = .Decimal, .slice = input[0..i] };
        }
    }
    { // Tokenize Comments
        if (input.len >= 2 and input[0] == '/' and input[1] == '/') {
            var i: usize = 2;
            while (i < input.len and input[i] != '\r' and input[i] != '\n') i += 1;
            return Token{ .id = .Comment, .slice = input[0..i] };
        }
    }
    { // Tokenize Strings
        if (input[0] == '\'') {
            var i: usize = 1;
            while (i < input.len) : (i += 1) {
                if (input[i] == '\'') return Token{ .id = .String, .slice = input[0 .. i + 1] };
            }
        }
    }
    { // Tokenize Whitespace
        if (isWhitespace(input[0])) {
            var i: usize = 1;
            while (i < input.len and isWhitespace(input[i])) i += 1;
            return Token{ .id = .Whitespace, .slice = input[0..i] };
        }
    }
    { // Tokenize Identifiers
        inline for (identifiers) |ident| {
            var matched = true;
            var i: usize = 0;
            while (i < ident.len) : (i += 1) {
                if (i >= input.len or ident[i] != input[i]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return Token{ .id = .Identifier, .slice = input[0..i] };
        }
    }
    return null;
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n';
}

fn isDec(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

fn isHex(byte: u8) bool {
    return isDec(byte) or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F');
}

fn isOct(byte: u8) bool {
    return byte >= '0' and byte <= '7';
}

fn isBin(byte: u8) bool {
    return byte == '0' or byte == '1';
}
