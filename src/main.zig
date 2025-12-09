//! Gooey Demo - Login Form with Component System

const std = @import("std");
const gooey = @import("gooey");
const ui = gooey.ui;

// Layout types
const layout = gooey.layout;
const LayoutEngine = layout.LayoutEngine;
const LayoutId = layout.LayoutId;

// Core types
const Scene = gooey.Scene;
const Hsla = gooey.Hsla;
const Quad = gooey.Quad;
const Shadow = gooey.Shadow;
const TextInput = gooey.TextInput;
const InputEvent = gooey.InputEvent;
const Window = gooey.Window;
const Gooey = gooey.Gooey;

// =============================================================================
// Application State
// =============================================================================

const AppState = struct {
    login_attempts: u32 = 0,
    is_submitting: bool = false,
    error_message: ?[]const u8 = null,
    focused_field: FocusedField = .username,

    const FocusedField = enum {
        none,
        username,
        password,
    };

    pub fn focusNext(self: *AppState) void {
        self.focused_field = switch (self.focused_field) {
            .none, .password => .username,
            .username => .password,
        };
    }

    pub fn submit(self: *AppState, username: []const u8, password: []const u8) void {
        self.login_attempts += 1;
        self.is_submitting = true;

        if (username.len == 0) {
            self.error_message = "Username is required";
            self.is_submitting = false;
        } else if (password.len == 0) {
            self.error_message = "Password is required";
            self.is_submitting = false;
        } else {
            self.error_message = null;
            std.debug.print("Login attempt #{}: user={s}\n", .{ self.login_attempts, username });
            self.is_submitting = false;
        }
    }

    pub fn reset(self: *AppState) void {
        self.error_message = null;
        self.focused_field = .username;
    }
};

// =============================================================================
// UI Components
// =============================================================================

/// Header text component
const Header = struct {
    title: []const u8,
    subtitle: ?[]const u8 = null,

    pub fn render(self: @This(), b: *ui.Builder) void {
        b.vstack(.{ .gap = 4 }, .{
            ui.text(self.title, .{ .size = 24, .color = ui.Color.rgb(0.1, 0.1, 0.1) }),
        });
        // Render subtitle conditionally
        if (self.subtitle) |sub| {
            b.box(.{}, .{
                ui.text(sub, .{ .size = 14, .color = ui.Color.rgb(0.5, 0.5, 0.5) }),
            });
        }
    }
};

/// Error message banner
const ErrorBanner = struct {
    message: []const u8,

    pub fn render(self: @This(), b: *ui.Builder) void {
        b.box(.{
            .padding = .{ .symmetric = .{ .x = 12, .y = 8 } },
            .background = ui.Color.rgb(1.0, 0.9, 0.9),
            .corner_radius = 4,
        }, .{
            ui.text(self.message, .{ .color = ui.Color.rgb(0.8, 0.2, 0.2) }),
        });
    }
};

/// A styled button
const Button = struct {
    label: []const u8,
    style: Style = .primary,
    enabled: bool = true,

    const Style = enum { primary, secondary };

    pub fn render(self: @This(), b: *ui.Builder) void {
        const bg = switch (self.style) {
            .primary => if (self.enabled)
                ui.Color.rgb(0.2, 0.5, 1.0)
            else
                ui.Color.rgb(0.5, 0.7, 1.0),
            .secondary => ui.Color.rgb(0.9, 0.9, 0.9),
        };
        const fg = switch (self.style) {
            .primary => ui.Color.white,
            .secondary => ui.Color.rgb(0.3, 0.3, 0.3),
        };

        b.box(.{
            .padding = .{ .symmetric = .{ .x = 24, .y = 10 } },
            .background = bg,
            .corner_radius = 6,
            .alignment = .{ .main = .center, .cross = .center },
        }, .{
            ui.text(self.label, .{ .color = fg }),
        });
    }
};

/// Input field placeholder
const InputPlaceholder = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        b.box(.{
            .grow = true,
            .height = 36,
        }, .{});
    }
};

/// The complete login form
const LoginForm = struct {
    state: *const AppState,

    pub fn render(self: @This(), b: *ui.Builder) void {
        const s = self.state;

        // Card container
        b.box(.{
            .width = 400,
            .padding = .{ .all = 24 },
            .gap = 16,
            .background = ui.Color.white,
            .corner_radius = 12,
            .alignment = .{ .main = .start, .cross = .center },
        }, .{
            // Header
            Header{
                .title = "Login",
                .subtitle = if (s.login_attempts > 0) "Welcome back!" else null,
            },

            // Username placeholder
            InputPlaceholder{},

            // Password placeholder
            InputPlaceholder{},

            // Button row
            ButtonRow{ .is_submitting = s.is_submitting },
        });

        // Error banner (rendered after card, but we'll fix positioning later)
        // For now this is a limitation - conditionals in tuples need work
    }
};

/// Button row component
const ButtonRow = struct {
    is_submitting: bool,

    pub fn render(self: @This(), b: *ui.Builder) void {
        b.hstack(.{ .gap = 12 }, .{
            Button{ .label = "Cancel", .style = .secondary },
            Button{
                .label = if (self.is_submitting) "Signing in..." else "Sign In",
                .style = .primary,
                .enabled = !self.is_submitting,
            },
        });
    }
};

/// Footer hint text
const Footer = struct {
    pub fn render(_: @This(), b: *ui.Builder) void {
        b.box(.{ .padding = .{ .all = 20 } }, .{
            ui.text("Tab: switch | Enter: submit | Esc: reset", .{
                .size = 12,
                .color = ui.Color.rgb(0.5, 0.5, 0.5),
            }),
        });
    }
};

// =============================================================================
// Global State
// =============================================================================

var g_state: AppState = .{};
var g_ui: *Gooey = undefined;
var g_builder: ?ui.Builder = null;
var g_building: bool = false;

// =============================================================================
// Main
// =============================================================================

pub fn main() !void {
    std.debug.print("Starting Gooey - Component-based Login Form\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize platform
    var plat = try gooey.MacPlatform.init();
    defer plat.deinit();

    // Create window
    var window = try Window.init(allocator, &plat, .{
        .title = "Gooey - Login Form",
        .width = 800,
        .height = 600,
        .background_color = gooey.geometry.Color.init(0.95, 0.95, 0.95, 1.0),
    });
    defer window.deinit();

    // Initialize text system
    var text_system = try gooey.TextSystem.initWithScale(allocator, @floatCast(window.scale_factor));
    defer text_system.deinit();
    try text_system.loadFont("Menlo", 16.0);

    // Initialize layout engine
    var layout_engine = LayoutEngine.init(allocator);
    defer layout_engine.deinit();
    layout_engine.setMeasureTextFn(measureTextCallback, &text_system);

    // Create scene
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // Initialize Gooey context
    var gooey_ctx = Gooey.init(allocator, window, &layout_engine, &scene, &text_system);
    defer gooey_ctx.deinit();
    g_ui = &gooey_ctx;

    // Initialize UI Builder
    g_builder = ui.Builder.init(allocator, &layout_engine, &scene);

    // Setup text inputs
    const username_input = gooey_ctx.textInput("username");
    username_input.setPlaceholder("Username");

    const password_input = gooey_ctx.textInput("password");
    password_input.setPlaceholder("Password");

    // Initial focus
    gooey_ctx.focusTextInput("username");

    // Set callbacks
    window.setInputCallback(onInput);
    window.setRenderCallback(onRender);
    window.setTextAtlas(text_system.getAtlas());
    window.setScene(&scene);

    std.debug.print("Ready! Tab: switch fields | Enter: submit | Esc: reset\n", .{});

    plat.run();
}

// =============================================================================
// Input Handler
// =============================================================================

fn onInput(window: *Window, event: InputEvent) bool {
    const gooey_ctx = g_ui;

    switch (event) {
        .key_down => |key| {
            if (key.key == .tab) {
                g_state.focusNext();
                syncFocus(gooey_ctx);
                window.requestRender();
                return true;
            }

            if (key.key == .@"return") {
                const username = gooey_ctx.textInput("username").getText();
                const password = gooey_ctx.textInput("password").getText();
                g_state.submit(username, password);
                window.requestRender();
                return true;
            }

            if (key.key == .escape) {
                g_state.reset();
                gooey_ctx.textInput("username").clear();
                gooey_ctx.textInput("password").clear();
                syncFocus(gooey_ctx);
                window.requestRender();
                return true;
            }

            return dispatchToTextInput(gooey_ctx, event);
        },
        .text_input => return dispatchToTextInput(gooey_ctx, event),
        .mouse_down => return false,
        else => return false,
    }
}

fn syncFocus(gooey_ctx: *Gooey) void {
    switch (g_state.focused_field) {
        .username => gooey_ctx.focusTextInput("username"),
        .password => gooey_ctx.focusTextInput("password"),
        .none => gooey_ctx.widgets.blurAll(),
    }
}

fn dispatchToTextInput(gooey_ctx: *Gooey, event: InputEvent) bool {
    if (gooey_ctx.getFocusedTextInput()) |input| {
        switch (event) {
            .key_down => |k| {
                input.handleKey(k) catch {};
                return true;
            },
            .text_input => |t| {
                input.insertText(t.text) catch {};
                return true;
            },
            .composition => |c| {
                input.setComposition(c.text) catch {};
                return true;
            },
            else => return false,
        }
    }
    return false;
}

// =============================================================================
// Render
// =============================================================================

fn onRender(window: *Window) void {
    _ = window;
    if (g_building) return;
    g_building = true;
    defer g_building = false;

    buildScene(g_ui, &g_state) catch |err| {
        std.debug.print("Build error: {}\n", .{err});
    };
}

fn buildScene(gooey_ctx: *Gooey, state: *const AppState) !void {
    gooey_ctx.beginFrame();

    const width: f32 = @floatFromInt(gooey_ctx.window.width());
    const height: f32 = @floatFromInt(gooey_ctx.window.height());

    var b = &g_builder.?;
    b.id_counter = 0;

    // Root container - centers everything
    b.boxWithId("root", .{
        .width = width,
        .height = height,
        .alignment = .{ .main = .center, .cross = .center },
        .direction = .column,
        .gap = 0,
    }, .{
        LoginForm{ .state = state },
        Footer{},
    });

    const commands = try gooey_ctx.endFrame();

    gooey_ctx.scene.clear();

    // Draw card shadow
    for (commands) |cmd| {
        if (cmd.command_type == .rectangle) {
            const rect = cmd.data.rectangle;
            if (rect.corner_radius.top_left >= 12 and cmd.bounding_box.width >= 300) {
                try gooey_ctx.scene.insertShadow(Shadow.drop(
                    cmd.bounding_box.x,
                    cmd.bounding_box.y,
                    cmd.bounding_box.width,
                    cmd.bounding_box.height,
                    15,
                ).withCornerRadius(12).withColor(Hsla.init(0, 0, 0, 0.12)));
                break;
            }
        }
    }

    // Render layout commands
    for (commands) |cmd| {
        try renderCommand(gooey_ctx, cmd);
    }

    // Render text inputs (find the placeholder boxes)
    var input_index: u32 = 0;
    for (commands) |cmd| {
        if (cmd.command_type == .rectangle) {
            // Look for our placeholder boxes (36px height, no background)
            if (cmd.bounding_box.height == 36 and cmd.data.rectangle.background_color.a == 0) {
                const input_id = if (input_index == 0) "username" else "password";
                const input_widget = gooey_ctx.textInput(input_id);
                input_widget.bounds = .{
                    .x = cmd.bounding_box.x,
                    .y = cmd.bounding_box.y,
                    .width = cmd.bounding_box.width,
                    .height = cmd.bounding_box.height,
                };
                try input_widget.render(gooey_ctx.scene, gooey_ctx.text_system, gooey_ctx.scale_factor);
                input_index += 1;
                if (input_index >= 2) break;
            }
        }
    }

    gooey_ctx.scene.finish();
}

// =============================================================================
// Render Helpers
// =============================================================================

fn renderCommand(gooey_ctx: *Gooey, cmd: layout.RenderCommand) !void {
    switch (cmd.command_type) {
        .rectangle => {
            const rect = cmd.data.rectangle;
            try gooey_ctx.scene.insertQuad(Quad{
                .bounds_origin_x = cmd.bounding_box.x,
                .bounds_origin_y = cmd.bounding_box.y,
                .bounds_size_width = cmd.bounding_box.width,
                .bounds_size_height = cmd.bounding_box.height,
                .background = layout.colorToHsla(rect.background_color),
                .corner_radii = .{
                    .top_left = rect.corner_radius.top_left,
                    .top_right = rect.corner_radius.top_right,
                    .bottom_left = rect.corner_radius.bottom_left,
                    .bottom_right = rect.corner_radius.bottom_right,
                },
            });
        },
        .text => {
            const text_data = cmd.data.text;
            const baseline_y = cmd.bounding_box.y + cmd.bounding_box.height * 0.75;
            try renderText(
                gooey_ctx.scene,
                gooey_ctx.text_system,
                text_data.text,
                cmd.bounding_box.x,
                baseline_y,
                gooey_ctx.scale_factor,
                layout.colorToHsla(text_data.color),
            );
        },
        else => {},
    }
}

fn renderText(scene: *Scene, text_system: *gooey.TextSystem, text_content: []const u8, x: f32, baseline_y: f32, scale_factor: f32, color: Hsla) !void {
    var shaped = try text_system.shapeText(text_content);
    defer shaped.deinit(text_system.allocator);

    var pen_x = x;
    for (shaped.glyphs) |glyph_info| {
        const cached = try text_system.getGlyph(glyph_info.glyph_id);
        if (cached.region.width > 0 and cached.region.height > 0) {
            const atlas = text_system.getAtlas();
            const uv_coords = cached.region.uv(atlas.size);
            try scene.insertGlyph(gooey.GlyphInstance.init(
                pen_x + glyph_info.x_offset + cached.bearing_x,
                baseline_y + glyph_info.y_offset - cached.bearing_y,
                @as(f32, @floatFromInt(cached.region.width)) / scale_factor,
                cached.height,
                uv_coords.u0,
                uv_coords.v0,
                uv_coords.u1,
                uv_coords.v1,
                color,
            ));
        }
        pen_x += glyph_info.x_advance;
    }
}

fn measureTextCallback(text_content: []const u8, _: u16, _: u16, _: ?f32, user_data: ?*anyopaque) layout.engine.TextMeasurement {
    if (user_data) |ptr| {
        const ts: *gooey.TextSystem = @ptrCast(@alignCast(ptr));
        const text_width = ts.measureText(text_content) catch 0;
        const metrics = ts.getMetrics();
        return .{
            .width = text_width,
            .height = if (metrics) |m| m.line_height else 20,
        };
    }
    return .{ .width = @as(f32, @floatFromInt(text_content.len)) * 10, .height = 20 };
}
