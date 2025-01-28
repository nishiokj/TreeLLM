// src/file_tree.zig
const std = @import("std");
const Allocator = std.mem.Allocator;
const TreeNode = @import("./Tree.zig").TreeNode;
const Tree = @import("./Tree.zig").Tree;
const FileNode = @import("./FileNode.zig").FileNode;

pub const FileTree = struct {
    root: *FileNode,
    node_allocator: Allocator,
    content_allocator: Allocator,
    nodes: std.StringHashMap(*FileNode),
    pub fn init(
        root_path: []const u8,
        node_allocator: Allocator,
        content_allocator: Allocator,
    ) !*FileTree {
        const self = try node_allocator.create(FileTree);
        self.* = .{
            .root = try FileNode.init(
                node_allocator,
                null,
                root_path,
                content_allocator,
            ),
            .node_allocator = node_allocator,
            .content_allocator = content_allocator,
        };
        return self;
    }

    pub fn deinit(self: *FileTree) void {
        self.root.deinit();
        self.node_allocator.destroy(self);
    }
};
