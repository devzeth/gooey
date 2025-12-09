//! gooey - A minimal GPU-accelerated UI framework for Zig
//! Inspired by GPUI, targeting macOS with Metal rendering.

const std = @import("std");

// =============================================================================
// Core Types
// =============================================================================

// Geometry
pub const geometry = @import("core/geometry.zig");
pub const Size = geometry.Size;
pub const Point = geometry.Point;
pub const Rect = geometry.Rect;
pub const Color = geometry.Color;
pub const Bounds = geometry.Bounds;
pub const BoundsF = geometry.BoundsF;
pub const Edges = geometry.Edges;
pub const Corners = geometry.Corners;
pub const Pixels = geometry.Pixels;

// Input events
pub const input = @import("core/input.zig");
pub const InputEvent = input.InputEvent;
pub const MouseEvent = input.MouseEvent;
pub const MouseButton = input.MouseButton;
pub const KeyEvent = input.KeyEvent;
pub const KeyCode = input.KeyCode;
pub const Modifiers = input.Modifiers;

// Scene and primitives
pub const scene = @import("core/scene.zig");
pub const Scene = scene.Scene;
pub const Quad = scene.Quad;
pub const Shadow = scene.Shadow;
pub const Hsla = scene.Hsla;
pub const GlyphInstance = scene.GlyphInstance;

// Element types
pub const element_id = @import("core/element_types.zig");
pub const ElementId = element_id.ElementId;

// Event system
pub const event = @import("core/event.zig");
pub const Event = event.Event;
pub const EventPhase = event.EventPhase;
pub const EventResult = event.EventResult;

// =============================================================================
// Gooey Context & Widgets
// =============================================================================

// Gooey unified context
pub const gooey_ctx = @import("core/gooey.zig");
pub const Gooey = gooey_ctx.Gooey;

// Widget store (retained widget management)
pub const widget_store = @import("core/widget_store.zig");
pub const WidgetStore = widget_store.WidgetStore;

// =============================================================================
// Font System
// =============================================================================

pub const font = @import("font/main.zig");
pub const TextSystem = font.TextSystem;
pub const Face = font.Face;
pub const TextStyle = font.TextStyle;

// =============================================================================
// Layout System
// =============================================================================

pub const layout = @import("layout/layout.zig");
pub const LayoutEngine = layout.LayoutEngine;
pub const LayoutId = layout.LayoutId;
pub const Sizing = layout.Sizing;
pub const SizingAxis = layout.SizingAxis;
pub const Padding = layout.Padding;
pub const LayoutConfig = layout.LayoutConfig;
pub const ElementDeclaration = layout.ElementDeclaration;
pub const BoundingBox = layout.BoundingBox;
pub const ChildAlignment = layout.ChildAlignment;
pub const CornerRadius = layout.CornerRadius;

// =============================================================================
// Platform
// =============================================================================

pub const platform = @import("platform/mac/platform.zig");
pub const MacPlatform = platform.MacPlatform;
pub const Window = @import("platform/mac/window.zig").Window;
pub const DisplayLink = @import("platform/mac/display_link.zig").DisplayLink;

// =============================================================================
// Widgets
// =============================================================================

pub const elements = @import("elements.zig");
pub const TextInput = elements.TextInput;

// =============================================================================
// UI Component System
// =============================================================================

pub const ui = @import("ui/mod.zig");
pub const Builder = ui.Builder;

// =============================================================================
// App - Convenience Entry Point
// =============================================================================

pub const app = @import("app.zig");
pub const run = app.run;
pub const UI = app.UI;
pub const RunConfig = app.RunConfig;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}
