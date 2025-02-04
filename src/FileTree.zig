const std = @import("std");
const Allocator = std.mem.Allocator;
const FileNode = @import("FileNode.zig").FileNode;
const Types = @import("Types.zig");
const Serializer = @import("Serializer.zig").Serializer;
pub const FileTree = struct {
    root: ?*FileNode = null,
    content_allocator: *std.heap.ArenaAllocator,
    allocator: Allocator,
    pub fn init(
        allocator: Allocator,
    ) !*FileTree {
        const self = try allocator.create(FileTree);
        const content_allocator = try allocator.create(std.heap.ArenaAllocator);
        content_allocator.* = std.heap.ArenaAllocator.init(allocator);

        self.* = .{
            .root = null,
            .content_allocator = content_allocator,
            .allocator = content_allocator.allocator(),
        };
        return self;
    }

    pub fn aggregate(nodeList: []const *FileNode, allocator: Allocator, prompt: []const u8) !std.ArrayList(u8) {
        var aggregateContext = std.ArrayList(u8).init(allocator);
        try aggregateContext.appendSlice("PROMPT % ");
        try aggregateContext.appendSlice(prompt);
        try aggregateContext.appendSlice("\n");
        try aggregateContext.appendSlice("CONTEXT % ");
        try aggregateContext.appendSlice("$$$");
        for (nodeList) |file| {
            if (file.is_dir == 0) {
                try file.loadContent();
                defer file.unloadContent();
                if (file.content) |content| {
                    try aggregateContext.appendSlice("\n");
                    try aggregateContext.appendSlice("$$");
                    try aggregateContext.appendSlice("\n");
                    try aggregateContext.appendSlice("file path$ ");
                    try aggregateContext.appendSlice(file.path);
                    try aggregateContext.appendSlice("\n");
                    try aggregateContext.appendSlice(content);
                }
            }
        }
        return aggregateContext;
    }
    pub fn traverse(current: *FileNode, allocator: Allocator) ![]const *FileNode {
        var nodeList = std.ArrayList(*FileNode).init(allocator);
        var currNode = current;
        if (currNode.parent) |parent| {
            if (parent.children) |children| {
                for (children.items) |child| {
                    try nodeList.append(child);
                }
            }
        }
        while (currNode.parent) |parent| {
            try nodeList.append(currNode);
            currNode = parent;
        }
        return nodeList.toOwnedSlice();
    }
    pub fn completion(
        self: *FileTree,
        currNode: *FileNode,
        prompt: []const u8,
        model: []const u8,
        api_key: []const u8,
    ) !void {
        const nodeList = try traverse(currNode, self.allocator);
        var contextBuffer = try aggregate(nodeList, self.allocator, prompt);
        defer contextBuffer.deinit();
        const serialized_query = try Serializer.formatBuffer(self.allocator, try contextBuffer.toOwnedSlice());
        try currNode.invoke(serialized_query, model, api_key);
    }

    pub fn deinit(self: *FileTree) void {
        const alloc = self.content_allocator.child_allocator;
        self.content_allocator.deinit();
        alloc.destroy(self.content_allocator);
    }
};
