Engineering Notes

1. Always prefer performance as number 1 priority!
2. We are using Zig 0.15.2. make sure to use latest API's
   e.g. Check how we do ArrayList inits.

Each glyph carries its own clip bounds, and the fragment shader discards pixels outside. No extra draw calls, no scissor rect state changes, just a simple `discard_fragment()` in the shader.

So we have a foundation for:

1. **Scroll containers** - push clip to viewport, render children, pop
2. **`overflow: hidden`** on any element - same pattern
3. **Nested clips** - the stack automatically intersects them
4. **Tooltips/dropdowns** that can overflow their parent - just don't push a clip

Design Philosophy

1. **Plain structs by default** - no wrappers needed for simple state
2. **Context when you need it** - opt-in to reactivity
3. **Components are just structs with `render`** - like GPUI Views
4. **Progressive complexity** - start simple, add power as needed

---

## Level 1: Dead Simple App

For a quick tool or demo - just functions and state:

```gooey/examples/simple.zig#L1-55
const std = @import("std");
const gooey = @import("gooey");

// Plain struct - no wrappers, no ceremony
var state = struct {
    count: i32 = 0,
    name: []const u8 = "",
}{};

pub fn main() !void {
    try gooey.run(.{
        .title = "Simple Counter",
        .size = .{ 400, 300 },
        .render = render,
        .on_event = onEvent,
    });
}

fn render(ui: *gooey.UI) void {
    ui.vstack(.{ .gap = 16, .padding = 24 }, .{
        ui.text("Count: {}", .{state.count}),

        ui.hstack(.{ .gap = 8 }, .{
            ui.button("-", .{ .on_click = decrement }),
            ui.button("+", .{ .on_click = increment }),
        }),

        ui.input("Name", &state.name),

        if (state.name.len > 0)
            ui.text("Hello, {s}!", .{state.name})
        else
            ui.empty(),
    });
}

fn increment() void {
    state.count += 1;
}

fn decrement() void {
    state.count -= 1;
}

fn onEvent(event: gooey.Event) bool {
    if (event.isKey(.escape)) {
        gooey.quit();
        return true;
    }
    return false;
}
```

---

## Level 2: Component-Based App

When you want reusable pieces:

```gooey/examples/components.zig#L1-95
const std = @import("std");
const gooey = @import("gooey");
const UI = gooey.UI;

// ============================================================================
// Components are just structs with render()
// ============================================================================

const Counter = struct {
    label: []const u8,
    value: *i32,

    pub fn render(self: Counter, ui: *UI) void {
        ui.hstack(.{ .gap = 8, .align = .center }, .{
            ui.text("{s}: {}", .{ self.label, self.value.* }),
            ui.button("-", .{ .on_click = self.makeDecrement() }),
            ui.button("+", .{ .on_click = self.makeIncrement() }),
        });
    }

    fn makeIncrement(self: Counter) *const fn() void {
        // Capture pointer for callback
        return struct {
            var ptr: *i32 = undefined;
            fn inc() void { ptr.* += 1; }
        }.init(self.value);
    }
};

const LoginForm = struct {
    username: []const u8 = "",
    password: []const u8 = "",
    on_submit: ?*const fn([]const u8, []const u8) void = null,

    pub fn render(self: *LoginForm, ui: *UI) void {
        ui.card(.{ .padding = 24, .gap = 16, .width = 350 }, .{
            ui.heading("Sign In"),

            ui.field("Username", .{
                .bind = &self.username,
                .placeholder = "Enter username",
            }),

            ui.field("Password", .{
                .bind = &self.password,
                .secure = true,
            }),

            ui.hstack(.{ .gap = 12, .justify = .end }, .{
                ui.button("Cancel", .{ .style = .secondary }),
                ui.button("Sign In", .{
                    .style = .primary,
                    .on_click = self.handleSubmit(),
                }),
            }),
        });
    }
};

// ============================================================================
// App
// ============================================================================

var app_state = struct {
    clicks: i32 = 0,
    form: LoginForm = .{},
}{};

pub fn main() !void {
    try gooey.run(.{
        .title = "Components Demo",
        .render = render,
    });
}

fn render(ui: *UI) void {
    ui.center(.{}, .{
        ui.vstack(.{ .gap = 32 }, .{
            // Use component inline
            Counter{ .label = "Clicks", .value = &app_state.clicks },

            // Or reference a field that is a component
            &app_state.form,
        }),
    });
}
```

---

## Level 3: App Context + Shared State

When you need dependency injection, multiple windows, or services:

```gooey/examples/with_context.zig#L1-130
const std = @import("std");
const gooey = @import("gooey");
const UI = gooey.UI;
const Context = gooey.Context;

// ============================================================================
// App-level state and services
// ============================================================================

const AppState = struct {
    user: ?User = null,
    theme: Theme = .light,
    notifications: std.ArrayList(Notification),

    // Services
    api: *ApiClient,
    storage: *Storage,
};

// ============================================================================
// Views get Context - like GPUI's ViewContext
// ============================================================================

const Sidebar = struct {
    collapsed: bool = false,

    // render receives Context for accessing app state/services
    pub fn render(self: *Sidebar, ui: *UI, cx: *Context) void {
        const width: f32 = if (self.collapsed) 60 else 240;

        ui.box(.{ .width = width, .fill_height = true, .background = cx.theme().sidebar }, .{
            ui.vstack(.{ .gap = 4, .padding = 8 }, .{
                NavItem{ .icon = "home", .label = "Dashboard", .route = "/" },
                NavItem{ .icon = "settings", .label = "Settings", .route = "/settings" },

                ui.spacer(),

                // Access app state through context
                if (cx.state().user) |user|
                    UserBadge{ .user = user }
                else
                    ui.button("Sign In", .{ .on_click = cx.action(showLogin) }),
            }),
        });
    }

    fn showLogin(cx: *Context) void {
        cx.openModal(LoginModal{});
    }
};

const Dashboard = struct {
    pub fn render(self: *Dashboard, ui: *UI, cx: *Context) void {
        _ = self;
        ui.vstack(.{ .gap = 24, .padding = 24 }, .{
            ui.heading("Dashboard"),

            // Async data loading
            ui.async(cx.state().api.fetchStats(), .{
                .loading = ui.spinner(),
                .success = |stats| StatsGrid{ .stats = stats },
                .failure = |err| ErrorBanner{ .message = err },
            }),
        });
    }
};

// ============================================================================
// Main App View
// ============================================================================

const App = struct {
    sidebar: Sidebar = .{},
    router: Router = .{},

    pub fn render(self: *App, ui: *UI, cx: *Context) void {
        ui.hstack(.{ .fill = true }, .{
            &self.sidebar,

            ui.box(.{ .grow = true }, .{
                self.router.currentView(cx),
            }),
        });

        // Render any open modals
        cx.renderModals(ui);

        // Render notifications
        ui.overlay(.bottom_right, .{
            NotificationStack{ .items = cx.state().notifications.items },
        });
    }
};

// ============================================================================
// Bootstrap
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create services
    var api = try ApiClient.init(allocator, "https://api.example.com");
    defer api.deinit();

    var storage = try Storage.init(allocator);
    defer storage.deinit();

    // Create app state
    var state = AppState{
        .notifications = std.ArrayList(Notification).init(allocator),
        .api = &api,
        .storage = &storage,
    };

    // Run with context
    try gooey.runWithContext(App{}, &state, .{
        .title = "My App",
        .size = .{ 1200, 800 },
    });
}
```

---

## Level 4: Full GPUI-Style Entities

For complex apps with shared mutable state across views:

```gooey/examples/entities.zig#L1-150
const std = @import("std");
const gooey = @import("gooey");
const Entity = gooey.Entity;
const Context = gooey.Context;
const UI = gooey.UI;

// ============================================================================
// Entities - reference-counted, observable state
// ============================================================================

const Document = struct {
    title: []const u8,
    content: []const u8,
    modified: bool = false,

    pub fn setContent(self: *Document, cx: *Context, content: []const u8) void {
        self.content = content;
        self.modified = true;
        cx.notify();  // Triggers re-render of observers
    }
};

const Workspace = struct {
    documents: std.ArrayList(Entity(Document)),
    active_document: ?Entity(Document) = null,

    pub fn openDocument(self: *Workspace, cx: *Context, path: []const u8) !void {
        const content = try cx.services().fs.readFile(path);
        const doc = try cx.new(Document, .{
            .title = std.fs.path.basename(path),
            .content = content,
        });
        try self.documents.append(doc);
        self.active_document = doc;
        cx.notify();
    }

    pub fn closeDocument(self: *Workspace, cx: *Context, doc: Entity(Document)) void {
        // Find and remove
        for (self.documents.items, 0..) |d, i| {
            if (d.id() == doc.id()) {
                _ = self.documents.orderedRemove(i);
                break;
            }
        }
        if (self.active_document) |active| {
            if (active.id() == doc.id()) {
                self.active_document = self.documents.getLastOrNull();
            }
        }
        cx.notify();
    }
};

// ============================================================================
// Views that observe entities
// ============================================================================

const Editor = struct {
    document: Entity(Document),

    pub fn render(self: *Editor, ui: *UI, cx: *Context) void {
        // Reading the entity automatically subscribes to changes
        const doc = cx.read(self.document);

        ui.vstack(.{ .fill = true }, .{
            // Tab bar
            ui.hstack(.{ .gap = 0 }, .{
                ui.text(doc.title, .{}),
                if (doc.modified) ui.text(" •", .{ .color = .blue }) else ui.empty(),
            }),

            // Editor area
            ui.textEditor(.{
                .content = doc.content,
                .on_change = |new_content| {
                    // Update through context to trigger reactivity
                    cx.update(self.document, |d| {
                        d.setContent(cx, new_content);
                    });
                },
            }),
        });
    }
};

const TabBar = struct {
    workspace: Entity(Workspace),

    pub fn render(self: *TabBar, ui: *UI, cx: *Context) void {
        const ws = cx.read(self.workspace);

        ui.hstack(.{ .gap = 2 }, .{
            ui.each(ws.documents.items, |doc| {
                Tab{ .document = doc, .workspace = self.workspace }
            }),

            ui.button("+", .{
                .on_click = || cx.emit(OpenFileDialog{}),
            }),
        });
    }
};

// ============================================================================
// App Root
// ============================================================================

const App = struct {
    workspace: Entity(Workspace),

    pub fn init(cx: *Context) !App {
        return .{
            .workspace = try cx.new(Workspace, .{
                .documents = std.ArrayList(Entity(Document)).init(cx.allocator()),
            }),
        };
    }

    pub fn render(self: *App, ui: *UI, cx: *Context) void {
        const ws = cx.read(self.workspace);

        ui.vstack(.{ .fill = true }, .{
            TabBar{ .workspace = self.workspace },

            if (ws.active_document) |doc|
                Editor{ .document = doc }
            else
                EmptyState{ .message = "Open a file to begin" },
        });
    }

    // Handle app-level events
    pub fn on(self: *App, cx: *Context, event: anytype) void {
        switch (@TypeOf(event)) {
            OpenFileDialog => {
                if (cx.services().dialogs.openFile()) |path| {
                    cx.update(self.workspace, |ws| {
                        ws.openDocument(cx, path) catch {};
                    });
                }
            },
            // ...
        }
    }
};

pub fn main() !void {
    try gooey.app(App, .{
        .title = "Code Editor",
    });
}
```

---

## The Key Abstractions

### 1. `UI` - The Immediate-Mode Builder

```gooey/src/ui.zig#L1-30
pub const UI = struct {
    // Core building blocks
    pub fn box(self: *UI, style: BoxStyle, children: anytype) void;
    pub fn text(self: *UI, comptime fmt: []const u8, args: anytype) void;
    pub fn button(self: *UI, label: []const u8, opts: ButtonOpts) void;
    pub fn input(self: *UI, label: []const u8, bind: *[]const u8) void;

    // Layout helpers
    pub fn vstack(self: *UI, style: StackStyle, children: anytype) void;
    pub fn hstack(self: *UI, style: StackStyle, children: anytype) void;
    pub fn center(self: *UI, style: CenterStyle, children: anytype) void;

    // Conditionals
    pub fn when(self: *UI, cond: bool, child: anytype) void;
    pub fn each(self: *UI, items: anytype, render: anytype) void;

    // Utilities
    pub fn spacer(self: *UI) void;
    pub fn empty(self: *UI) void;
};
```

### 2. `Context` - Optional App Services

```gooey/src/context.zig#L1-45
pub fn Context(comptime State: type) type {
    return struct {
        // State access
        pub fn state(self: *@This()) *State;

        // Entity operations (when using entities)
        pub fn new(self: *@This(), comptime T: type, value: T) !Entity(T);
        pub fn read(self: *@This(), entity: Entity(anytype)) *const @TypeOf(entity).Inner;
        pub fn update(self: *@This(), entity: Entity(anytype), f: anytype) void;

        // Reactivity
        pub fn notify(self: *@This()) void;  // Trigger re-render
        pub fn subscribe(self: *@This(), entity: Entity(anytype)) void;

        // Services
        pub fn services(self: *@This()) *Services;
        pub fn allocator(self: *@This()) std.mem.Allocator;

        // UI operations
        pub fn openModal(self: *@This(), view: anytype) void;
        pub fn closeModal(self: *@This()) void;
        pub fn emit(self: *@This(), event: anytype) void;
        pub fn navigate(self: *@This(), route: []const u8) void;

        // Window
        pub fn requestRender(self: *@This()) void;
        pub fn setTitle(self: *@This(), title: []const u8) void;
    };
}
```

### 3. Components - Just Structs

```gooey/src/component.zig#L1-25
// A component is ANY struct with a render method.
// The signature determines what it receives:

// Simple - just UI
const Simple = struct {
    pub fn render(self: @This(), ui: *UI) void { ... }
};

// With context - gets app access
const WithContext = struct {
    pub fn render(self: *@This(), ui: *UI, cx: *Context) void { ... }
};

// Stateful - can have mutable state
const Stateful = struct {
    count: i32 = 0,

    pub fn render(self: *@This(), ui: *UI, cx: *Context) void {
        ui.button("+", .{ .on_click = || {
            self.count += 1;
            cx.notify();
        }});
    }
};
```

---

## What Makes This Feel Good

| Aspect     | Simple Case               | Complex Case                        |
| ---------- | ------------------------- | ----------------------------------- |
| State      | Global `var`              | `Entity(T)` with reactivity         |
| Components | Struct with `render(*UI)` | Struct with `render(*UI, *Context)` |
| Events     | Simple function callbacks | `cx.emit()` + handlers              |
| Services   | Not needed                | Injected via Context                |
| Windows    | Single, implicit          | Multiple via `cx.openWindow()`      |

The key insight from GPUI that we keep:

- **Views/Components are structs** - not functions, not closures
- **Context provides access** - don't pass everything explicitly
- **Entities for shared state** - when you need it
- **Notify for reactivity** - explicit but simple

What we simplify:

- **No Entity required for simple state** - just use `var`
- **No Context required for simple views** - just `render(ui)`
- **Progressive adoption** - start simple, add complexity as needed
