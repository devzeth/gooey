//! WidgetStore - Simple retained storage for stateful widgets
//!
//! Provides persistent widget instances across frames without the complexity
//! of the Entity system. Widgets are stored by string ID and created on first access.
//!
//! Example:
//! ```zig
//! var store = WidgetStore.init(allocator);
//! defer store.deinit();
//!
//! // Get or create a text input - same ID returns same instance
//! var username = store.textInput("username");
//! username.setPlaceholder("Enter username");
//! ```

const std = @import("std");
const TextInput = @import("../elements/text_input.zig").TextInput;
const Bounds = @import("../elements/text_input.zig").Bounds;

pub const WidgetStore = struct {
    allocator: std.mem.Allocator,
    text_inputs: std.StringHashMap(*TextInput),
    accessed_this_frame: std.StringHashMap(void),
    default_text_input_bounds: Bounds = .{ .x = 0, .y = 0, .width = 200, .height = 36 },

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .text_inputs = std.StringHashMap(*TextInput).init(allocator),
            .accessed_this_frame = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.text_inputs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.text_inputs.deinit();

        var acc_it = self.accessed_this_frame.keyIterator();
        while (acc_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.accessed_this_frame.deinit();
    }

    /// Get or create a TextInput by ID - persists across frames
    pub fn textInput(self: *Self, id: []const u8) *TextInput {
        if (!self.accessed_this_frame.contains(id)) {
            const owned_access_key = self.allocator.dupe(u8, id) catch return self.getOrCreateTextInput(id);
            self.accessed_this_frame.put(owned_access_key, {}) catch {};
        }
        return self.getOrCreateTextInput(id);
    }

    fn getOrCreateTextInput(self: *Self, id: []const u8) *TextInput {
        if (self.text_inputs.get(id)) |existing| {
            return existing;
        }

        const input = self.allocator.create(TextInput) catch @panic("Failed to allocate TextInput");
        input.* = TextInput.initWithId(self.allocator, self.default_text_input_bounds, id);

        const owned_key = self.allocator.dupe(u8, id) catch @panic("Failed to allocate key");
        self.text_inputs.put(owned_key, input) catch @panic("Failed to store TextInput");

        return input;
    }

    pub fn beginFrame(self: *Self) void {
        var it = self.accessed_this_frame.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.accessed_this_frame.clearRetainingCapacity();
    }

    pub fn endFrame(_: *Self) void {
        // No-op - widgets persist until explicitly removed
    }

    pub fn removeTextInput(self: *Self, id: []const u8) void {
        if (self.text_inputs.fetchRemove(id)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
            self.allocator.free(kv.key);
        }
    }

    pub fn getTextInput(self: *Self, id: []const u8) ?*TextInput {
        return self.text_inputs.get(id);
    }

    pub fn hasTextInput(self: *Self, id: []const u8) bool {
        return self.text_inputs.contains(id);
    }

    pub fn textInputCount(self: *Self) usize {
        return self.text_inputs.count();
    }

    pub fn getFocusedTextInput(self: *Self) ?*TextInput {
        var it = self.text_inputs.valueIterator();
        while (it.next()) |input| {
            if (input.*.isFocused()) {
                return input.*;
            }
        }
        return null;
    }

    pub fn focusTextInput(self: *Self, id: []const u8) void {
        if (self.getFocusedTextInput()) |current| {
            current.blur();
        }
        if (self.text_inputs.get(id)) |input| {
            input.focus();
        }
    }

    pub fn blurAll(self: *Self) void {
        var it = self.text_inputs.valueIterator();
        while (it.next()) |input| {
            input.*.blur();
        }
    }
};
