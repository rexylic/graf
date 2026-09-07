const std = @import("std");
const AHM = std.hash_map.AutoHashMap;

const Edge = @import("edge.zig").Edge;
const Vertex = @import("vertex.zig").Vertex;

pub fn Graph(T: type) type {
    const V = *const Vertex(T);
    const E = *const Edge(T);
    return struct {
        vertices: AHM(V, void),
        edges: AHM(E, void),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .vertices = .init(allocator),
                .edges = .init(allocator),
            };
        }

        pub fn deinit(i: *Self) void {
            i.vertices.deinit();
            i.edges.deinit();
        }

        /// Add vertex to the graph.
        /// Throws if out of memory.
        pub fn addVertex(i: *Self, v: V) !void {
            try i.vertices.put(v, {});
        }

        /// Add edge and its end vertices to the graph.
        /// Throws if out of memory.
        pub fn addEdge(i: *Self, e: E) !void {
            try i.edges.put(e, {});
            try i.vertices.put(e.source, {});
            try i.vertices.put(e.sink, {});
        }

        /// Remove vertex from the graph.
        pub fn removeVertex(i: *Self, v: V) bool {
            return i.vertices.remove(v);
        }

        /// Remove edge from the graph.
        pub fn removeEdge(i: *Self, e: E) bool {
            return i.edges.remove(e);
        }

        /// Remove edge and its end vertices from the graph.
        pub fn removeEdgeComplete(i: *Self, e: E) bool {
            _ = i.removeVertex(e.sink);
            _ = i.removeVertex(e.source);
            return i.edges.remove(e);
        }
    };
}

test {
    var g = Graph(u8).init(std.testing.allocator);
    defer g.deinit();

    const a = Vertex(u8){ .data = 1 };
    try g.addVertex(&a);

    const b = Vertex(u8){ .data = 2 };
    const e = Edge(u8){ .source = &a, .sink = &b };
    try g.addEdge(&e);
    try std.testing.expect(g.vertices.contains(&b));

    try std.testing.expect(g.removeVertex(&a));
    try std.testing.expect(!g.vertices.contains(&a));

    try std.testing.expect(g.removeEdge(&e));
    try std.testing.expect(!g.edges.contains(&e));
    try std.testing.expect(g.vertices.contains(&b));
}
