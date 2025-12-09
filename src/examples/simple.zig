//! Simple Counter Example
//!
//! Demonstrates the minimal gooey.run() API with:
//! - Plain struct state
//! - Button click handling
//! - Components

const std = @import("std");
const gooey = @import("gooey");
const ui = gooey.ui;

// =============================================================================
// Application State - just a plain struct!
// =============================================================================

var state = struct {
    count: i32 = 0,
    message: []const u8 = "Click the buttons!",
}{};

// =============================================================================
// Components
// =============================================================================

const Counter = struct {
    // Buffer for formatting the count (static so it persists)
    var count_buf: [32]u8 = undefined;

    pub fn render(_: @This(), b: *ui.Builder) void {
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{state.count}) catch "?";

        b.vstack(.{ .gap = 8, .alignment = .center }, .{
            ui.text("Count:", .{ .size = 16, .color = ui.Color.rgb(0.3, 0.3, 0.3) }),
            ui.text(count_str, .{ .size = 48 }),
        });
    }
};

const ButtonRow = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        b.hstack(.{ .gap = 12 }, .{
            ui.button("- Decrease", decrement),
            ui.button("+ Increase", increment),
        });
    }
};

const Card = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        b.box(.{
            .padding = .{ .all = 32 },
            .gap = 20,
            .background = ui.Color.white,
            .corner_radius = 12,
            .alignment = .{ .main = .center, .cross = .center },
            .direction = .column,
        }, .{
            ui.text(state.message, .{ .size = 14, .color = ui.Color.rgb(0.5, 0.5, 0.5) }),
            Counter{},
            ButtonRow{},
            ui.button("Reset", reset),
        });
    }
};

// =============================================================================
// Entry Point
// =============================================================================

pub fn main() !void {
    try gooey.run(.{
        .title = "Simple Counter",
        .width = 400,
        .height = 300,
        .render = render,
        .on_event = onEvent,
    });
}

// =============================================================================
// Render Function
// =============================================================================

fn render(g: *gooey.UI) void {
    const size = g.windowSize();

    g.boxWithId("root", .{
        .width = size.width,
        .height = size.height,
        .alignment = .{ .main = .center, .cross = .center },
    }, .{
        Card{},
    });
}

// =============================================================================
// Event Handlers
// =============================================================================

fn increment() void {
    state.count += 1;
    state.message = "Incremented!";
}

fn decrement() void {
    state.count -= 1;
    state.message = "Decremented!";
}

fn reset() void {
    state.count = 0;
    state.message = "Reset to zero!";
}

fn onEvent(_: *gooey.UI, event: gooey.InputEvent) bool {
    if (event == .key_down) {
        const key = event.key_down.key;
        if (key == .escape) {
            return true;
        }
    }
    return false;
}
