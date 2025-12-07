# gooey

**A GPU-accelerated UI framework for Zig, inspired by [GPUI](https://github.com/zed-industries/zed/tree/main/crates/gpui)**

Gooey is a hybrid immediate/retained mode UI framework designed for building fast, GPU-rendered applications on macOS. It uses Metal for rendering and integrates deeply with macOS system APIs.

> ⚠️ **Early Development**: This project is in its initial stages. Currently macOS-only, with plans for cross-platform support.

## Features

- **Metal-Powered Rendering** - Hardware-accelerated rendering with MSAA anti-aliasing
- **CVDisplayLink VSync** - Smooth 60Hz+ frame-paced rendering
- **Text Rendering** - CoreText-based font loading, shaping, and glyph caching
- **Scene Graph** - Collect draw commands (quads, shadows, text) for efficient batched rendering
- **Objective-C Interop** - Clean Zig bindings via [zig-objc](https://github.com/mitchellh/zig-objc)

## Quick Start

### Prerequisites

- Zig 0.15.2+
- macOS 12.0+ (Metal required)
- Xcode Command Line Tools

### Build & Run

zig build run # Run the example
zig build test # Run tests

## Roadmap

### Phase 1: Foundation ✅

- [x] Objective-C runtime bindings
- [x] NSWindow + CAMetalLayer setup
- [x] CVDisplayLink vsync
- [x] Basic Metal rendering pipeline
- [x] MSAA anti-aliasing

### Phase 2: Rendering ✅

- [x] Quad rendering (rounded rectangles)
- [x] Shadow rendering (SDF blur)
- [x] Text rendering (CoreText + atlas)
- [x] Retina / scale factor support

### Phase 3: Interactivity 🚧

- [ ] Mouse input handling
- [ ] Keyboard input handling
- [ ] Event dispatch system
- [ ] Hit testing

### Phase 4: Layout System

- [ ] Flexbox layout (port/bind Taffy or Clay.h)
- [ ] Element abstraction
- [ ] View composition

## Inspiration

- **GPUI** - Zed's GPU UI framework
- **Ghostty** - Modern terminal with Zig Metal bindings
- **zig-objc** - Objective-C runtime bindings for Zig

## Architecture

```mermaid
graph TB
    subgraph Application
        App[App Context]
        Window[Window]
        Scene[Scene Graph]
    end

    subgraph Rendering
        Renderer[Metal Renderer]
        Text[Text Pipeline]
    end

    subgraph Text System
        TextSys[TextSystem]
        Cache[Glyph Cache]
        Atlas[Texture Atlas]
    end

    subgraph Platform [Platform - macOS]
        NSApp[NSApplication]
        NSWin[NSWindow]
        Metal[CAMetalLayer]
        DL[CVDisplayLink]
        GCD[GCD Dispatcher]
    end

    App --> Window
    App --> Scene
    Window --> Renderer
    Scene --> Renderer
    Renderer --> Text
    Text --> Atlas
    TextSys --> Cache
    Cache --> Atlas
    Window --> NSWin
    Window --> Metal
    Window --> DL
    Renderer --> Metal
```
