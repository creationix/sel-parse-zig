const std = @import("std");
const lexer = @import("./lexer.zig");

const Parser = struct {
    fn parseFile(self: *Parser, filename: []const u8) !void {
        // Read the sample file and run it through tokenizer.
        const dir = std.fs.cwd();
        const buffer = try dir.readFileAlloc(std.testing.allocator, filename, 1024 * 1024);
        defer std.testing.allocator.free(buffer);
        return self.tokenize(buffer);
    }

    fn tokenize(self: *Parser, input: []const u8) void {
        lexer.tokenize(*Parser, self, input, Parser.onToken);
    }

    fn onToken(self: *Parser, token: lexer.Token) void {
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
