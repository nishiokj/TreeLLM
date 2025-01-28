const std = import("std");
const FileTree = import("FileTree.zig").FileTree;
const FileNode = import("FileNode.zig");
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

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};

    const fileTree = try FileTree.init("/src", allocator,allocator );
    defer fileTree.deinit();
    const root = fileTree.root:
    try root.children.append(structuresFolder);
    const structuresFolder = try FileNode.init(allocator, root,"/src/structures",allocator);
    
    const FN = try FileNode.init(allocator,structuresFolder, path1, allocator);
    const FT = try FileNode.init(allocator,structuresFolder, path2, allocator);

    const mn = try FileNode.init(allocator,root,path4, allocator);
    const rm = try FileNode.init(allocator,root,path3,allocator);
    try root.children.append(structuresFolder);
    try structuresFolder.children.append(FT);
    try structuresFolder.children.append(FN);
    try root.children.append(mn);
    try root.children.append(rm);

    try rm.Invoke("Create a struct in zig capable of acting as a Unix based socket server. The server will have a thread for I/O and will read in bytes from lua where there is a delimiter '/00' separating the first piece of data (file path) from the second (file content). Using this it will attempt to add this to an existing FileTree. ");
    
}

pub fn buildTree() !void {

}
