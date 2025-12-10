//! Glyph cache - maps (font_id, glyph_id, size) to atlas regions
//!
//! Renders glyphs on-demand using the FontFace interface and caches
//! them in the texture atlas.

const std = @import("std");
const types = @import("types.zig");
const font_face_mod = @import("font_face.zig");
const Atlas = @import("atlas.zig").Atlas;
const Region = @import("atlas.zig").Region;

const FontFace = font_face_mod.FontFace;
const RasterizedGlyph = types.RasterizedGlyph;

/// Key for glyph lookup
pub const GlyphKey = struct {
    /// Font identifier (pointer-based)
    font_ptr: usize,
    /// Glyph ID from the font
    glyph_id: u16,
    /// Font size in 1/64th points (for subpixel precision)
    size_fixed: u16,
    /// Scale factor (1-4x)
    scale_fixed: u8,

    pub fn init(face: FontFace, glyph_id: u16, scale: f32) GlyphKey {
        return .{
            .font_ptr = @intFromPtr(face.ptr),
            .glyph_id = glyph_id,
            .size_fixed = @intFromFloat(face.metrics.point_size * 64.0),
            .scale_fixed = @intFromFloat(@max(1.0, @min(4.0, scale))),
        };
    }
};

/// Cached glyph information
pub const CachedGlyph = struct {
    /// Region in the atlas
    region: Region,
    /// Horizontal bearing (offset from pen position to left edge)
    bearing_x: f32,
    /// Vertical bearing (offset from baseline to top edge)
    bearing_y: f32,
    /// Logical glyph height (for precise positioning)
    height: f32,
    /// Horizontal advance to next glyph
    advance_x: f32,
    /// Whether this glyph uses the color atlas (emoji)
    is_color: bool,
    /// Scale factor used
    scale: f32,
};

/// Glyph cache with atlas management
pub const GlyphCache = struct {
    allocator: std.mem.Allocator,
    /// Glyph lookup table
    map: std.AutoHashMap(GlyphKey, CachedGlyph),
    /// Grayscale atlas for regular text
    grayscale_atlas: Atlas,
    /// Color atlas for emoji (optional)
    color_atlas: ?Atlas,
    /// Reusable bitmap buffer for rendering
    render_buffer: []u8,
    render_buffer_size: u32,
    scale_factor: f32,

    const Self = @This();
    const RENDER_BUFFER_SIZE: u32 = 256; // Max glyph size

    pub fn init(allocator: std.mem.Allocator, scale: f32) !Self {
        const buffer_bytes = RENDER_BUFFER_SIZE * RENDER_BUFFER_SIZE;
        const render_buffer = try allocator.alloc(u8, buffer_bytes);
        @memset(render_buffer, 0);

        return .{
            .allocator = allocator,
            .map = std.AutoHashMap(GlyphKey, CachedGlyph).init(allocator),
            .grayscale_atlas = try Atlas.init(allocator, .grayscale),
            .color_atlas = null,
            .render_buffer = render_buffer,
            .render_buffer_size = RENDER_BUFFER_SIZE,
            .scale_factor = scale,
        };
    }

    pub fn setScaleFactor(self: *Self, scale: f32) void {
        if (self.scale_factor != scale) {
            self.scale_factor = scale;
            self.clear();
        }
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
        self.grayscale_atlas.deinit();
        if (self.color_atlas) |*ca| ca.deinit();
        self.allocator.free(self.render_buffer);
        self.* = undefined;
    }

    /// Get a cached glyph, or render and cache it
    pub fn getOrRender(self: *Self, face: FontFace, glyph_id: u16) !CachedGlyph {
        const key = GlyphKey.init(face, glyph_id, self.scale_factor);

        if (self.map.get(key)) |cached| {
            return cached;
        }

        const glyph = try self.renderGlyph(face, glyph_id);
        try self.map.put(key, glyph);
        return glyph;
    }

    fn renderGlyph(self: *Self, face: FontFace, glyph_id: u16) !CachedGlyph {
        @memset(self.render_buffer, 0);

        // Use the FontFace interface to render
        const rasterized = try face.renderGlyph(
            glyph_id,
            self.scale_factor,
            self.render_buffer,
            self.render_buffer_size,
        );

        // Handle empty glyphs (spaces, etc.)
        if (rasterized.width == 0 or rasterized.height == 0) {
            return CachedGlyph{
                .region = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .bearing_x = rasterized.bearing_x,
                .bearing_y = rasterized.bearing_y,
                .advance_x = rasterized.advance_x,
                .height = rasterized.logical_height,
                .is_color = rasterized.is_color,
                .scale = rasterized.scale,
            };
        }

        // Reserve space in atlas
        const region = try self.grayscale_atlas.reserve(rasterized.width, rasterized.height) orelse blk: {
            try self.grayscale_atlas.grow();
            break :blk try self.grayscale_atlas.reserve(rasterized.width, rasterized.height) orelse
                return error.AtlasFull;
        };

        // Copy rasterized data to atlas
        self.grayscale_atlas.set(region, self.render_buffer[0 .. rasterized.width * rasterized.height]);

        return CachedGlyph{
            .region = region,
            .bearing_x = rasterized.bearing_x,
            .bearing_y = rasterized.bearing_y,
            .height = rasterized.logical_height,
            .advance_x = rasterized.advance_x,
            .is_color = rasterized.is_color,
            .scale = rasterized.scale,
        };
    }

    /// Clear the cache (call when changing fonts)
    pub fn clear(self: *Self) void {
        self.map.clearRetainingCapacity();
        self.grayscale_atlas.clear();
        if (self.color_atlas) |*ca| ca.clear();
    }

    /// Get the grayscale atlas for GPU upload
    pub fn getAtlas(self: *const Self) *const Atlas {
        return &self.grayscale_atlas;
    }

    /// Get atlas generation (for detecting changes)
    pub fn getGeneration(self: *const Self) u32 {
        return self.grayscale_atlas.generation;
    }
};
