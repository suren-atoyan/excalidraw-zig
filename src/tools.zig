const rl = @import("raylib");
const elements_mod = @import("elements.zig");
const Element = elements_mod.Element;
const ElementKind = elements_mod.ElementKind;
const selection_mod = @import("selection.zig");
const Handle = selection_mod.Handle;
const App = @import("app.zig").App;

pub const ToolKind = enum {
    select,
    rectangle,
    ellipse,
    circle_shape,
    line,
    arrow,
    text,
};

pub const ToolState = union(enum) {
    idle,
    drawing: struct {
        start_x: f32,
        start_y: f32,
        element_id: u64,
    },
    dragging: struct {
        element_id: u64,
        start_x: f32,
        start_y: f32,
        orig_x: f32,
        orig_y: f32,
    },
    resizing: struct {
        element_id: u64,
        handle: Handle,
        start_x: f32,
        start_y: f32,
        orig_x: f32,
        orig_y: f32,
        orig_w: f32,
        orig_h: f32,
    },
    typing: struct {
        element_id: u64,
    },
};

pub fn processInput(app: *App) void {
    const mouse_pos = rl.getMousePosition();
    const mx = mouse_pos.x;
    const my = mouse_pos.y;

    // Don't process if panning
    if (app.canvas.panning or app.canvas.space_held) return;

    // Don't process clicks on UI areas (top 58px toolbar, bottom 50px property bar)
    if (my < 58 or my > @as(f32, @floatFromInt(rl.getScreenHeight())) - 50) {
        if (app.tool_state == .idle) return;
    }

    const world = app.canvas.screenToWorld(mx, my);
    const wx = world[0];
    const wy = world[1];

    switch (app.tool_state) {
        .idle => processIdle(app, mx, my, wx, wy),
        .drawing => |d| processDrawing(app, wx, wy, d),
        .dragging => |d| processDragging(app, wx, wy, d),
        .resizing => |r| processResizing(app, wx, wy, r),
        .typing => |t| processTyping(app, t),
    }
}

fn startTextElement(app: *App, wx: f32, wy: f32) void {
    app.history.pushSnapshot(&app.scene) catch {};
    const el = Element{
        .id = 0,
        .kind = .text,
        .x = wx,
        .y = wy,
        .width = 100,
        .height = 24,
        .stroke_color = app.current_props.color,
        .fill_style = .none,
        .stroke_width = app.current_props.stroke_width,
        .text = null,
        .seed = @truncate(@as(u64, @intFromFloat(rl.getTime() * 100000))),
    };
    if (app.scene.addElement(el)) |added| {
        app.selection = added.id;
        app.text_input.start(null);
        app.tool_state = .{ .typing = .{ .element_id = added.id } };
    } else |_| {}
}

fn processIdle(app: *App, mx: f32, my: f32, wx: f32, wy: f32) void {
    // Double-click anywhere creates a text box (like excalidraw)
    if (app.detectDoubleClick()) {
        startTextElement(app, wx, wy);
        return;
    }

    switch (app.active_tool) {
        .select => {
            if (rl.isMouseButtonPressed(.left)) {
                // Check handles first if something is selected
                if (app.selection) |sel_id| {
                    if (app.scene.getElementById(sel_id)) |el| {
                        if (selection_mod.hitTestHandle(el.*, app.canvas, mx, my)) |handle| {
                            app.history.pushSnapshot(&app.scene) catch {};
                            app.tool_state = .{ .resizing = .{
                                .element_id = sel_id,
                                .handle = handle,
                                .start_x = wx,
                                .start_y = wy,
                                .orig_x = el.x,
                                .orig_y = el.y,
                                .orig_w = el.width,
                                .orig_h = el.height,
                            } };
                            return;
                        }
                    }
                }

                // Hit test elements
                if (selection_mod.hitTestElements(app.scene.elements.items, wx, wy)) |id| {
                    app.selection = id;
                    if (app.scene.getElementById(id)) |el| {
                        app.history.pushSnapshot(&app.scene) catch {};
                        app.tool_state = .{ .dragging = .{
                            .element_id = id,
                            .start_x = wx,
                            .start_y = wy,
                            .orig_x = el.x,
                            .orig_y = el.y,
                        } };
                    }
                } else {
                    app.selection = null;
                }
            }
        },
        .rectangle, .ellipse, .circle_shape, .line, .arrow => {
            if (rl.isMouseButtonPressed(.left)) {
                app.history.pushSnapshot(&app.scene) catch {};
                const kind: ElementKind = switch (app.active_tool) {
                    .rectangle => .rectangle,
                    .ellipse => .ellipse,
                    .circle_shape => .ellipse,
                    .line => .line,
                    .arrow => .arrow,
                    else => .rectangle,
                };
                var el = Element{
                    .id = 0,
                    .kind = kind,
                    .x = wx,
                    .y = wy,
                    .width = 0,
                    .height = 0,
                    .stroke_color = app.current_props.color,
                    .fill_style = app.current_props.fill_style,
                    .stroke_width = app.current_props.stroke_width,
                    .seed = @truncate(@as(u64, @intFromFloat(rl.getTime() * 100000))),
                };
                if (kind == .line or kind == .arrow) {
                    el.points = .{ .{ 0, 0 }, .{ 0, 0 } };
                }
                if (app.scene.addElement(el)) |added| {
                    app.tool_state = .{ .drawing = .{
                        .start_x = wx,
                        .start_y = wy,
                        .element_id = added.id,
                    } };
                    app.selection = added.id;
                } else |_| {}
            }
        },
        .text => {
            if (rl.isMouseButtonPressed(.left)) {
                startTextElement(app, wx, wy);
            }
        },
    }
}

fn processDrawing(app: *App, wx: f32, wy: f32, d: anytype) void {
    if (app.scene.getElementById(d.element_id)) |el| {
        if (el.kind == .line or el.kind == .arrow) {
            if (el.points != null) {
                el.points.?[1] = .{ wx - el.x, wy - el.y };
            }
        } else {
            // For circle_shape tool, constrain to square
            if (app.active_tool == .circle_shape) {
                const dx = wx - d.start_x;
                const dy = wy - d.start_y;
                const size = @max(@abs(dx), @abs(dy));
                el.width = if (dx >= 0) size else -size;
                el.height = if (dy >= 0) size else -size;
            } else {
                el.width = wx - d.start_x;
                el.height = wy - d.start_y;
            }
        }
    }

    if (rl.isMouseButtonReleased(.left)) {
        app.tool_state = .idle;
        // Auto-switch to select mode after drawing a shape (like Excalidraw)
        app.active_tool = .select;
    }
}

fn processDragging(app: *App, wx: f32, wy: f32, d: anytype) void {
    if (app.scene.getElementById(d.element_id)) |el| {
        el.x = d.orig_x + (wx - d.start_x);
        el.y = d.orig_y + (wy - d.start_y);
    }

    if (rl.isMouseButtonReleased(.left)) {
        app.tool_state = .idle;
    }
}

fn processResizing(app: *App, wx: f32, wy: f32, r: anytype) void {
    if (app.scene.getElementById(r.element_id)) |el| {
        el.x = r.orig_x;
        el.y = r.orig_y;
        el.width = r.orig_w;
        el.height = r.orig_h;
        const dx = wx - r.start_x;
        const dy = wy - r.start_y;
        selection_mod.applyResize(el, r.handle, dx, dy);
    }

    if (rl.isMouseButtonReleased(.left)) {
        app.tool_state = .idle;
    }
}

fn finishTyping(app: *App, element_id: u64) void {
    // Keep text if non-empty, remove element if empty
    const txt = app.text_input.getText();
    if (txt.len == 0) {
        if (app.scene.getElementById(element_id)) |el| {
            if (el.text) |old| {
                app.scene.allocator.free(old);
                el.text = null;
            }
        }
        app.scene.removeElement(element_id);
        app.selection = null;
    }
    app.text_input.active = false;
    app.tool_state = .idle;
}

fn processTyping(app: *App, t: anytype) void {
    // Click outside the text element finishes typing (like Excalidraw)
    if (rl.isMouseButtonPressed(.left)) {
        if (app.scene.getElementById(t.element_id)) |el| {
            const mouse = rl.getMousePosition();
            const world = app.canvas.screenToWorld(mouse.x, mouse.y);
            if (!el.containsPoint(world[0], world[1])) {
                finishTyping(app, t.element_id);
                return;
            }
        }
    }

    app.text_input.update();

    // Update element text live so it's visible while typing
    if (app.scene.getElementById(t.element_id)) |el| {
        const txt = app.text_input.getText();
        if (el.text) |old| {
            app.scene.allocator.free(old);
        }
        el.text = app.scene.allocator.dupe(u8, txt) catch null;
        // Update bounding box based on text
        if (txt.len > 0) {
            el.width = @max(100, @as(f32, @floatFromInt(txt.len)) * 12);
        }
    }

    if (app.text_input.isFinished()) {
        // Both Enter and Escape confirm the text (like Excalidraw)
        finishTyping(app, t.element_id);
    }
}
