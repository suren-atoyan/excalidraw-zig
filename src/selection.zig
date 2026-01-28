const rl = @import("raylib");
const elements_mod = @import("elements.zig");
const Element = elements_mod.Element;
const canvas_mod = @import("canvas.zig");
const Canvas = canvas_mod.Canvas;

pub const Handle = enum {
    top_left,
    top,
    top_right,
    right,
    bottom_right,
    bottom,
    bottom_left,
    left,
};

pub const Selection = struct {
    element_id: u64,
    active_handle: ?Handle = null,
};

pub fn getHandles(element: Element) [8][2]f32 {
    const bb = element.getBoundingBox();
    const x = bb[0];
    const y = bb[1];
    const w = bb[2];
    const h = bb[3];
    const mx = x + w / 2.0;
    const my = y + h / 2.0;

    return .{
        .{ x, y }, // top_left
        .{ mx, y }, // top
        .{ x + w, y }, // top_right
        .{ x + w, my }, // right
        .{ x + w, y + h }, // bottom_right
        .{ mx, y + h }, // bottom
        .{ x, y + h }, // bottom_left
        .{ x, my }, // left
    };
}

pub fn hitTestHandle(element: Element, canvas: Canvas, sx: f32, sy: f32) ?Handle {
    const handles = getHandles(element);
    const handle_enums = [_]Handle{
        .top_left, .top, .top_right, .right,
        .bottom_right, .bottom, .bottom_left, .left,
    };
    const size: f32 = 8.0;
    for (handles, 0..) |h, i| {
        const sp = canvas.worldToScreen(h[0], h[1]);
        if (sx >= sp[0] - size / 2.0 and sx <= sp[0] + size / 2.0 and
            sy >= sp[1] - size / 2.0 and sy <= sp[1] + size / 2.0)
        {
            return handle_enums[i];
        }
    }
    return null;
}

pub fn drawHandles(element: Element, canvas: Canvas) void {
    const handles = getHandles(element);
    const size: f32 = 8.0;
    const color = rl.Color.init(28, 126, 214, 255);

    // Draw bounding box
    const bb = element.getBoundingBox();
    const tl = canvas.worldToScreen(bb[0], bb[1]);
    const br = canvas.worldToScreen(bb[0] + bb[2], bb[1] + bb[3]);
    const w = br[0] - tl[0];
    const h = br[1] - tl[1];
    if (w > 0 and h > 0) {
        rl.drawRectangleLinesEx(rl.Rectangle.init(tl[0], tl[1], w, h), 1.0, color);
    }

    for (handles) |hpos| {
        const sp = canvas.worldToScreen(hpos[0], hpos[1]);
        rl.drawRectangleRec(
            rl.Rectangle.init(sp[0] - size / 2.0, sp[1] - size / 2.0, size, size),
            rl.Color.white,
        );
        rl.drawRectangleLinesEx(
            rl.Rectangle.init(sp[0] - size / 2.0, sp[1] - size / 2.0, size, size),
            1.0,
            color,
        );
    }
}

pub fn applyResize(element: *Element, handle: Handle, dx: f32, dy: f32) void {
    switch (handle) {
        .top_left => {
            element.x += dx;
            element.y += dy;
            element.width -= dx;
            element.height -= dy;
        },
        .top => {
            element.y += dy;
            element.height -= dy;
        },
        .top_right => {
            element.width += dx;
            element.y += dy;
            element.height -= dy;
        },
        .right => {
            element.width += dx;
        },
        .bottom_right => {
            element.width += dx;
            element.height += dy;
        },
        .bottom => {
            element.height += dy;
        },
        .bottom_left => {
            element.x += dx;
            element.width -= dx;
            element.height += dy;
        },
        .left => {
            element.x += dx;
            element.width -= dx;
        },
    }
}

pub fn hitTestElements(elements: []Element, px: f32, py: f32) ?u64 {
    // Iterate in reverse to find topmost element first
    var i = elements.len;
    while (i > 0) {
        i -= 1;
        if (elements[i].containsPoint(px, py)) {
            return elements[i].id;
        }
    }
    return null;
}
