const std = @import("std");

pub const Content = struct { type: []const u8, text: []const u8 };
pub const COTMessage = struct { role: []const u8, content: *std.ArrayList(Content) };
pub const Message = struct { role: []const u8, content: []const u8 };
pub const CompletionPayload = struct { model: []const u8, messages: []Message };
pub const COTCompletionPayload = struct { model: []const u8, messages: *std.ArrayList(COTMessage) };
pub const Choice = struct { index: usize, message: struct { role: []const u8, content: []const u8, refusal: ?[]const u8 }, finish_reason: ?[]const u8 = null, logprobs: ?[]const u8 = null };

pub const Usage = struct {
    prompt_tokens: u64,
    completion_tokens: ?u64,
    total_tokens: u64,
};

pub const Completion = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    model: []const u8,
    choices: []Choice,
    // Usage is not returned by the Completion endpoint when streamed.
    system_fingerprint: ?[]const u8 = null,
};
