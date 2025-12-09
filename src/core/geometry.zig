//! Core geometry types for the UI framework
//!
//! Provides generic, reusable geometry primitives:
//! - Point, Size, Rect/Bounds for spatial layout
//! - Edges for padding/margins
//! - Corners for border radii
//! - Color for RGBA colors

const std = @import("std");

// =============================================================================
// Unit Type Aliases
// =============================================================================

/// Logical pixels (before scaling)
pub const Pixels = f32;

/// Scaled pixels (after applying scale factor)
pub const ScaledPixels = f32;

// =============================================================================
// Point
// =============================================================================

/// A 2D point with x and y coordinates
pub fn Point(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,

        const Self = @This();

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{ .x = self.x * factor, .y = self.y * factor };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub const zero = Self{ .x = 0, .y = 0 };
    };
}

// =============================================================================
// Size
// =============================================================================

/// A 2D size with width and height
pub fn Size(comptime T: type) type {
    return struct {
        width: T = 0,
        height: T = 0,

        const Self = @This();

        pub fn init(width: T, height: T) Self {
            return .{ .width = width, .height = height };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{ .width = self.width * factor, .height = self.height * factor };
        }

        pub fn area(self: Self) T {
            return self.width * self.height;
        }

        pub const zero = Self{ .width = 0, .height = 0 };
    };
}

// =============================================================================
// Rect / Bounds
// =============================================================================

/// A rectangle with origin point and size.
pub fn Rect(comptime T: type) type {
    return struct {
        origin: Point(T) = .{},
        size: Size(T) = .{},

        const Self = @This();

        pub fn init(x: T, y: T, w: T, h: T) Self {
            return .{
                .origin = .{ .x = x, .y = y },
                .size = .{ .width = w, .height = h },
            };
        }

        pub fn fromOriginSize(origin: Point(T), size: Size(T)) Self {
            return .{ .origin = origin, .size = size };
        }

        pub fn contains(self: Self, point: Point(T)) bool {
            return point.x >= self.origin.x and
                point.x < self.origin.x + self.size.width and
                point.y >= self.origin.y and
                point.y < self.origin.y + self.size.height;
        }

        pub fn containsPoint(self: Self, x: T, y: T) bool {
            return x >= self.origin.x and
                x < self.origin.x + self.size.width and
                y >= self.origin.y and
                y < self.origin.y + self.size.height;
        }

        pub fn inset(self: Self, edges: Edges(T)) Self {
            return .{
                .origin = .{
                    .x = self.origin.x + edges.left,
                    .y = self.origin.y + edges.top,
                },
                .size = .{
                    .width = @max(0, self.size.width - edges.horizontal()),
                    .height = @max(0, self.size.height - edges.vertical()),
                },
            };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{
                .origin = self.origin.scale(factor),
                .size = self.size.scale(factor),
            };
        }

        pub fn left(self: Self) T {
            return self.origin.x;
        }
        pub fn top(self: Self) T {
            return self.origin.y;
        }
        pub fn right(self: Self) T {
            return self.origin.x + self.size.width;
        }
        pub fn bottom(self: Self) T {
            return self.origin.y + self.size.height;
        }
        pub fn width(self: Self) T {
            return self.size.width;
        }
        pub fn height(self: Self) T {
            return self.size.height;
        }

        pub const zero = Self{};
    };
}

/// Alias for Rect
pub fn Bounds(comptime T: type) type {
    return Rect(T);
}

// =============================================================================
// Edges (for padding, margins, border widths)
// =============================================================================

pub fn Edges(comptime T: type) type {
    return struct {
        top: T = 0,
        right: T = 0,
        bottom: T = 0,
        left: T = 0,

        const Self = @This();

        pub fn all(value: T) Self {
            return .{ .top = value, .right = value, .bottom = value, .left = value };
        }

        pub fn symmetric(h: T, v: T) Self {
            return .{ .top = v, .right = h, .bottom = v, .left = h };
        }

        pub fn horizontal(self: Self) T {
            return self.left + self.right;
        }
        pub fn vertical(self: Self) T {
            return self.top + self.bottom;
        }

        pub const zero = Self{};
    };
}

// =============================================================================
// Corners (for border radii)
// =============================================================================

pub fn Corners(comptime T: type) type {
    return struct {
        top_left: T = 0,
        top_right: T = 0,
        bottom_right: T = 0,
        bottom_left: T = 0,

        const Self = @This();

        pub fn all(radius: T) Self {
            return .{ .top_left = radius, .top_right = radius, .bottom_right = radius, .bottom_left = radius };
        }

        pub const zero = Self{};
    };
}

// =============================================================================
// Color
// =============================================================================

pub const Color = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,

    pub fn init(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    pub fn withAlpha(self: Color, a: f32) Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = a };
    }

    pub const white = Color{ .r = 1, .g = 1, .b = 1, .a = 1 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 1 };
    pub const red = Color{ .r = 1, .g = 0, .b = 0, .a = 1 };
    pub const green = Color{ .r = 0, .g = 1, .b = 0, .a = 1 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 1, .a = 1 };
    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const clear = transparent;
};

// =============================================================================
// Concrete type aliases
// =============================================================================

pub const PointF = Point(Pixels);
pub const SizeF = Size(Pixels);
pub const RectF = Rect(Pixels);
pub const BoundsF = Bounds(Pixels);
pub const EdgesF = Edges(Pixels);
pub const CornersF = Corners(Pixels);
