//! FontFace interface - abstraction over platform-specific font implementations
//!
//! This trait defines the operations that all font backends must support.
//! Use the concrete backend types (e.g., CoreTextFace) for platform-specific features.

const std = @import("std");
const types = @import("types.zig");

pub const Metrics = types.Metrics;
pub const GlyphMetrics = types.GlyphMetrics;
pub const RasterizedGlyph = types.RasterizedGlyph;
pub const SystemFont = types.SystemFont;

/// Font face interface - implemented by platform backends
pub const FontFace = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    /// Cached metrics (computed at font load time)
    metrics: Metrics,

    pub const VTable = struct {
        /// Get glyph ID for a Unicode codepoint
        glyphIndex: *const fn (ptr: *anyopaque, codepoint: u21) u16,

        /// Get metrics for a specific glyph
        glyphMetrics: *const fn (ptr: *anyopaque, glyph_id: u16) GlyphMetrics,

        /// Render a glyph to a bitmap buffer
        /// Returns info about the rasterized glyph
        /// Buffer must be at least buffer_size * buffer_size bytes
        renderGlyph: *const fn (
            ptr: *anyopaque,
            glyph_id: u16,
            scale: f32,
            buffer: []u8,
            buffer_size: u32,
        ) anyerror!RasterizedGlyph,

        /// Release resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// Get glyph ID for a Unicode codepoint
    /// Returns 0 for missing glyphs (.notdef)
    pub fn glyphIndex(self: FontFace, codepoint: u21) u16 {
        return self.vtable.glyphIndex(self.ptr, codepoint);
    }

    /// Get metrics for a specific glyph
    pub fn glyphMetrics(self: FontFace, glyph_id: u16) GlyphMetrics {
        return self.vtable.glyphMetrics(self.ptr, glyph_id);
    }

    /// Get glyph metrics for a codepoint (convenience)
    pub fn codepointMetrics(self: FontFace, codepoint: u21) GlyphMetrics {
        return self.glyphMetrics(self.glyphIndex(codepoint));
    }

    /// Render a glyph to a bitmap buffer
    pub fn renderGlyph(
        self: FontFace,
        glyph_id: u16,
        scale: f32,
        buffer: []u8,
        buffer_size: u32,
    ) !RasterizedGlyph {
        return self.vtable.renderGlyph(self.ptr, glyph_id, scale, buffer, buffer_size);
    }

    /// Release resources
    pub fn deinit(self: *FontFace) void {
        self.vtable.deinit(self.ptr);
        self.* = undefined;
    }
};

/// Helper to create a FontFace from a concrete implementation
pub fn createFontFace(comptime T: type, impl: *T) FontFace {
    const gen = struct {
        fn glyphIndex(ptr: *anyopaque, codepoint: u21) u16 {
            const self: *T = @ptrCast(@alignCast(ptr));
            return self.glyphIndex(codepoint);
        }

        fn glyphMetrics(ptr: *anyopaque, glyph_id: u16) GlyphMetrics {
            const self: *T = @ptrCast(@alignCast(ptr));
            return self.glyphMetrics(glyph_id);
        }

        fn renderGlyph(
            ptr: *anyopaque,
            glyph_id: u16,
            scale: f32,
            buffer: []u8,
            buffer_size: u32,
        ) anyerror!RasterizedGlyph {
            const self: *T = @ptrCast(@alignCast(ptr));
            return self.renderGlyph(glyph_id, scale, buffer, buffer_size);
        }

        fn deinit(ptr: *anyopaque) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.deinit();
        }

        const vtable = FontFace.VTable{
            .glyphIndex = glyphIndex,
            .glyphMetrics = glyphMetrics,
            .renderGlyph = renderGlyph,
            .deinit = deinit,
        };
    };

    return .{
        .ptr = impl,
        .vtable = &gen.vtable,
        .metrics = impl.metrics,
    };
}
