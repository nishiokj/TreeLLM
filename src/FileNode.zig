const std = @import("std");

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Stat = std.fs.File.Stat;
const GrokLLM = @import("LLMRequest.zig").GrokLLM;
// FileNode represents a file/directory in the tree
pub const FileNode = struct {
    // --- Metadata ---
    parent: ?*FileNode,
    children: std.ArrayList(*FileNode), // For directories
    path: []const u8, // Full filesystem path

    // --- Content ---
    content: ?[]u8, // Loaded file content (null = unloaded)
    content_allocator: Allocator, // Allocator for `content`

    pub fn init(
        allocator: Allocator,
        parent: ?*FileNode,
        path: []const u8,
        content_allocator: Allocator,
    ) !*FileNode {
        const self = try allocator.create(FileNode);
        self.* = .{
            .parent = parent,
            .children = std.ArrayList(*FileNode).init(allocator),
            .path = try allocator.dupe(u8, path), // Owned copy of path
            .content = null,
            .content_allocator = content_allocator,
        };
        return self;
    }

    pub fn deinit(self: *FileNode) void {
        // Free content if loaded
        if (self.content) |bytes| {
            self.content_allocator.free(bytes);
        }
        self.content_allocator.free(self.path);
        self.children.deinit();
        self.content_allocator.destroy(self);
    }
    pub fn invoke(self: *FileNode, input: []const u8) ![]const u8 {
        var grok = try GrokLLM.init(self.content_allocator);
        const response = try grok.call(input);
        defer grok.deinit();
        return response;
    }

    // Inside FileNode:
    pub fn loadContent(self: *FileNode) !void {
        if (self.content != null) return; // Already loaded

        const file = try std.fs.openFileAbsolute(self.path, .{});
        defer file.close();

        // Read entire file into memory
        self.content = try file.readToEndAlloc(
            self.content_allocator,
            std.math.maxInt(usize),
        );
    }

    pub fn unloadContent(self: *FileNode) void {
        if (self.content) |bytes| {
            self.content_allocator.free(bytes);
            self.content = null;
        }
    }

    pub fn reloadContent(self: *FileNode) !void {
        self.unloadContent();
        try self.loadContent();
    }
};
