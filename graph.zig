//! Graph implementation with O(1) lookup, update and delete.

const std = @import("std");

const Alloc = std.mem.Allocator;
const AHM = std.array_hash_map.Auto;

fn Neighborhood(V: type, E: type) type {
    return struct {
        const PartialNb = AHM(V, E);

        alloc: *Alloc,
        ins: PartialNb,
        outs: PartialNb,

        fn init(alloc: *Alloc) @This() {
            return .{
                .alloc = alloc,
                .ins = PartialNb.empty,
                .outs = PartialNb.empty,
            };
        }

        fn deinit(this: *@This()) void {
            this.ins.deinit(this.alloc.*);
            this.outs.deinit(this.alloc.*);
        }

        /// Vertex in-degree.
        fn inDeg(this: *const @This()) usize {
            return this.ins.count();
        }

        /// Vertex out-degree.
        fn outDeg(this: *const @This()) usize {
            return this.outs.count();
        }

        /// Vertex degree.
        fn deg(this: *const @This()) usize {
            return this.inDeg() + this.outDeg();
        }

        /// Add an in-edge.
        /// Return whether edge is added.
        fn addIn(this: *@This(), v: V, e: E) !bool {
            const gop = try this.ins.getOrPut(this.alloc.*, v);
            if (gop.found_existing) return false;
            gop.value_ptr.* = e;
            return true;
        }

        /// Add an out-edge.
        /// Return whether edge is added.
        fn addOut(this: *@This(), v: V, e: E) !bool {
            const gop = try this.outs.getOrPut(this.alloc.*, v);
            if (gop.found_existing) return false;
            gop.value_ptr.* = e;
            return true;
        }

        /// Replace current in-vertex with new vertex.
        /// Return whether vertex is replaced.
        fn replIn(this: *@This(), old: V, new: V) !bool {
            if (!this.ins.contains(old) or this.ins.contains(new)) return false;
            const kv = this.ins.fetchSwapRemove(old).?;
            try this.ins.put(this.alloc.*, new, kv.value);
            return true;
        }

        /// Replace current out-vertex with new vertex.
        /// Return whether vertex is replaced.
        fn replOut(this: *@This(), old: V, new: V) !bool {
            if (!this.outs.contains(old) or this.outs.contains(new)) return false;
            const kv = this.outs.fetchSwapRemove(old).?;
            try this.outs.put(this.alloc.*, new, kv.value);
            return true;
        }

        /// Delete the in-edge to vertex.
        /// Return edge item.
        fn delIn(this: *@This(), v: V) ?E {
            if (this.ins.fetchSwapRemove(v)) |kv| return kv.value;
            return null;
        }

        /// Delete the out-edge to vertex.
        /// Return edge item.
        fn delOut(this: *@This(), v: V) ?E {
            if (this.outs.fetchSwapRemove(v)) |kv| return kv.value;
            return null;
        }
    };
}

pub fn Graph(V: type, E: type) type {
    return struct {
        const Nh = Neighborhood(V, E);

        alloc: Alloc,
        nodes: AHM(V, Nh),

        pub fn init(alloc: Alloc) !@This() {
            return .{ .alloc = alloc, .nodes = AHM(V, Nh).empty };
        }

        pub fn deinit(this: *@This()) void {
            var nodes_iter = this.nodes.iterator();
            while (nodes_iter.next()) |node| node.value_ptr.deinit();
            this.nodes.deinit(this.alloc);
        }

        /// If graph has vertex.
        pub fn hasNode(this: *const @This(), v: V) bool {
            return this.nodes.contains(v);
        }

        /// Get neighbourhood of vertex.
        pub fn getNh(this: *const @This(), v: V) ?*Nh {
            return this.nodes.getPtr(v);
        }

        /// If graph has edge.
        pub fn hasEdge(this: *const @This(), u: V, v: V) bool {
            if (!this.hasNode(u)) return false;
            if (!this.hasNode(v)) return false;
            return this.getNh(u).?.outs.contains(v);
        }

        /// Add vertex if doesn't exist.
        /// Return whether vertex is added.
        pub fn add(this: *@This(), v: V) !bool {
            if (this.hasNode(v)) return false;
            try this.nodes.put(this.alloc, v, Nh.init(&this.alloc));
            return true;
        }

        /// Remove vertex if exists.
        /// Return whether vertex is removed.
        pub fn remove(this: *@This(), v: V) bool {
            if (!this.hasNode(v)) return false;
            {
                const neigh = this.getNh(v).?;
                defer neigh.deinit();

                var iter = neigh.ins.iterator();
                while (iter.next()) |x| _ = this.getNh(x.key_ptr.*).?.delOut(v);

                iter = neigh.outs.iterator();
                while (iter.next()) |x| _ = this.getNh(x.key_ptr.*).?.delIn(v);
            }
            _ = this.nodes.swapRemove(v);
            return true;
        }

        /// Draw an edge.
        pub fn draw(this: *@This(), u: V, v: V, e: E) !void {
            _ = try this.add(u);
            _ = try this.add(v);
            _ = try this.getNh(u).?.addOut(v, e);
            _ = try this.getNh(v).?.addIn(u, e);
        }

        /// Delete an edge.
        /// Return the edge item if edge exists.
        pub fn delete(this: *@This(), u: V, v: V) !?E {
            if (!this.hasNode(u) or !this.hasNode(v)) return null;
            const e = this.getNh(u).?.delOut(v) orelse return null;
            return e orelse this.getNh(v).?.delIn(u);
        }

        /// Contract an edge.
        /// Neighbours of the edge tail are re-drawn to the head.
        /// Return the edge item if edge exists.
        pub fn contract(this: *@This(), u: V, v: V) !?E {
            const e = this.delete(u, v) catch null orelse return null;
            {
                const nh = this.getNh(u).?;

                var iter = nh.ins.iterator();
                while (iter.next()) |x| _ = try this.getNh(x.key_ptr.*).?.replOut(u, v);

                iter = nh.outs.iterator();
                while (iter.next()) |x| _ = try this.getNh(x.key_ptr.*).?.replIn(u, v);
            }
            _ = this.remove(u);
            return e;
        }
    };
}

const t = std.testing;

test "init" {
    var g = try Graph(u8, u8).init(t.allocator);
    defer g.deinit();
}

test "add and remove vertex" {
    var g = try Graph(u8, u8).init(t.allocator);
    defer g.deinit();

    _ = try g.add(3);
    try t.expect(g.hasNode(3));

    _ = g.remove(3);
    try t.expect(!g.hasNode(3));
}

test "add and remove edge" {
    var g = try Graph(u8, u8).init(t.allocator);
    defer g.deinit();

    _ = try g.draw(3, 4, 0);
    _ = try g.draw(4, 5, 1);
    try t.expect(g.hasEdge(3, 4));

    const res = try g.delete(3, 4);
    try t.expectEqual(res.?, 0);
    try t.expect(!g.hasEdge(3, 4));
    try t.expect(g.hasEdge(4, 5));
    try t.expect(g.hasNode(3));
    try t.expect(g.hasNode(4));
    try t.expect(g.hasNode(5));
}

test "contract edge" {
    var g = try Graph(u8, u8).init(t.allocator);
    defer g.deinit();

    _ = try g.draw(0, 1, 0);
    _ = try g.draw(1, 2, 1);
    try t.expect(!g.hasEdge(0, 2));

    const res = try g.contract(1, 2);
    try t.expectEqual(res.?, 1);
    try t.expect(g.hasEdge(0, 2));
}
