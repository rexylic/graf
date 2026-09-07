//! Like a graph but uses a hash to store edges and vertices.

const std = @import("std");
const Alloc = std.mem.Allocator;
const Dict = std.hash_map.AutoHashMap;

pub fn Map(comptime NodeType: type, comptime EdgeType: type) type {
    const V = NodeType;
    const E = EdgeType;

    return struct {
        /// Map of nodes and edges
        nodes: Dict(V, ?Dict(V, E)),
        edges: Dict(E, struct { V, V }),

        /// Self type
        pub const I = @This();

        /// Initialize a GraphMap
        pub fn init(allocator: Alloc) I {
            return I{
                .nodes = .init(allocator),
                .edges = .init(allocator),
            };
        }

        /// Deinitialize a GraphMap
        pub fn deinit(i: *I) void {
            var ki = i.nodes.keyIterator();
            while (ki.next()) |node| {
                const edges = i.neighbours(node.*) orelse continue;
                edges.deinit();
            }
            i.nodes.deinit();
            i.edges.deinit();
        }

        // ========== NODE ==========

        /// Mutable pointer to a hash map of neighbours of node, if node is in self
        fn neighbours(i: *I, node: V) ?*Dict(V, E) {
            const maybe_edges = i.nodes.getPtr(node) orelse return null;
            if (maybe_edges.*) |*edges| return edges;
            return null;
        }

        /// Add a node to the graph
        pub fn addNode(i: *I, node: V) !bool {
            if (i.nodes.contains(node)) return false;
            try i.nodes.put(node, null);
            return true;
        }

        /// Remove a node to the graph
        pub fn delNode(i: *I, node: V) bool {
            if (!i.nodes.contains(node)) return false;
            if (i.neighbours(node)) |edges| {
                var ev = edges.valueIterator();
                while (ev.next()) |edge| _ = i.edges.remove(edge.*);
                edges.deinit();
            }
            _ = i.nodes.remove(node);
            return true;
        }

        // ========== EDGE ==========

        pub fn hasEdge(i: *const I, from: V, to: V) bool {
            const maybe_edges = i.nodes.getPtr(from) orelse return false;
            if (maybe_edges.*) |*edges| return edges.contains(to);
            return false;
        }

        pub fn getEdge(i: *const I, from: V, to: V) ?E {
            if (!i.hasEdge(from, to)) return null;
            return i.nodes.get(from).?.?.get(to).?;
        }

        pub fn addEdge(i: *I, from: V, to: V, item: E, allocator: Alloc) !bool {
            if (i.hasEdge(from, to) or i.edges.contains(item)) return false;
            _ = try i.addNode(from);
            _ = try i.addNode(to);
            try i.edges.put(item, .{ from, to });
            if (i.neighbours(from) == null) try i.nodes.put(from, .init(allocator));
            try i.neighbours(from).?.put(to, item);
            return true;
        }

        pub fn delEdge(i: *I, from: V, to: V) bool {
            if (i.getEdge(from, to)) |edge| {
                _ = i.edges.remove(edge);
                _ = i.neighbours(from).?.remove(to);
                return true;
            } else return false;
        }
    };
}

test {
    const assert = std.testing.expect;
    const alloc = std.testing.allocator;

    var map = Map(u8, u8).init(alloc);
    defer map.deinit();

    try assert(try map.addNode(0));
    try assert(try map.addNode(1));
    try assert(try map.addEdge(2, 3, 0, alloc));
    try assert(!try map.addEdge(2, 3, 1, alloc));
    try assert(try map.addEdge(1, 3, 1, alloc));
    try assert(!map.delNode(4));
    try assert(map.delNode(0));
    try assert(map.delEdge(1, 3));
    try assert(!map.delEdge(5, 6));
}
