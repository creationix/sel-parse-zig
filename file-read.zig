const std = @import("std");

pub fn main() !void {
    const res = std.fs.cwd().openRead("selectors/samples.ipldsel");

    const stdout = &std.io.getStdOut().outStream().stream;
    try stdout.print("res = {}\n", .{res});
}
