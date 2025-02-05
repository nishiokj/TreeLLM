const std = @import("std");
const Types = @import("Types.zig");
pub const Error = error{
    InvalidFormat,
};

pub const Query = struct {
    prompt: []const u8,

    context: []const u8,
};
pub const BuildError = error{
    InvalidInput,
};
pub const ParseError = error{
    MissingPrompt,
    MissingContext,
    MissingFilePath,
};
pub const Serializer = struct {
    // Helper: Append a slice with JSON escaping.
    fn appendEscaped(builder: *std.ArrayList(u8), slice: []const u8) !void {
        const hexChars = "0123456789ABCDEF";
        for (slice) |c| {
            // Replace newline with a space.
            if (c == '\n') {
                try builder.appendSlice(" ");
            } else if (c == '"') {
                // Escape a double quote.
                try builder.appendSlice("\\\"");
            } else if (c == '\\') {
                // Escape a backslash.
                try builder.appendSlice("\\\\");
            } else if (c < 0x20) {
                // For other control characters, output a Unicode escape.
                var buffer: [6]u8 = undefined;
                buffer[0] = '\\';
                buffer[1] = 'u';
                buffer[2] = '0';
                buffer[3] = '0';
                buffer[4] = hexChars[(c >> 4) & 0xF];
                buffer[5] = hexChars[c & 0xF];
                try builder.appendSlice(buffer[0..6]);
            } else {
                try builder.append(c);
            }
        }
    }

    pub fn buildFormattedString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var builder = std.ArrayList(u8).init(allocator);

        // Trim overall input.
        const trimmed_input = std.mem.trim(u8, input, " ");

        // Split the input on "%%%" delimiter.
        var tokens = std.mem.splitSequence(u8, trimmed_input, "%%%");

        // Skip empty tokens to get the prompt.
        var prompt: []const u8 = "";
        while (true) {
            const token = tokens.next() orelse break;
            if (!std.mem.eql(u8, token, "")) {
                prompt = token;
                break;
            }
        }
        if (prompt.len == 0) return ParseError.MissingPrompt;

        // The next token should be the context.
        const context_token = tokens.next() orelse return ParseError.MissingContext;

        // Now split the context using "$$" delimiter.
        var ctxParts = std.mem.splitSequence(u8, context_token, "$$");
        // The first part is the main context text.
        var mainContext: []const u8 = "";
        if (ctxParts.next()) |firstCtx| {
            mainContext = firstCtx;
        }

        // Append the formatted sections with escaped text.
        try builder.appendSlice("##PROMPT##");
        try appendEscaped(&builder, prompt);
        try builder.appendSlice("##CONTEXT##");
        try appendEscaped(&builder, mainContext);

        // For each remaining part in context, try to extract a file path.
        while (true) {
            const fileEntry = ctxParts.next();
            if (fileEntry) |entry| {
                // Look for the first "$" in the file entry.
                if (std.mem.indexOf(u8, entry, "$")) |delimPos| {
                    // The file path is the substring after the "$" delimiter.
                    const filePath = std.mem.trim(u8, entry[delimPos + 1 ..], " ");
                    if (filePath.len == 0)
                        return ParseError.MissingFilePath;
                    try builder.appendSlice("#FILE# ");
                    try appendEscaped(&builder, filePath);
                }
            } else break;
        }

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
