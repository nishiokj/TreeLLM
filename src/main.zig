const std = @import("std");
const FileNode = @import("FileNode.zig").FileNode;
const Allocator = std.mem.Allocator;
const FileTree = @import("FileTree.zig").FileTree;
pub fn main() !void {

    //build tree
    //give tree the node to build context from
    //read contexts into memory and allocate
    //aggregate contexts into structured form
    //send to LLM
    //in production we will try recognizing the folder structure and retrieving it
    //
    //
    const path1 = "src/FileNode.zig";
    const path2 = "src/FileTree.zig";
    const path3 = "src/Server.zig";
    const path4 = "src/main.zig";
    const path5 = "src/Types.zig";

    const allocator = std.heap.page_allocator;

    //   const fileTree = try FileTree.init("/src", allocator, allocator);
    //    defer fileTree.deinit();
    //  const root = fileTree.root;
    const root = try FileNode.init(allocator, null, "/src", 1);
    const FN = try FileNode.init(allocator, root, path1, 0);
    const FT = try FileNode.init(allocator, root, path2, 0);

    const mn = try FileNode.init(allocator, root, path4, 0);
    const serv = try FileNode.init(allocator, root, path3, 0);
    const types = try FileNode.init(allocator, root, path5, 0);
    FN.parent = root;
    FT.parent = root;
    serv.parent = root;
    const tree = try FileTree.init(allocator);
    defer tree.deinit();
    tree.root = root;
    try root.children.append(FT);
    try root.children.append(FN);
    try root.children.append(mn);
    try root.children.append(types);
    try root.children.append(serv);
    defer root.deinit();
    defer FN.deinit();
    defer FT.deinit();
    defer mn.deinit();
    defer serv.deinit();
    defer types.deinit();
    try tree.completion(serv, "Write framework for a server struct in zig (Under 300 tokens). Do not respond with words, simply write the code neatly. Zig version 0.14. Instructions ###  Server is designed to be a multithreaded socket server that listens on a posix socket, converts bytes into string args in the format: file % request %", "o1-mini");
}
