const std = @import("std");
const Types = @import("Types.zig");

pub const Serializer = struct {
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
