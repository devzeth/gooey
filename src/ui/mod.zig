//! UI Component System
//!
//! A declarative, component-based UI API for Gooey.
//!
//! Components are structs with a `render` method:
//! ```zig
//! const MyComponent = struct {
//!     value: i32,
//!
//!     pub fn render(self: @This(), b: *ui.Builder) void {
//!         b.box(.{}, .{ ui.text("...", .{}) });
//!     }
//! };
//! ```

const ui_impl = @import("ui.zig");

// Re-export types
pub const Builder = ui_impl.Builder;
pub const text = ui_impl.text;
pub const input = ui_impl.input;
pub const spacer = ui_impl.spacer;
pub const spacerMin = ui_impl.spacerMin;
pub const Color = ui_impl.Color;
pub const TextStyle = ui_impl.TextStyle;
pub const BoxStyle = ui_impl.BoxStyle;
pub const StackStyle = ui_impl.StackStyle;
pub const CenterStyle = ui_impl.CenterStyle;
pub const PrimitiveType = ui_impl.PrimitiveType;
pub const Text = ui_impl.Text;
pub const Input = ui_impl.Input;
pub const Spacer = ui_impl.Spacer;
