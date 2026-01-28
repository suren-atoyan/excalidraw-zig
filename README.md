# Excalidraw-Zig

A lightweight [Excalidraw](https://excalidraw.com)-inspired drawing app built with Zig and raylib.

## Features

- Rectangle, ellipse, circle, line, arrow, and text tools
- Hand-drawn/sketchy rendering style
- Select, move, and resize elements with handles
- Color, fill style, and stroke width properties
- Pan (middle-mouse or space+drag) and zoom (scroll wheel, +/- keys)
- Double-click anywhere to create a text box
- Undo/redo (Ctrl+Z / Ctrl+Shift+Z)
- Save to JSON (Ctrl+S)

## Build & Run

Requires [Zig 0.15+](https://ziglang.org/download/).

```
zig build run
```

## Keyboard Shortcuts

| Key              | Action          |
| ---------------- | --------------- |
| 1 / V            | Select tool     |
| 2 / R            | Rectangle       |
| 3 / D            | Diamond         |
| 4 / E            | Ellipse         |
| 5 / A            | Arrow           |
| 6 / L            | Line            |
| 7 / T            | Text            |
| +/-              | Zoom in/out     |
| Ctrl+Z           | Undo            |
| Ctrl+Shift+Z     | Redo            |
| Delete/Backspace | Delete selected |
| Double-click     | Create text box |
