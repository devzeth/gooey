//! Shared types for the text system
//!
//! These types are platform-agnostic and used by all text backends.

const std = @import("std");

/// System font styles
pub const SystemFont = enum {
    monospace,
    sans_serif,
    serif,
    system,
};

/// Font metrics computed once at load time
pub const Metrics = struct {
    /// Design units per em
    units_per_em: u32,
    /// Ascent in points (positive, above baseline)
    ascender: f32,
    /// Descent in points (positive, below baseline)
    descender: f32,
    /// Line gap / leading
    line_gap: f32,
    /// Height of capital letters
    cap_height: f32,
    /// Height of lowercase 'x'
    x_height: f32,
    /// Underline position (negative = below baseline)
    underline_position: f32,
    /// Underline thickness
    underline_thickness: f32,
    /// Total line height (ascender + descender + line_gap)
    line_height: f32,
    /// Font size in points
    point_size: f32,
    /// Is this a monospace font?
    is_monospace: bool,
    /// Cell width for monospace fonts (advance of 'M')
    cell_width: f32,
};

/// Glyph metrics for a single glyph
pub const GlyphMetrics = struct {
    /// Glyph ID (0 = missing glyph)
    glyph_id: u16,
    /// Horizontal advance
    advance_x: f32,
    /// Vertical advance (usually 0 for horizontal text)
    advance_y: f32,
    /// Bounding box origin X (left bearing)
    bearing_x: f32,
    /// Bounding box origin Y (top bearing from baseline)
    bearing_y: f32,
    /// Bounding box width
    width: f32,
    /// Bounding box height
    height: f32,
};

/// A shaped glyph with positioning information
pub const ShapedGlyph = struct {
    /// Glyph ID in the font
    glyph_id: u16,
    /// Horizontal offset from pen position
    x_offset: f32,
    /// Vertical offset from baseline
    y_offset: f32,
    /// Horizontal advance for next glyph
    x_advance: f32,
    /// Vertical advance (usually 0)
    y_advance: f32,
    /// Index into original text (byte offset)
    cluster: u32,
};

/// Result of shaping a text run
pub const ShapedRun = struct {
    glyphs: []ShapedGlyph,
    /// Total advance width
    width: f32,

    pub fn deinit(self: *ShapedRun, allocator: std.mem.Allocator) void {
        if (self.glyphs.len > 0) {
            allocator.free(self.glyphs);
        }
        self.* = undefined;
    }
};

/// Result of rasterizing a glyph
pub const RasterizedGlyph = struct {
    /// Width of the rasterized bitmap in pixels
    width: u32,
    /// Height of the rasterized bitmap in pixels
    height: u32,
    /// Horizontal bearing (offset from pen to left edge) in logical pixels
    bearing_x: f32,
    /// Vertical bearing (offset from baseline to top edge) in logical pixels
    bearing_y: f32,
    /// Logical height including padding
    logical_height: f32,
    /// Horizontal advance to next glyph
    advance_x: f32,
    /// Whether this is a color glyph (emoji)
    is_color: bool,
    /// The scale factor used for rasterization
    scale: f32,
};

/// Text measurement result
pub const TextMeasurement = struct {
    /// Total width of the text
    width: f32,
    /// Height (based on font metrics)
    height: f32,
    /// Number of lines (for wrapped text)
    line_count: u32 = 1,
};
