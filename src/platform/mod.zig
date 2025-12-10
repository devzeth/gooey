//! Platform abstraction layer for gooey
//!
//! This module provides a unified interface for platform-specific functionality:
//! - Window management
//! - Event loop
//! - GPU rendering context
//!
//! ## Architecture
//!
//! The platform module provides two ways to use platform functionality:
//!
//! 1. **Compile-time selection** (recommended): Use `Platform` and `Window` types
//!    which are aliases to the current platform's implementation. Zero overhead.
//!
//! 2. **Runtime polymorphism**: Use `PlatformVTable` and `WindowVTable` for
//!    dynamic dispatch when needed (plugin systems, testing mocks, etc.)
//!
//! ## Platform Selection
//!
//! The appropriate backend is selected at compile time based on the target OS:
//! - macOS: Metal + AppKit
//! - (future) Windows: DirectX 12 + Win32
//! - (future) Linux: Vulkan + X11/Wayland
//!
//! ## Usage
//!
//! ```zig
//! const platform = @import("gooey").platform;
//!
//! var plat = try platform.Platform.init();
//! defer plat.deinit();
//!
//! var window = try platform.Window.init(allocator, &plat, .{
//!     .title = "My App",
//!     .width = 800,
//!     .height = 600,
//! });
//! defer window.deinit();
//!
//! plat.run();
//! ```

const std = @import("std");
const builtin = @import("builtin");

// =============================================================================
// Platform Interface (for runtime polymorphism)
// =============================================================================

pub const interface = @import("interface.zig");

/// Platform interface for runtime polymorphism
pub const PlatformVTable = interface.PlatformVTable;

/// Window interface for runtime polymorphism
pub const WindowVTable = interface.WindowVTable;

/// Platform capabilities
pub const PlatformCapabilities = interface.PlatformCapabilities;

/// Window creation options (platform-agnostic)
pub const WindowOptions = interface.WindowOptions;

/// Renderer capabilities
pub const RendererCapabilities = interface.RendererCapabilities;

// =============================================================================
// Compile-time Platform Selection
// =============================================================================

pub const backend = switch (builtin.os.tag) {
    .macos => @import("mac/platform.zig"),
    else => @compileError("Unsupported platform: " ++ @tagName(builtin.os.tag)),
};

/// Platform type for the current OS (compile-time selected)
pub const Platform = backend.MacPlatform;

/// Window type for the current OS (compile-time selected)
pub const Window = @import("mac/window.zig").Window;

/// DisplayLink for vsync (macOS-specific, abstracted on other platforms)
pub const DisplayLink = @import("mac/display_link.zig").DisplayLink;

// =============================================================================
// Platform-specific modules (for advanced usage)
// =============================================================================

pub const mac = struct {
    pub const platform = @import("mac/platform.zig");
    pub const window = @import("mac/window.zig");
    pub const display_link = @import("mac/display_link.zig");
    pub const appkit = @import("mac/appkit.zig");
    pub const metal = @import("mac/metal/metal.zig");
};

// =============================================================================
// Helpers
// =============================================================================

/// Create a platform interface from the compile-time selected platform.
/// Useful when you need runtime polymorphism.
pub fn makePlatformInterface(plat: *Platform) PlatformVTable {
    return plat.interface();
}

/// Get the capabilities of the current platform.
pub fn getCapabilities() PlatformCapabilities {
    return Platform.capabilities;
}
