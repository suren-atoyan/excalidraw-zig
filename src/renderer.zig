const rl = @import("raylib");
const elements_mod = @import("elements.zig");
const Element = elements_mod.Element;
const FillStyle = elements_mod.FillStyle;
const canvas_mod = @import("canvas.zig");
const Canvas = canvas_mod.Canvas;
const roughness = @import("roughness.zig");
const selection_mod = @import("selection.zig");
const scene_mod = @import("scene.zig");
const Scene = scene_mod.Scene;
const std = @import("std");

pub fn drawElement(element: Element, canvas: Canvas, font: rl.Font, selected: bool) void {
    _ = selected;
    const color = element.stroke_color.toRaylibColor();
    const thick = element.stroke_width.toFloat();

    switch (element.kind) {
        .rectangle => {
            const bb = element.getBoundingBox();
            // Fill
            switch (element.fill_style) {
                .solid => {
                    const tl = canvas.worldToScreen(bb[0], bb[1]);
                    const br = canvas.worldToScreen(bb[0] + bb[2], bb[1] + bb[3]);
                    const fill_color = rl.Color.init(color.r, color.g, color.b, 40);
                    rl.drawRectangleRec(rl.Rectangle.init(tl[0], tl[1], br[0] - tl[0], br[1] - tl[1]), fill_color);
                },
                .crosshatch => {
                    roughness.fillCrosshatch(bb[0], bb[1], bb[2], bb[3], canvas, color);
                },
                .none => {},
            }
            roughness.wobbleRect(element.seed, bb[0], bb[1], bb[2], bb[3], canvas, color, thick);
        },
        .ellipse => {
            const bb = element.getBoundingBox();
            const cx = bb[0] + bb[2] / 2.0;
            const cy = bb[1] + bb[3] / 2.0;
            const rx = bb[2] / 2.0;
            const ry = bb[3] / 2.0;
            // Fill
            switch (element.fill_style) {
                .solid => {
                    const sp = canvas.worldToScreen(cx, cy);
                    const fill_color = rl.Color.init(color.r, color.g, color.b, 40);
                    rl.drawEllipseV(
                        rl.Vector2.init(sp[0], sp[1]),
                        rx * canvas.zoom,
                        ry * canvas.zoom,
                        fill_color,
                    );
                },
                .crosshatch => {
                    roughness.fillCrosshatch(bb[0], bb[1], bb[2], bb[3], canvas, color);
                },
                .none => {},
            }
            roughness.wobbleEllipse(element.seed, cx, cy, rx, ry, canvas, color, thick);
        },
        .line => {
            if (element.points) |pts| {
                const x1 = element.x + pts[0][0];
                const y1 = element.y + pts[0][1];
                const x2 = element.x + pts[1][0];
                const y2 = element.y + pts[1][1];
                roughness.wobbleLine(element.seed, x1, y1, x2, y2, canvas, color, thick);
            }
        },
        .arrow => {
            if (element.points) |pts| {
                const x1 = element.x + pts[0][0];
                const y1 = element.y + pts[0][1];
                const x2 = element.x + pts[1][0];
                const y2 = element.y + pts[1][1];
                roughness.wobbleLine(element.seed, x1, y1, x2, y2, canvas, color, thick);

                // Arrowhead
                const dx = x2 - x1;
                const dy = y2 - y1;
                const len = @sqrt(dx * dx + dy * dy);
                if (len > 1.0) {
                    const arrow_len: f32 = 16.0;
                    const arrow_angle: f32 = 0.5;
                    const ux = dx / len;
                    const uy = dy / len;
                    const cos_a = @cos(arrow_angle);
                    const sin_a = @sin(arrow_angle);

                    const lx = x2 - arrow_len * (ux * cos_a - uy * sin_a);
                    const ly = y2 - arrow_len * (uy * cos_a + ux * sin_a);
                    const rx_pt = x2 - arrow_len * (ux * cos_a + uy * sin_a);
                    const ry_pt = y2 - arrow_len * (uy * cos_a - ux * sin_a);

                    const sp2 = canvas.worldToScreen(x2, y2);
                    const sl = canvas.worldToScreen(lx, ly);
                    const sr = canvas.worldToScreen(rx_pt, ry_pt);
                    rl.drawTriangle(
                        rl.Vector2.init(sp2[0], sp2[1]),
                        rl.Vector2.init(sl[0], sl[1]),
                        rl.Vector2.init(sr[0], sr[1]),
                        color,
                    );
                }
            }
        },
        .text => {
            if (element.text) |txt| {
                if (txt.len > 0) {
                    const sp = canvas.worldToScreen(element.x, element.y);
                    const font_size: f32 = 20.0 * canvas.zoom;
                    // We need a null-terminated string
                    var buf: [513]u8 = undefined;
                    const copy_len = @min(txt.len, 512);
                    @memcpy(buf[0..copy_len], txt[0..copy_len]);
                    buf[copy_len] = 0;
                    const z_text: [:0]const u8 = buf[0..copy_len :0];
                    rl.drawTextEx(font, z_text, rl.Vector2.init(sp[0], sp[1]), font_size, 1.0, color);
                }
            }
        },
    }
}

pub fn drawScene(scene: *Scene, canvas: Canvas, font: rl.Font) void {
    for (scene.elements.items) |el| {
        drawElement(el, canvas, font, false);
    }
}

pub fn drawSelectionHighlight(element: Element, canvas: Canvas) void {
    selection_mod.drawHandles(element, canvas);
}
