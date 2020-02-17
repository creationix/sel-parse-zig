const std = @import("std");
const lexer = @import("./lexer.zig");
const readNext = lexer.readNext;
const Token = lexer.Token;

const expectEqual = std.testing.expectEqual;
const stdout = &std.io.getStdOut().outStream().stream;

test "integers" {
    stdout.print("\n", .{}) catch unreachable;
    inline for (.{ "0 way", "100", "0x1", "0xf", " ", "0xg", "0XDEADBEEF", "1", "1234567890" }) |input| {
        stdout.print("`{}` -> {}\n", .{ input, readNext(input) }) catch unreachable;
    }
}

test "strings" {
    stdout.print("\n", .{}) catch unreachable;
    inline for (.{ "string", "'string'", "'string' 'string'", "''X", "'multiline\r\nstring'", "'open string" }) |input| {
        stdout.print("`{}` -> {}\n", .{ input, readNext(input) }) catch unreachable;
    }
}

test "comments" {
    stdout.print("\n", .{}) catch unreachable;
    inline for (.{ "//open comment", "\n//comment later\n", "// comment", "//\r", "//\n", "// comment\r\na" }) |input| {
        stdout.print("`{}` -> {}\n", .{ input, readNext(input) }) catch unreachable;
    }
}

test "identifiers" {
    stdout.print("\n", .{}) catch unreachable;
    inline for (.{ "one", "recursel", "recursive", "aalll", "all", "rx" }) |input| {
        stdout.print("`{}` -> {}\n", .{ input, readNext(input) }) catch unreachable;
    }
}

test "unknown" {
    stdout.print("\n", .{}) catch unreachable;
    inline for (.{ "bad2", "%6%", "aalll", "all", "xr", "" }) |input| {
        stdout.print("`{}` -> {}\n", .{ input, readNext(input) }) catch unreachable;
    }
}

test "automated" {
    stdout.print("\n", .{}) catch unreachable;
    const input0 = " spaced";
    expectEqual(readNext(input0), Token{ .id = .Whitespace, .slice = input0[0..1] });
    const input1 = "bad2";
    expectEqual(readNext(input1), Token{ .id = .Unknown, .slice = input1[0..3] });
    const input2 = "%6%";
    expectEqual(readNext(input2), Token{ .id = .Unknown, .slice = input2[0..1] });
    const input3 = "aalll";
    expectEqual(readNext(input3), Token{ .id = .Unknown, .slice = input3[0..1] });
    const input4 = "all";
    expectEqual(readNext(input4), Token{ .id = .Identifier, .slice = input4[0..3] });
    const input5 = "xr";
    expectEqual(readNext(input5), Token{ .id = .Unknown, .slice = input5[0..1] });
    const input6 = "";
    expectEqual(readNext(input6), Token{ .id = .Unknown, .slice = input6[0..0] });
}

test "while file" {
    const buffer = @embedFile("../selectors/samples.ipldsel");
    var i: usize = 0;
    stdout.print("\n`{}`\n", .{buffer}) catch unreachable;
    while (i < buffer.len) {
        // stdout.print("`{}`\n", .{buffer[i..]}) catch unreachable;
        const token = readNext(buffer[i..]);
        stdout.print("{}\t{}\t{Bi}\t`{}`\n", .{ i, token.id, token.slice.len, token.slice }) catch unreachable;
        i += token.slice.len;
    }
}
