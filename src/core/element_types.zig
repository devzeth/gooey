//! Element identity types
//!
//! Provides stable identity for elements across renders:
//! - ElementId: unique element identity (named, integer, or focus handle)
//! - GlobalElementId: path-based ID for disambiguation
//! - LayoutNodeId: index into layout tree
//! - AvailableSpace: layout constraint

const std = @import("std");

// Re-export geometry types for convenience
pub const geometry = @import("geometry.zig");
pub const Pixels = geometry.Pixels;
pub const Point = geometry.Point;
pub const Size = geometry.Size;
pub const Rect = geometry.Rect;
pub const Bounds = geometry.Bounds;
pub const Edges = geometry.Edges;
pub const Corners = geometry.Corners;

// =============================================================================
// Available Space (for layout constraints)
// =============================================================================

pub const AvailableSpace = union(enum) {
    definite: Pixels,
    min_content,
    max_content,

    pub fn unwrapOr(self: AvailableSpace, default: Pixels) Pixels {
        return switch (self) {
            .definite => |v| v,
            else => default,
        };
    }
};

// =============================================================================
// Layout Node ID
// =============================================================================

pub const LayoutNodeId = struct {
    index: u32,

    pub const invalid = LayoutNodeId{ .index = std.math.maxInt(u32) };

    pub fn isValid(self: LayoutNodeId) bool {
        return self.index != std.math.maxInt(u32);
    }
};

// =============================================================================
// Element ID (stable identity across renders)
// =============================================================================

pub const ElementId = union(enum) {
    name: NamedId,
    integer: u64,
    focus_handle: u64,

    pub const NamedId = struct {
        hash: u64,

        pub fn init(name: []const u8) NamedId {
            return .{ .hash = std.hash.Wyhash.hash(0, name) };
        }
    };

    pub fn named(name: []const u8) ElementId {
        return .{ .name = NamedId.init(name) };
    }

    pub fn int(id: u64) ElementId {
        return .{ .integer = id };
    }

    pub fn eql(self: ElementId, other: ElementId) bool {
        return switch (self) {
            .name => |n| switch (other) {
                .name => |on| n.hash == on.hash,
                else => false,
            },
            .integer => |i| switch (other) {
                .integer => |oi| i == oi,
                else => false,
            },
            .focus_handle => |f| switch (other) {
                .focus_handle => |of| f == of,
                else => false,
            },
        };
    }

    pub fn hash(self: ElementId) u64 {
        return switch (self) {
            .name => |n| n.hash,
            .integer, .focus_handle => |i| i,
        };
    }
};

// =============================================================================
// Global Element ID (path from root for disambiguation)
// =============================================================================

pub const GlobalElementId = struct {
    allocator: std.mem.Allocator,
    path: std.ArrayList(ElementId),

    pub fn init(allocator: std.mem.Allocator) GlobalElementId {
        return .{
            .allocator = allocator,
            .path = std.ArrayList(ElementId).init(allocator),
        };
    }

    pub fn deinit(self: *GlobalElementId) void {
        self.path.deinit();
    }

    pub fn push(self: *GlobalElementId, id: ElementId) !void {
        try self.path.append(id);
    }

    pub fn pop(self: *GlobalElementId) ?ElementId {
        return self.path.popOrNull();
    }

    pub fn hash(self: *const GlobalElementId) u64 {
        var h: u64 = 0;
        for (self.path.items) |id| {
            h = std.hash.Wyhash.hash(h, std.mem.asBytes(&id.hash()));
        }
        return h;
    }
};
