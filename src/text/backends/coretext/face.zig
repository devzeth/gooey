//! CoreText font face implementation
//!
//! Implements the FontFace interface using Apple's CoreText framework.

const std = @import("std");
const ct = @import("bindings.zig");
const types = @import("../../types.zig");
const font_face_mod = @import("../../font_face.zig");

const Metrics = types.Metrics;
const GlyphMetrics = types.GlyphMetrics;
const RasterizedGlyph = types.RasterizedGlyph;
const SystemFont = types.SystemFont;
const FontFace = font_face_mod.FontFace;

/// CoreText-backed font face
pub const CoreTextFace = struct {
    /// CoreText font reference
    ct_font: ct.CTFontRef,
    /// Cached metrics
    metrics: Metrics,

    const Self = @This();

    /// Load a font by name (e.g., "Menlo", "SF Pro", "Helvetica Neue")
    pub fn init(name: []const u8, size: f32) !Self {
        const cf_name = ct.createCFStringRuntime(name) orelse return error.InvalidFontName;
        defer ct.release(cf_name);

        const font = ct.CTFontCreateWithName(cf_name, @floatCast(size), null) orelse
            return error.FontNotFound;

        return Self{
            .ct_font = font,
            .metrics = computeMetrics(font, size),
        };
    }

    /// Load a system font
    pub fn initSystem(style: SystemFont, size: f32) !Self {
        const name = switch (style) {
            .monospace => "SF Mono",
            .sans_serif => "SF Pro",
            .serif => "New York",
            .system => ".AppleSystemUIFont",
        };
        return init(name, size);
    }

    pub fn deinit(self: *Self) void {
        ct.release(self.ct_font);
        self.* = undefined;
    }

    /// Get as the generic FontFace interface
    pub fn asFontFace(self: *Self) FontFace {
        return font_face_mod.createFontFace(Self, self);
    }

    /// Get glyph ID for a Unicode codepoint
    pub fn glyphIndex(self: *const Self, codepoint: u21) u16 {
        var utf16_buf: [2]ct.UniChar = undefined;
        var count: usize = 1;

        if (codepoint <= 0xFFFF) {
            utf16_buf[0] = @intCast(codepoint);
        } else {
            const adjusted = codepoint - 0x10000;
            utf16_buf[0] = @intCast(0xD800 + (adjusted >> 10));
            utf16_buf[1] = @intCast(0xDC00 + (adjusted & 0x3FF));
            count = 2;
        }

        var glyph: ct.CGGlyph = 0;
        const success = ct.CTFontGetGlyphsForCharacters(
            self.ct_font,
            &utf16_buf,
            @ptrCast(&glyph),
            @intCast(count),
        );

        return if (success) glyph else 0;
    }

    /// Get metrics for a specific glyph
    pub fn glyphMetrics(self: *const Self, glyph_id: u16) GlyphMetrics {
        var glyph = glyph_id;
        var advance: ct.CGSize = undefined;
        var bounds: ct.CGRect = undefined;

        _ = ct.CTFontGetAdvancesForGlyphs(
            self.ct_font,
            .horizontal,
            @ptrCast(&glyph),
            @ptrCast(&advance),
            1,
        );

        _ = ct.CTFontGetBoundingRectsForGlyphs(
            self.ct_font,
            .horizontal,
            @ptrCast(&glyph),
            @ptrCast(&bounds),
            1,
        );

        return .{
            .glyph_id = glyph_id,
            .advance_x = @floatCast(advance.width),
            .advance_y = @floatCast(advance.height),
            .bearing_x = @floatCast(bounds.origin.x),
            .bearing_y = @floatCast(bounds.origin.y + bounds.size.height),
            .width = @floatCast(bounds.size.width),
            .height = @floatCast(bounds.size.height),
        };
    }

    /// Render a glyph to a bitmap buffer
    pub fn renderGlyph(
        self: *const Self,
        glyph_id: u16,
        scale: f32,
        buffer: []u8,
        buffer_size: u32,
    ) !RasterizedGlyph {
        const glyph_metrics = self.glyphMetrics(glyph_id);
        const padding: u32 = 2;
        const padding_f: f32 = @floatFromInt(padding);

        // Handle empty glyphs (spaces, etc.)
        if (glyph_metrics.width < 1 or glyph_metrics.height < 1) {
            return RasterizedGlyph{
                .width = 0,
                .height = 0,
                .bearing_x = glyph_metrics.bearing_x,
                .bearing_y = glyph_metrics.bearing_y,
                .logical_height = glyph_metrics.height,
                .advance_x = glyph_metrics.advance_x,
                .is_color = false,
                .scale = scale,
            };
        }

        // Calculate pixel bounds with subpixel offsets
        const x = glyph_metrics.bearing_x * scale;
        const y = glyph_metrics.bearing_y * scale;
        const int_x = @floor(x);
        const int_y = @floor(y);
        const frac_x = x - int_x;
        const frac_y = y - int_y;

        // Bitmap size in physical pixels
        const width: u32 = @as(u32, @intFromFloat(@ceil(glyph_metrics.width * scale))) + padding * 2;
        const height: u32 = @as(u32, @intFromFloat(@ceil(glyph_metrics.height * scale))) + padding * 2;

        const clamped_w = @min(width, buffer_size);
        const clamped_h = @min(height, buffer_size);

        // Create CoreGraphics context
        const color_space = ct.CGColorSpaceCreateDeviceGray() orelse return error.GraphicsError;
        defer ct.CGColorSpaceRelease(color_space);

        const context = ct.CGBitmapContextCreate(
            buffer.ptr,
            clamped_w,
            clamped_h,
            8,
            clamped_w,
            color_space,
            ct.kCGImageAlphaNone,
        ) orelse return error.GraphicsError;
        defer ct.CGContextRelease(context);

        // Configure rendering
        ct.CGContextSetAllowsAntialiasing(context, true);
        ct.CGContextSetShouldAntialias(context, true);
        ct.CGContextSetAllowsFontSmoothing(context, true);
        ct.CGContextSetShouldSmoothFonts(context, true);
        ct.CGContextSetGrayFillColor(context, 1.0, 1.0);
        ct.CGContextSetAllowsFontSubpixelPositioning(context, true);
        ct.CGContextSetShouldSubpixelPositionFonts(context, true);
        ct.CGContextSetAllowsFontSubpixelQuantization(context, false);
        ct.CGContextSetShouldSubpixelQuantizeFonts(context, false);

        ct.CGContextTranslateCTM(context, frac_x, frac_y);
        ct.CGContextSetTextMatrix(context, ct.CGAffineTransform.identity);

        // Position for drawing
        const pos_x: ct.CGFloat = @as(ct.CGFloat, @floatFromInt(padding)) - glyph_metrics.bearing_x * scale;
        const pos_y: ct.CGFloat = @as(ct.CGFloat, @floatFromInt(padding)) + (glyph_metrics.height - glyph_metrics.bearing_y) * scale;

        var glyph = glyph_id;
        const position = ct.CGPoint{ .x = pos_x, .y = pos_y };

        // Create scaled font for rasterization
        const scaled_font = ct.CTFontCreateCopyWithAttributes(
            self.ct_font,
            self.metrics.point_size * scale,
            null,
            null,
        ) orelse return error.FontError;
        defer ct.release(scaled_font);

        ct.CTFontDrawGlyphs(scaled_font, @ptrCast(&glyph), @ptrCast(&position), 1, context);

        return RasterizedGlyph{
            .width = clamped_w,
            .height = clamped_h,
            .bearing_x = int_x / scale - padding_f / scale,
            .bearing_y = int_y / scale + padding_f / scale,
            .logical_height = glyph_metrics.height + 2.0 * padding_f / scale,
            .advance_x = glyph_metrics.advance_x,
            .is_color = false,
            .scale = scale,
        };
    }

    fn computeMetrics(font: ct.CTFontRef, size: f32) Metrics {
        const ascender: f32 = @floatCast(ct.CTFontGetAscent(font));
        const descender: f32 = @floatCast(ct.CTFontGetDescent(font));
        const line_gap: f32 = @floatCast(ct.CTFontGetLeading(font));
        const traits = ct.CTFontGetSymbolicTraits(font);
        const is_monospace = (traits & ct.kCTFontTraitMonoSpace) != 0;

        var test_chars = [_]ct.UniChar{ 'M', '0' };
        var glyphs: [2]ct.CGGlyph = undefined;
        _ = ct.CTFontGetGlyphsForCharacters(font, &test_chars, &glyphs, 2);

        var advances: [2]ct.CGSize = undefined;
        _ = ct.CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &advances, 2);

        const cell_width: f32 = @floatCast(@max(advances[0].width, advances[1].width));

        return .{
            .units_per_em = ct.CTFontGetUnitsPerEm(font),
            .ascender = ascender,
            .descender = descender,
            .line_gap = line_gap,
            .cap_height = @floatCast(ct.CTFontGetCapHeight(font)),
            .x_height = @floatCast(ct.CTFontGetXHeight(font)),
            .underline_position = @floatCast(ct.CTFontGetUnderlinePosition(font)),
            .underline_thickness = @floatCast(ct.CTFontGetUnderlineThickness(font)),
            .line_height = ascender + descender + line_gap,
            .point_size = size,
            .is_monospace = is_monospace,
            .cell_width = cell_width,
        };
    }
};

test "load system font" {
    var face = try CoreTextFace.initSystem(.monospace, 14.0);
    defer face.deinit();

    try std.testing.expect(face.metrics.ascender > 0);
    try std.testing.expect(face.metrics.line_height > 0);
}
