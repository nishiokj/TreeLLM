const std = @import("std");
const FileNode = @import("FileNode.zig").FileNode;
const Allocator = std.mem.Allocator;

pub fn main() !void {

    //build tree
    //give tree the node to build context from
    //read contexts into memory and allocate
    //aggregate contexts into structured form
    //send to LLM
    //in production we will try recognizing the folder structure and retrieving it
    //
    //
    const path1 = "src/structures/FileNode.zig";
    const path2 = "src/structures/FileTree.zig";
    const path3 = "src/readme.md";
    const path4 = "src/main.zig";
    const path5 = "src/server.zig";

    const allocator = std.heap.page_allocator;

    //   const fileTree = try FileTree.init("/src", allocator, allocator);
    //    defer fileTree.deinit();
    //  const root = fileTree.root;
    const root = try FileNode.init(allocator, null, "/src", allocator);
    const FN = try FileNode.init(allocator, root, path1, allocator);
    const FT = try FileNode.init(allocator, root, path2, allocator);

    const mn = try FileNode.init(allocator, root, path4, allocator);
    const rm = try FileNode.init(allocator, root, path3, allocator);
    const serv = try FileNode.init(allocator, root, path5, allocator);
    defer root.deinit();
    try root.children.append(FT);
    try root.children.append(FN);
    try root.children.append(mn);
    try root.children.append(rm);
    try root.children.append(serv);

    const response = try serv.invoke("Create a struct in zig capable of acting as a Unix based socket server. The server will have a thread for I/O and will read in bytes from lua where there is a delimiter '/00' separating the first piece of data (file path) from the second (file content). Using this it will attempt to add this to an existing FileTree. ");
    std.debug.print("{s}", .{response});
}
