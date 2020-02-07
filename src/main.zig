const std = @import("std");

const Selector = union(enum) {
    Match: Matcher,
    All: ExploreAll,
    Fields: ExploreFields,
    Index: ExploreIndex,
    Range: ExploreRange,
    Recursive: ExploreRecursive,
    Union: ExploreUnion,
    Conditional: ExploreConditional,
    Recurse: void,

    pub fn match() Selector {
        return Selector{
            .Match = Matcher{ .onlyIf = null, .label = null },
        };
    }

    pub fn matchLabelled(label: []u8) Selector {
        return Selector{
            .Match = Matcher{ .onlyIf = null, .label = label },
        };
    }

    pub fn all(next: *const Selector) Selector {
        return Selector{
            .All = ExploreAll{ .next = next },
        };
    }

    pub fn recurse() Selector {
        return Selector{ .Recurse = undefined };
    }

    pub fn fielded(fields: []const FieldEntry) Selector {
        return Selector{
            .Fields = ExploreFields{ .fields = fields },
        };
    }

    pub fn indexed(index: u32, next: *const Selector) Selector {
        return Selector{
            .Index = ExploreIndex{ .index = index, .next = next },
        };
    }

    pub fn range(start: u32, end: u32, next: *const Selector) Selector {
        return Selector{
            .Range = ExploreRange{ .start = start, .end = end, .next = next },
        };
    }

    pub fn recursive(sequence: *const Selector) Selector {
        return Selector{
            .Recursive = ExploreRecursive{
                .limit = RecursionLimit.None,
                .sequence = sequence,
                .stopAt = null,
            },
        };
    }
    pub fn recursiveLimited(limit: u32, sequence: *const Selector) Selector {
        return Selector{
            .Recursive = ExploreRecursive{
                .limit = RecursionLimit{ .Depth = limit },
                .sequence = sequence,
                .stopAt = undefined,
            },
        };
    }

    pub fn unioned(list: []*const Selector) Selector {
        return Selector{
            .Union = ExploreUnion{ .list = list },
        };
    }

    pub fn conditional(condition: Condition, next: *const Selector) Selector {
        return Selector{
            .Conditional = ExploreConditional{ .condition = condition, .next = next },
        };
    }
};

const Matcher = struct {
    onlyIf: ?Condition = null,
    label: ?[]u8 = null,
};

const ExploreAll = struct {
    next: *const Selector,
};

const FieldEntry = struct {
    field: []const u8,
    next: *const Selector,

    pub fn init(field: []const u8, next: *const Selector) FieldEntry {
        return FieldEntry{ .field = field, .next = next };
    }
};

const ExploreFields = struct {
    fields: []const FieldEntry,
};

const ExploreIndex = struct {
    index: u32,
    next: *const Selector,
};

const ExploreRange = struct {
    start: u32,
    end: u32,
    next: *const Selector,
};

const ExploreRecursive = struct {
    limit: RecursionLimit,
    sequence: *const Selector,
    stopAt: ?Condition = null,
};

const ExploreUnion = struct {
    list: []*const Selector,
};

const ExploreConditional = struct {
    condition: Condition,
    next: *const Selector,
};

const Condition = struct {}; // TODO: specify this.
const RecursionLimit = union(enum) {
    None: void,
    Depth: u32,
};

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

// Given an input slice of bytes, emit token events via the callback function.
fn tokenize(input: []const u8, onToken: fn (token: Token) void) void {
    var mode: LexMode = LexMode.Whitespace;
    var start: usize = 0;

    for (input) |byte, i| {
        switch (mode) {
            .Whitespace => if (!(byte == '\r' or byte == '\n' or byte == ' ' or byte == '\t')) {
                if (i > start) {
                    onToken(Token{ .whitespace = input[start..i] });
                }
                start = i;
                mode = tokenMode(byte);
            },
            .Comment => if (byte == '\r' or byte == '\n') {
                onToken(Token{ .comment = input[start..i] });
                start = i;
                mode = LexMode.Whitespace;
            },
            .String => if (byte == '\'') {
                onToken(Token{ .string = input[start .. i + 1] });
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
                onToken(Token{ .dec = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Dec => if (!(byte >= '0' and byte <= '9')) {
                onToken(Token{ .dec = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Hex => if (!(byte >= '0' and byte <= '9' or byte >= 'a' and byte <= 'f' or byte >= 'A' and byte <= 'F')) {
                onToken(Token{ .hex = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Octal => if (!(byte >= '0' and byte <= '7')) {
                onToken(Token{ .oct = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Binary => if (!(byte >= '0' and byte <= '1')) {
                onToken(Token{ .bin = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Ident => if (isWhitespace(byte) or isDec(byte) or byte == '\'' or byte == '#') {
                onToken(Token{ .ident = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Open => {
                onToken(Token{ .open = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
            .Close => {
                onToken(Token{ .close = input[start..i] });
                start = i;
                mode = tokenMode(byte);
            },
        }
    }
    // When we reach EOS, flush whatever token is leftover.
    switch (mode) {
        .Whitespace => onToken(Token{ .whitespace = input[start..] }),
        .Comment => onToken(Token{ .comment = input[start..] }),
        .String => onToken(Token{ .string = input[start..] }),
        .Zero => onToken(Token{ .dec = input[start..] }),
        .Dec => onToken(Token{ .dec = input[start..] }),
        .Hex => onToken(Token{ .hex = input[start..] }),
        .Octal => onToken(Token{ .oct = input[start..] }),
        .Binary => onToken(Token{ .bin = input[start..] }),
        .Ident => onToken(Token{ .ident = input[start..] }),
        .Open => onToken(Token{ .open = input[start..] }),
        .Close => onToken(Token{ .close = input[start..] }),
    }
}

pub fn main() !void {
    const stdout = &std.io.getStdOut().outStream().stream;

    // recursive(limit=5 fields(
    //     'tree'(recursive(all(recurse)))
    //     'parents'(all(recurse)))
    // )
    // const shallowClone = Selector.recursiveLimited(5, &Selector.fielded(&[_]FieldEntry{
    //     FieldEntry.init("tree", &Selector.recursive(&Selector.all(&Selector.recurse()))),
    //     FieldEntry.init("parents", &Selector.all(&Selector.recurse())),
    // }));
    // try stdout.print("shallowClone = {}\n", .{shallowClone});

    const res = std.fs.cwd().openRead("selectors/samples.ipldsel");
    try stdout.print("res = {}\n", .{res});

    // tokenize("  # Comment\n  'string' 'another''string' 123 0x1fd 0o664889 0b1001010 0 001 R5f'tree'R*~'parents'*~", dumpToken);
}

fn dumpToken(token: Token) void {
    const stdout = &std.io.getStdOut().outStream().stream;
    stdout.print("{}\n", .{token}) catch unreachable;
}
