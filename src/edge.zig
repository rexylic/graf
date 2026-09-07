const std = @import("std");

const Vertex = @import("vertex.zig").Vertex;

fn VP(T: type) type {
    return *const Vertex(T);
}

pub fn Edge(T: type) type {
    return struct {
        label: []const u8 = "Unnamed edge",
        source: VP(T),
        sink: VP(T),
    };
}

pub fn arrow(comptime T: type, u: VP(T), v: VP(T)) Edge(T) {
    return Edge(T){ .source = u, .sink = v };
}

test {
    const a = Vertex(u8){ .data = 1 };
    const b = Vertex(u8){ .data = 2 };
    const e1 = Edge(u8){ .source = &a, .sink = &b };
    const e2 = arrow(u8, &a, &b);
    try std.testing.expectEqual(e1, e2);
}
