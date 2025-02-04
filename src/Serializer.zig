const std = @import("std");
const Types = @import("Types.zig");
pub const Error = error{
    InvalidFormat,
};

pub const Query = struct {
    prompt: []const u8,

    context: []const u8,
};
pub const Serializer = struct {
    pub fn formatBuffer(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        // Split the input into tokens by "%" delimiter.
        // We expect an even number of tokens: a key followed by its value.
        var tokens = std.mem.splitAny(u8, input, "%");
        const first = tokens.first();

        // Default empty values.
        var prompt: []const u8 = "";
        var context: []const u8 = "";
        prompt = first;
        context = tokens.next().?;
        // We now build our formatted output.
        // We use an ArrayList(u8) as a simple string builder.
        var builder = std.ArrayList(u8).init(allocator);

        // Append PROMPT
        try builder.appendSlice("##PROMPT##:\n  ");
        try builder.appendSlice(prompt);
        try builder.appendSlice("\n\n");

        // Append CONTEXT
        try builder.appendSlice("##CONTEXT##:\n");
        // Here we assume that individual file entries are separated by a semicolon.
        var contextEntries = std.mem.splitAny(u8, context, "$$$");
        while (contextEntries.next()) |iter| {
            const trimmedEntry = std.mem.trim(u8, iter, " ");
            if (trimmedEntry.len == 0) continue; // skip empty entries

            // Each file entry is expected to be comma-separated.
            const parts = std.mem.splitAny(u8, trimmedEntry, "$$");

            var filename: []const u8 = "";
            //    var file_type: []const u8 = "";
            //    var functions: []const u8 = "";

            // The first part is expected to contain the file name,
            // possibly in the form "file: src/main.zig"
            var _items = parts.first().items;
            const firstPart = std.mem.trim(u8, _items, " ");
            _ = _items;
            if (std.mem.indexOf(u8, firstPart, "$")) |pos| {
                filename = std.mem.trim(u8, firstPart[pos + 1 ..], " ");
            } else {
                filename = firstPart;
            }

            // Look for other attributes.
            // for (std.math.range(1, parts.len)) |i| {
            //    const part = std.mem.trim(u8, parts[i], " ");
            //    if (std.mem.startsWith(u8, part, "type:")) {
            //       file_type = std.mem.trim(u8, part[5..], " ");
            //    } else if (std.mem.startsWith(u8, part, "functions:")) {
            //        functions = std.mem.trim(u8, part[10..], " ");
            //   }
            //  }

            // Append file info with sub-indentation.
            try builder.appendSlice("  ");
            try builder.appendSlice(filename);
            try builder.appendSlice("\n");
            //      if (file_type.len > 0) {
            //        try builder.appendSlice("    type: ");
            //      try builder.appendSlice(file_type);
            //    try builder.appendSlice("\n");
            //   }
            // if (functions.len > 0) {
            //   try builder.appendSlice("    functions: ");
            // try builder.appendSlice(functions);
            //    try builder.appendSlice("\n");
            //  }
        }

        //   try builder.appendSlice("\n##CONSTRAINTS##:\n  ");
        //    try builder.appendSlice(constraints);
        //   try builder.appendSlice("\n");

        // Return the completed formatted string.
        return builder.toOwnedSlice();
    }

    pub fn serializeContent(allocator: std.mem.Allocator, content: Types.Content) ![]u8 {
        // Build a JSON object for content:
        var builder = std.ArrayList(u8).init(allocator);
        try builder.appendSlice("{\"type\": \"");
        try builder.appendSlice(content.type);
        try builder.appendSlice("\", \"text\": \"");
        try builder.appendSlice(content.text);
        try builder.appendSlice("\"}");
        return builder.toOwnedSlice();
    }

    pub fn serializeCOTMessage(allocator: std.mem.Allocator, msg: Types.COTMessage) ![]u8 {
        // Build a JSON object for a single message:
        var builder = std.ArrayList(u8).init(allocator);
        try builder.appendSlice("{\"role\": \"");
        try builder.appendSlice(msg.role);
        try builder.appendSlice("\", \"content\": [");
        const contents = msg.content.items[0..msg.content.items.len];
        var first = true;
        for (contents) |content| {
            if (!first) {
                try builder.appendSlice(", ");
            }
            first = false;
            const contentStr = try serializeContent(allocator, content);
            try builder.appendSlice(contentStr);
            allocator.free(contentStr);
        }
        try builder.appendSlice("]}");
        return builder.toOwnedSlice();
    }

    pub fn serializeCOT(allocator: std.mem.Allocator, payload: Types.COTCompletionPayload) ![]u8 {
        // Build a JSON object for the payload.
        var builder = std.ArrayList(u8).init(allocator);
        try builder.appendSlice("{\"model\": \"");
        try builder.appendSlice(payload.model);
        try builder.appendSlice("\", \"messages\": [");

        var first = true;
        // Iterate over the messages stored in the ArrayList.
        const messages = payload.messages.items[0..payload.messages.items.len];
        for (messages) |msg| {
            if (!first) {
                try builder.appendSlice(", ");
            }
            first = false;
            const msgStr = try serializeCOTMessage(allocator, msg);
            try builder.appendSlice(msgStr);
            allocator.free(msgStr);
        }
        try builder.appendSlice("]}");
        return builder.toOwnedSlice();
    }
};
