//! Login Form Example
//!
//! Demonstrates input binding with:
//! - Two-way bound text inputs
//! - Form validation
//! - Formatted text display

const std = @import("std");
const gooey = @import("gooey");
const ui = gooey.ui;

// =============================================================================
// Application State
// =============================================================================

var state = struct {
    // Declarations must come before fields
    const Field = enum { username, password };

    pub fn focusNext(self: *@This()) void {
        self.focused = switch (self.focused) {
            .username => .password,
            .password => .username,
        };
    }

    // Fields come after declarations
    username: []const u8 = "",
    password: []const u8 = "",
    message: []const u8 = "Enter your credentials",
    submitted: bool = false,
    focused: Field = .username,
    initialized: bool = false,
}{};

// =============================================================================
// Entry Point
// =============================================================================

pub fn main() !void {
    try gooey.run(.{
        .title = "Login Form",
        .width = 400,
        .height = 350,
        .render = render,
        .on_event = onEvent,
    });
}

fn onEvent(g: *gooey.UI, event: gooey.InputEvent) bool {
    if (event == .key_down and event.key_down.key == .tab) {
        state.focusNext();
        // Sync focus to the actual TextInput widget
        switch (state.focused) {
            .username => g.focusTextInput("username"),
            .password => g.focusTextInput("password"),
        }
        return true;
    }
    return false;
}

// =============================================================================
// Components
// =============================================================================

/// Greeting component - shows personalized message when username is entered
const Greeting = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        if (state.username.len > 0) {
            b.box(.{}, .{
                ui.textFmt("Hello, {s}!", .{state.username}, .{ .size = 14 }),
            });
        }
    }
};

/// Login card component
const LoginCard = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        b.box(.{
            .padding = .{ .all = 32 },
            .gap = 16,
            .background = ui.Color.white,
            .corner_radius = 12,
            .direction = .column,
            .alignment = .{ .main = .center, .cross = .center },
        }, .{
            ui.text("Login", .{ .size = 24, .color = ui.Color.rgb(0.2, 0.2, 0.2) }),
            ui.text(state.message, .{ .size = 12, .color = ui.Color.rgb(0.5, 0.5, 0.5) }),
            ui.input("username", .{
                .placeholder = "Username",
                .width = 250,
                .bind = &state.username,
            }),
            ui.input("password", .{
                .placeholder = "Password",
                .secure = true,
                .width = 250,
                .bind = &state.password,
            }),
            Greeting{},
            ui.button("Sign In", submit),
        });
    }
};

// =============================================================================
// Render
// =============================================================================

fn render(g: *gooey.UI) void {
    if (!state.initialized) {
        state.initialized = true;
        g.focusTextInput("username");
    }

    const size = g.windowSize();

    g.box(.{
        .width = size.width,
        .height = size.height,
        .alignment = .{ .main = .center, .cross = .center },
    }, .{
        LoginCard{},
    });
}

fn submit() void {
    if (state.username.len == 0) {
        state.message = "Please enter a username";
    } else if (state.password.len == 0) {
        state.message = "Please enter a password";
    } else {
        state.message = "Login successful!";
        state.submitted = true;
    }
}
