// src/data_structures/tree.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn TreeNode(comptime T: type) type {
    return struct {
        value: T,
        parent: ?*@This(),
        children: std.ArrayList(*@This()),

        const Self = @This();

        /// Initialize a new node
        pub fn init(allocator: Allocator, value: T) !*Self {
            const node = try allocator.create(Self);
            node.* = .{
                .value = value,
                .parent = null,
                .children = std.ArrayList(*Self).init(allocator),
            };
            return node;
        }

        /// Add a child to this node
        pub fn addChild(self: *Self, value: T) !*Self {
            const child = try Self.init(self.children.allocator, value);
            try self.children.append(child);
            child.parent = self;
            return child;
        }

        /// Recursively deallocate this node and its children
        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children.items) |child| {
                child.deinit(allocator);
            }
            self.children.deinit();
            allocator.destroy(self);
        }
    };
}

pub fn Tree(comptime T: type) type {
    return struct {
        root: *TreeNode(T),
        allocator: Allocator,

        /// Initialize a new tree
        pub fn init(allocator: Allocator, root_value: T) !*@This() {
            const root = try TreeNode(T).init(allocator, root_value);
            const tree = try allocator.create(@This());
            tree.* = .{ .root = root, .allocator = allocator };
            return tree;
        }

        /// Deinitialize the entire tree
        pub fn deinit(self: *@This()) void {
            self.root.deinit(self.allocator);
            self.allocator.destroy(self);
        }
    };
}
