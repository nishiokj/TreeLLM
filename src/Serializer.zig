const std = @import("std");
const Types = @import("Types.zig");
pub const Error = error{
    InvalidFormat,
};
pub const Serializer = struct {
    pub fn formatBuffer(allocator: *std.mem.Allocator, input: []const u8) ![]u8 {
        // Split the input into tokens by "%" delimiter.
        // We expect an even number of tokens: a key followed by its value.
        const tokens = std.mem.split(input, "%").toSlice();
        if (tokens.len % 2 != 0) {
            return Error.InvalidFormat;
        }

        // Default empty values.
        var prompt: []const u8 = "";
        var system_prompt: []const u8 = "";
        var context: []const u8 = "";
        var constraints: []const u8 = "";

        // Process key/value pairs.
        for (std.math.range(0, tokens.len / 2)) |pair_index| {
            const key = std.mem.trim(u8, tokens[pair_index * 2], " ");
            const value = std.mem.trim(u8, tokens[pair_index * 2 + 1], " ");
            if (std.mem.eql(u8, key, "PROMPT")) {
                prompt = value;
            } else if (std.mem.eql(u8, key, "SYSTEM_PROMPT")) {
                system_prompt = value;
            } else if (std.mem.eql(u8, key, "CONTEXT")) {
                context = value;
            } else if (std.mem.eql(u8, key, "CONSTRAINTS")) {
                constraints = value;
            }
        }

        // We now build our formatted output.
        // We use an ArrayList(u8) as a simple string builder.
        var builder = std.ArrayList(u8).init(allocator);

        // Append PROMPT
        try builder.appendSlice("##PROMPT##:\n  ");
        try builder.appendSlice(prompt);
        try builder.appendSlice("\n\n");

        // Append SYSTEM_PROMPT
        try builder.appendSlice("##SYSTEM_PROMPT##:\n  ");
        try builder.appendSlice(system_prompt);
        try builder.appendSlice("\n\n");

        // Append CONTEXT
        try builder.appendSlice("##CONTEXT##:\n");
        // Here we assume that individual file entries are separated by a semicolon.
        const contextEntries = std.mem.split(context, ";").toSlice();
        for (contextEntries) |entry| {
            const trimmedEntry = std.mem.trim(u8, entry, " ");
            if (trimmedEntry.len == 0) continue; // skip empty entries

            // Each file entry is expected to be comma-separated.
            const parts = std.mem.split(trimmedEntry, ",").toSlice();

            var filename: []const u8 = "";
            var file_type: []const u8 = "";
            var functions: []const u8 = "";

            if (parts.len > 0) {
                // The first part is expected to contain the file name,
                // possibly in the form "file: src/main.zig"
                const firstPart = std.mem.trim(u8, parts[0], " ");

                if (std.mem.indexOf(u8, firstPart, ":")) |pos| {
                    // 'pos' is the index of the colon.
                    filename = std.mem.trim(u8, firstPart[pos + 1 ..], " ");
                } else {
                    filename = firstPart;
                }
            }

            // Look for other attributes.
            for (std.math.range(1, parts.len)) |i| {
                const part = std.mem.trim(u8, parts[i], " ");
                if (std.mem.startsWith(u8, part, "type:")) {
                    file_type = std.mem.trim(u8, part[5..], " ");
                } else if (std.mem.startsWith(u8, part, "functions:")) {
                    functions = std.mem.trim(u8, part[10..], " ");
                }
            }

            // Append file info with sub-indentation.
            try builder.appendSlice("  ");
            try builder.appendSlice(filename);
            try builder.appendSlice("\n");
            if (file_type.len > 0) {
                try builder.appendSlice("    type: ");
                try builder.appendSlice(file_type);
                try builder.appendSlice("\n");
            }
            if (functions.len > 0) {
                try builder.appendSlice("    functions: ");
                try builder.appendSlice(functions);
                try builder.appendSlice("\n");
            }
        }

        try builder.appendSlice("\n##CONSTRAINTS##:\n  ");
        try builder.appendSlice(constraints);
        try builder.appendSlice("\n");

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
