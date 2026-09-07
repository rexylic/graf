const std = @import("std");

const print = std.debug.print;
const expectSameString = std.testing.expectEqualStrings;
const expectEq = std.testing.expectEqual;

pub fn Vertex(T: type) type {
    return struct {
        label: []const u8 = "Unnamed vertex",
        data: T,
    };
}

pub fn box(item: anytype) Vertex(@TypeOf(item)) {
    return Vertex(@TypeOf(item)){ .data = item };
}

test {
    const u = Vertex(u4){ .data = 13 };
    try expectEq(u.data, 13);
    try expectSameString(u.label, "Unnamed vertex");
}

test {
    const fourteen: u8 = 14;
    var v = comptime box(fourteen);
    const label = "Hello";
    v.label = @ptrCast(label);
    try expectSameString(v.label, label);
}
