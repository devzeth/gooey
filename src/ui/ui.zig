//! UI Builder - Component-based declarative UI
//!
//! This module provides a clean, composable API for building UIs.
//! Components are structs with a `render` method. Children are tuples.
//!
//! Example:
//! ```zig
//! const ui = @import("ui");
//!
//! fn build(b: *ui.Builder) void {
//!     b.vstack(.{ .gap = 16 }, .{
//!         ui.text("Hello", .{ .size = 24 }),
//!         MyButton{ .label = "Click me" },
//!     });
//! }
//!
//! const MyButton = struct {
//!     label: []const u8,
//!
//!     pub fn render(self: @This(), b: *ui.Builder) void {
//!         b.box(.{ .padding = .{ .all = 12 }, .background = ui.Color.blue }, .{
//!             ui.text(self.label, .{ .color = ui.Color.white }),
//!         });
//!     }
//! };
//! ```

const std = @import("std");

// Import from gooey core
const layout_mod = @import("../layout/layout.zig");
const LayoutEngine = layout_mod.LayoutEngine;
const LayoutId = layout_mod.LayoutId;
const Sizing = layout_mod.Sizing;
const SizingAxis = layout_mod.SizingAxis;
const Padding = layout_mod.Padding;
const CornerRadius = layout_mod.CornerRadius;
const ChildAlignment = layout_mod.ChildAlignment;
const LayoutDirection = layout_mod.LayoutDirection;
const LayoutConfig = layout_mod.LayoutConfig;
const ElementDeclaration = layout_mod.ElementDeclaration;
const TextConfig = layout_mod.TextConfig;
const RenderCommand = layout_mod.RenderCommand;

const scene_mod = @import("../core/scene.zig");
const Scene = scene_mod.Scene;
const Hsla = scene_mod.Hsla;

// Re-export for convenience
pub const Color = @import("../layout/types.zig").Color;

// =============================================================================
// Style Types
// =============================================================================

/// Text styling options
pub const TextStyle = struct {
    size: u16 = 14,
    color: Color = Color.black,
    weight: Weight = .regular,
    italic: bool = false,

    pub const Weight = enum { thin, light, regular, medium, semibold, bold, black };
};

/// Box styling options
pub const BoxStyle = struct {
    // Sizing
    width: ?f32 = null,
    height: ?f32 = null,
    min_width: ?f32 = null,
    min_height: ?f32 = null,
    max_width: ?f32 = null,
    max_height: ?f32 = null,
    grow: bool = false,

    // Spacing
    padding: PaddingValue = .{ .all = 0 },
    gap: f32 = 0,

    // Appearance
    background: Color = Color.transparent,
    corner_radius: f32 = 0,
    border_color: Color = Color.transparent,
    border_width: f32 = 0,

    // Layout
    direction: Direction = .column,
    alignment: Alignment = .{ .main = .start, .cross = .start },

    pub const Direction = enum { row, column };

    pub const Alignment = struct {
        main: MainAxis = .start,
        cross: CrossAxis = .start,

        pub const MainAxis = enum { start, center, end, space_between, space_around };
        pub const CrossAxis = enum { start, center, end, stretch };
    };

    pub const PaddingValue = union(enum) {
        all: f32,
        symmetric: struct { x: f32, y: f32 },
        each: struct { top: f32, right: f32, bottom: f32, left: f32 },
    };

    /// Convert to layout Padding
    pub fn toPadding(self: BoxStyle) Padding {
        return switch (self.padding) {
            .all => |v| Padding.all(@intFromFloat(v)),
            .symmetric => |s| Padding.symmetric(@intFromFloat(s.x), @intFromFloat(s.y)),
            .each => |e| .{
                .top = @intFromFloat(e.top),
                .right = @intFromFloat(e.right),
                .bottom = @intFromFloat(e.bottom),
                .left = @intFromFloat(e.left),
            },
        };
    }
};

/// Input field options
pub const InputStyle = struct {
    placeholder: []const u8 = "",
    secure: bool = false,
    font_size: u16 = 14,
};

/// Stack layout options
pub const StackStyle = struct {
    gap: f32 = 0,
    alignment: Alignment = .start,
    padding: f32 = 0,

    pub const Alignment = enum { start, center, end, stretch };
};

/// Center container options
pub const CenterStyle = struct {
    padding: f32 = 0,
};

// =============================================================================
// Primitive Descriptors
// =============================================================================

pub const PrimitiveType = enum { text, input, spacer };

/// Text element descriptor
pub const Text = struct {
    content: []const u8,
    style: TextStyle,

    pub const primitive_type: PrimitiveType = .text;
};

/// Input field descriptor
pub const Input = struct {
    id: []const u8,
    bind: *[]const u8,
    style: InputStyle,

    pub const primitive_type: PrimitiveType = .input;
};

/// Spacer element descriptor
pub const Spacer = struct {
    min_size: f32 = 0,

    pub const primitive_type: PrimitiveType = .spacer;
};

// =============================================================================
// Free Functions (return descriptors)
// =============================================================================

/// Create a text element
pub fn text(content: []const u8, style: TextStyle) Text {
    return .{ .content = content, .style = style };
}

/// Create a text input element
pub fn input(id: []const u8, bind: *[]const u8, style: InputStyle) Input {
    return .{ .id = id, .bind = bind, .style = style };
}

/// Create a flexible spacer
pub fn spacer() Spacer {
    return .{};
}

/// Create a spacer with minimum size
pub fn spacerMin(min_size: f32) Spacer {
    return .{ .min_size = min_size };
}

// =============================================================================
// UI Builder
// =============================================================================

/// The UI builder context passed to component render() methods
pub const Builder = struct {
    allocator: std.mem.Allocator,
    layout: *LayoutEngine,
    scene: *Scene,
    id_counter: u32 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, layout_engine: *LayoutEngine, scene_ptr: *Scene) Self {
        return .{
            .allocator = allocator,
            .layout = layout_engine,
            .scene = scene_ptr,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    // =========================================================================
    // Container Methods
    // =========================================================================

    /// Generic box container with children
    pub fn box(self: *Self, style: BoxStyle, children: anytype) void {
        self.boxWithId(null, style, children);
    }

    /// Box with explicit ID
    pub fn boxWithId(self: *Self, id: ?[]const u8, style: BoxStyle, children: anytype) void {
        const layout_id = if (id) |i| LayoutId.fromString(i) else self.generateId();

        var sizing = Sizing.fitContent();

        if (style.width) |w| {
            sizing.width = SizingAxis.fixed(w);
        } else if (style.grow) {
            sizing.width = SizingAxis.grow();
        }

        if (style.height) |h| {
            sizing.height = SizingAxis.fixed(h);
        } else if (style.grow) {
            sizing.height = SizingAxis.grow();
        }

        const direction: LayoutDirection = switch (style.direction) {
            .row => .left_to_right,
            .column => .top_to_bottom,
        };

        const child_alignment = ChildAlignment{
            .x = switch (style.alignment.cross) {
                .start => .left,
                .center => .center,
                .end => .right,
                .stretch => .left,
            },
            .y = switch (style.alignment.main) {
                .start => .top,
                .center => .center,
                .end => .bottom,
                .space_between, .space_around => .top,
            },
        };

        self.layout.openElement(.{
            .id = layout_id,
            .layout = .{
                .sizing = sizing,
                .padding = style.toPadding(),
                .child_gap = @intFromFloat(style.gap),
                .child_alignment = child_alignment,
                .layout_direction = direction,
            },
            .background_color = style.background,
            .corner_radius = CornerRadius.all(style.corner_radius),
        }) catch return;

        self.processChildren(children);

        self.layout.closeElement();
    }

    /// Vertical stack (column)
    pub fn vstack(self: *Self, style: StackStyle, children: anytype) void {
        self.box(.{
            .direction = .column,
            .gap = style.gap,
            .padding = .{ .all = style.padding },
            .alignment = .{
                .cross = switch (style.alignment) {
                    .start => .start,
                    .center => .center,
                    .end => .end,
                    .stretch => .stretch,
                },
                .main = .start,
            },
        }, children);
    }

    /// Horizontal stack (row)
    pub fn hstack(self: *Self, style: StackStyle, children: anytype) void {
        self.box(.{
            .direction = .row,
            .gap = style.gap,
            .padding = .{ .all = style.padding },
            .alignment = .{
                .cross = switch (style.alignment) {
                    .start => .start,
                    .center => .center,
                    .end => .end,
                    .stretch => .stretch,
                },
                .main = .start,
            },
        }, children);
    }

    /// Center children in available space
    pub fn center(self: *Self, style: CenterStyle, children: anytype) void {
        self.box(.{
            .grow = true,
            .padding = .{ .all = style.padding },
            .alignment = .{ .main = .center, .cross = .center },
        }, children);
    }

    // =========================================================================
    // Component Integration
    // =========================================================================

    /// Render any component (struct with `render` method)
    pub fn with(self: *Self, component: anytype) void {
        const T = @TypeOf(component);
        if (@typeInfo(T) == .Struct and @hasDecl(T, "render")) {
            component.render(self);
        } else {
            @compileError("with() requires a struct with a `render` method");
        }
    }

    // =========================================================================
    // Conditionals
    // =========================================================================

    /// Render children only if condition is true
    pub fn when(self: *Self, condition: bool, children: anytype) void {
        if (condition) {
            self.processChildren(children);
        }
    }

    /// Render with value if optional is non-null
    pub fn maybe(self: *Self, optional: anytype, comptime render_fn: anytype) void {
        if (optional) |value| {
            const result = render_fn(value);
            self.processChild(result);
        }
    }

    // =========================================================================
    // Iteration
    // =========================================================================

    /// Render for each item in a slice
    pub fn each(self: *Self, items: anytype, comptime render_fn: anytype) void {
        for (items, 0..) |item, index| {
            const result = render_fn(item, index);
            self.processChild(result);
        }
    }

    // =========================================================================
    // Internal: Child Processing
    // =========================================================================

    fn processChildren(self: *Self, children: anytype) void {
        const T = @TypeOf(children);
        const type_info = @typeInfo(T);

        if (type_info == .@"struct" and type_info.@"struct".is_tuple) {
            inline for (children) |child| {
                self.processChild(child);
            }
        } else {
            self.processChild(children);
        }
    }

    fn processChild(self: *Self, child: anytype) void {
        const T = @TypeOf(child);
        const type_info = @typeInfo(T);

        if (type_info != .@"struct") {
            return;
        }

        if (@hasDecl(T, "primitive_type")) {
            const prim_type: PrimitiveType = T.primitive_type;
            switch (prim_type) {
                .text => self.renderText(child),
                .input => self.renderInput(child),
                .spacer => self.renderSpacer(child),
            }
            return;
        }

        if (@hasDecl(T, "render")) {
            child.render(self);
            return;
        }

        if (type_info.@"struct".is_tuple) {
            inline for (child) |nested| {
                self.processChild(nested);
            }
            return;
        }
    }

    // =========================================================================
    // Internal: Primitive Rendering
    // =========================================================================

    fn renderText(self: *Self, txt: Text) void {
        self.layout.text(txt.content, .{
            .color = txt.style.color,
            .font_size = txt.style.size,
        }) catch return;
    }

    fn renderInput(self: *Self, inp: Input) void {
        const display_text = if (inp.bind.*.len > 0)
            inp.bind.*
        else
            inp.style.placeholder;

        self.box(.{
            .padding = .{ .symmetric = .{ .x = 8, .y = 6 } },
            .background = Color.white,
            .corner_radius = 4,
            .border_color = Color.rgb(0.8, 0.8, 0.8),
            .border_width = 1,
        }, .{
            text(display_text, .{
                .size = inp.style.font_size,
                .color = if (inp.bind.*.len > 0) Color.black else Color.rgb(0.6, 0.6, 0.6),
            }),
        });
    }

    fn renderSpacer(self: *Self, spc: Spacer) void {
        _ = spc;
        self.layout.openElement(.{
            .id = self.generateId(),
            .layout = .{
                .sizing = .{
                    .width = SizingAxis.grow(),
                    .height = SizingAxis.grow(),
                },
            },
        }) catch return;
        self.layout.closeElement();
    }

    // =========================================================================
    // Internal: ID Generation
    // =========================================================================

    fn generateId(self: *Self) LayoutId {
        self.id_counter += 1;
        return LayoutId.fromInt(self.id_counter);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "text primitive" {
    const t = text("Hello", .{ .size = 20 });
    try std.testing.expectEqualStrings("Hello", t.content);
    try std.testing.expectEqual(@as(u16, 20), t.style.size);
}

test "spacer primitive" {
    const s = spacer();
    try std.testing.expectEqual(@as(f32, 0), s.min_size);

    const s2 = spacerMin(50);
    try std.testing.expectEqual(@as(f32, 50), s2.min_size);
}
