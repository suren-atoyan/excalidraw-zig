const rl = @import("raylib");
const tools_mod = @import("tools.zig");
const ToolKind = tools_mod.ToolKind;
const properties_mod = @import("properties.zig");
const ElementProps = properties_mod.ElementProps;
const elements_mod = @import("elements.zig");
const ColorKind = elements_mod.ColorKind;
const FillStyle = elements_mod.FillStyle;
const StrokeWidth = elements_mod.StrokeWidth;
const std = @import("std");

fn drawSelectIcon(cx: f32, cy: f32, color: rl.Color) void {
    // Arrow/pointer cursor icon — draw as lines for reliability
    const tip_x = cx - 4;
    const tip_y = cy - 10;
    // Left edge
    rl.drawLineEx(rl.Vector2.init(tip_x, tip_y), rl.Vector2.init(tip_x, tip_y + 16), 2, color);
    // Bottom-left to tip
    rl.drawLineEx(rl.Vector2.init(tip_x, tip_y + 16), rl.Vector2.init(tip_x + 4, tip_y + 12), 2, color);
    // Small tail
    rl.drawLineEx(rl.Vector2.init(tip_x + 4, tip_y + 12), rl.Vector2.init(tip_x + 8, tip_y + 16), 2, color);
    // Right side back
    rl.drawLineEx(rl.Vector2.init(tip_x + 8, tip_y + 16), rl.Vector2.init(tip_x + 5, tip_y + 11), 2, color);
    // Right edge to tip
    rl.drawLineEx(rl.Vector2.init(tip_x + 5, tip_y + 11), rl.Vector2.init(tip_x + 12, tip_y + 9), 2, color);
    // Close back to top
    rl.drawLineEx(rl.Vector2.init(tip_x + 12, tip_y + 9), rl.Vector2.init(tip_x, tip_y), 2, color);
}

fn drawRectIcon(cx: f32, cy: f32, color: rl.Color) void {
    rl.drawRectangleLinesEx(rl.Rectangle.init(cx - 9, cy - 7, 18, 14), 2, color);
}

fn drawEllipseIcon(cx: f32, cy: f32, color: rl.Color) void {
    // Diamond/rhombus shape like excalidraw
    const s: f32 = 9;
    rl.drawLineEx(rl.Vector2.init(cx, cy - s), rl.Vector2.init(cx + s, cy), 2, color);
    rl.drawLineEx(rl.Vector2.init(cx + s, cy), rl.Vector2.init(cx, cy + s), 2, color);
    rl.drawLineEx(rl.Vector2.init(cx, cy + s), rl.Vector2.init(cx - s, cy), 2, color);
    rl.drawLineEx(rl.Vector2.init(cx - s, cy), rl.Vector2.init(cx, cy - s), 2, color);
}

fn drawCircleIcon(cx: f32, cy: f32, color: rl.Color) void {
    // Draw a circle outline using line segments
    const segments: u32 = 24;
    const r: f32 = 9;
    var i: u32 = 0;
    while (i < segments) : (i += 1) {
        const a1 = @as(f32, @floatFromInt(i)) * std.math.tau / @as(f32, @floatFromInt(segments));
        const a2 = @as(f32, @floatFromInt(i + 1)) * std.math.tau / @as(f32, @floatFromInt(segments));
        rl.drawLineEx(
            rl.Vector2.init(cx + r * @cos(a1), cy + r * @sin(a1)),
            rl.Vector2.init(cx + r * @cos(a2), cy + r * @sin(a2)),
            2,
            color,
        );
    }
}

fn drawArrowIcon(cx: f32, cy: f32, color: rl.Color) void {
    // Arrow line with arrowhead
    const x1 = cx - 10;
    const y1 = cy + 5;
    const x2 = cx + 8;
    const y2 = cy - 5;
    rl.drawLineEx(rl.Vector2.init(x1, y1), rl.Vector2.init(x2, y2), 2, color);
    // Arrowhead
    rl.drawLineEx(rl.Vector2.init(x2, y2), rl.Vector2.init(x2 - 6, y2 + 1), 2, color);
    rl.drawLineEx(rl.Vector2.init(x2, y2), rl.Vector2.init(x2 - 1, y2 + 6), 2, color);
}

fn drawLineIcon(cx: f32, cy: f32, color: rl.Color) void {
    rl.drawLineEx(rl.Vector2.init(cx - 10, cy + 6), rl.Vector2.init(cx + 10, cy - 6), 2, color);
}

fn drawTextIcon(cx: f32, cy: f32, color: rl.Color) void {
    // Capital A
    const top_x = cx;
    const top_y = cy - 9;
    const bot_l = cx - 7;
    const bot_r = cx + 7;
    const bot_y = cy + 9;
    rl.drawLineEx(rl.Vector2.init(top_x, top_y), rl.Vector2.init(bot_l, bot_y), 2, color);
    rl.drawLineEx(rl.Vector2.init(top_x, top_y), rl.Vector2.init(bot_r, bot_y), 2, color);
    // Crossbar
    const mid_y = cy + 2;
    rl.drawLineEx(rl.Vector2.init(cx - 4, mid_y), rl.Vector2.init(cx + 4, mid_y), 2, color);
}

pub fn drawToolbar(active_tool: ToolKind, screen_width: i32, _font: rl.Font) ?ToolKind {
    _ = _font;
    const sw: f32 = @floatFromInt(screen_width);
    const bar_h: f32 = 50;
    const btn_w: f32 = 40;
    const btn_h: f32 = 40;
    const gap: f32 = 2;
    const tool_count: f32 = 7;
    const total_w = tool_count * btn_w + (tool_count - 1) * gap;
    const start_x = (sw - total_w) / 2.0;
    const bar_y: f32 = 8;

    // Bar background - rounded rectangle with shadow
    const bar_rect = rl.Rectangle.init(start_x - 10, bar_y - 4, total_w + 20, bar_h);
    rl.drawRectangleRec(bar_rect, rl.Color.init(255, 255, 255, 245));
    rl.drawRectangleLinesEx(bar_rect, 1, rl.Color.init(210, 210, 210, 255));

    const tool_kinds = [_]ToolKind{ .select, .rectangle, .ellipse, .circle_shape, .arrow, .line, .text };

    var result: ?ToolKind = null;
    const mouse = rl.getMousePosition();
    const clicked = rl.isMouseButtonPressed(.left);

    for (0..7) |i| {
        const fi: f32 = @floatFromInt(i);
        const bx = start_x + fi * (btn_w + gap);
        const by = bar_y;
        const is_active = active_tool == tool_kinds[i];

        // Check hover
        const hovered = mouse.x >= bx and mouse.x <= bx + btn_w and mouse.y >= by and mouse.y <= by + btn_h;

        const bg = if (is_active)
            rl.Color.init(83, 101, 235, 255) // Excalidraw purple-blue
        else if (hovered)
            rl.Color.init(236, 236, 244, 255)
        else
            rl.Color.init(255, 255, 255, 0);
        const fg = if (is_active) rl.Color.white else rl.Color.init(50, 50, 50, 255);

        // Rounded button background
        rl.drawRectangleRec(rl.Rectangle.init(bx + 2, by + 2, btn_w - 4, btn_h - 4), bg);

        // Draw icon
        const icon_cx = bx + btn_w / 2.0;
        const icon_cy = by + btn_h / 2.0;

        switch (tool_kinds[i]) {
            .select => drawSelectIcon(icon_cx, icon_cy, fg),
            .rectangle => drawRectIcon(icon_cx, icon_cy, fg),
            .ellipse => drawEllipseIcon(icon_cx, icon_cy, fg),
            .circle_shape => drawCircleIcon(icon_cx, icon_cy, fg),
            .arrow => drawArrowIcon(icon_cx, icon_cy, fg),
            .line => drawLineIcon(icon_cx, icon_cy, fg),
            .text => drawTextIcon(icon_cx, icon_cy, fg),
        }

        // Keyboard shortcut number
        const num_str: [:0]const u8 = switch (i) {
            0 => "1",
            1 => "2",
            2 => "3",
            3 => "4",
            4 => "5",
            5 => "6",
            6 => "7",
            else => "",
        };
        const num_color = if (is_active) rl.Color.init(200, 200, 255, 200) else rl.Color.init(160, 160, 160, 200);
        rl.drawTextEx(rl.getFontDefault() catch unreachable, num_str, rl.Vector2.init(bx + btn_w - 10, by + btn_h - 12), 10, 0, num_color);

        if (clicked and hovered) {
            result = tool_kinds[i];
        }
    }

    return result;
}

pub fn drawPropertyBar(props: *ElementProps, screen_width: i32, screen_height: i32, font: rl.Font) bool {
    const sw: f32 = @floatFromInt(screen_width);
    const sh: f32 = @floatFromInt(screen_height);
    const bar_h: f32 = 44;
    const bar_y = sh - bar_h;
    var changed = false;

    // Background
    rl.drawRectangleRec(rl.Rectangle.init(0, bar_y, sw, bar_h), rl.Color.init(255, 255, 255, 245));
    rl.drawRectangleLinesEx(rl.Rectangle.init(0, bar_y, sw, bar_h), 1, rl.Color.init(210, 210, 210, 255));

    const mouse = rl.getMousePosition();
    const clicked = rl.isMouseButtonPressed(.left);

    // Color swatches
    var cx: f32 = 16;
    const cy = bar_y + bar_h / 2.0;
    for (properties_mod.color_options) |c| {
        const col = c.toRaylibColor();
        const is_sel = props.color == c;
        const r: f32 = if (is_sel) 12 else 10;
        rl.drawCircleV(rl.Vector2.init(cx, cy), r, col);
        if (is_sel) {
            rl.drawCircleV(rl.Vector2.init(cx, cy), r + 2, rl.Color.init(83, 101, 235, 80));
        }
        if (clicked) {
            const ddx = mouse.x - cx;
            const ddy = mouse.y - cy;
            if (ddx * ddx + ddy * ddy < 14 * 14) {
                props.color = c;
                changed = true;
            }
        }
        cx += 28;
    }

    // Fill style
    cx += 20;
    const fill_labels = [_][:0]const u8{ "No", "So", "Cr" };
    for (properties_mod.fill_options, 0..) |f, i| {
        const is_sel = props.fill_style == f;
        const bx = cx;
        const by = bar_y + 6;
        const bw: f32 = 32;
        const bh: f32 = 32;
        const bg = if (is_sel) rl.Color.init(83, 101, 235, 255) else rl.Color.init(255, 255, 255, 255);
        const fg = if (is_sel) rl.Color.white else rl.Color.init(30, 30, 30, 255);
        rl.drawRectangleRec(rl.Rectangle.init(bx, by, bw, bh), bg);
        rl.drawRectangleLinesEx(rl.Rectangle.init(bx, by, bw, bh), 1, rl.Color.init(180, 180, 180, 255));
        rl.drawTextEx(font, fill_labels[i], rl.Vector2.init(bx + 4, by + 8), 14, 1, fg);
        if (clicked and mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh) {
            props.fill_style = f;
            changed = true;
        }
        cx += bw + 4;
    }

    // Stroke width
    cx += 20;
    const sw_labels = [_][:0]const u8{ "Tn", "Nm", "Bd" };
    for (properties_mod.stroke_width_options, 0..) |s, i| {
        const is_sel = props.stroke_width == s;
        const bx = cx;
        const by = bar_y + 6;
        const bw: f32 = 32;
        const bh: f32 = 32;
        const bg = if (is_sel) rl.Color.init(83, 101, 235, 255) else rl.Color.init(255, 255, 255, 255);
        const fg = if (is_sel) rl.Color.white else rl.Color.init(30, 30, 30, 255);
        rl.drawRectangleRec(rl.Rectangle.init(bx, by, bw, bh), bg);
        rl.drawRectangleLinesEx(rl.Rectangle.init(bx, by, bw, bh), 1, rl.Color.init(180, 180, 180, 255));
        rl.drawTextEx(font, sw_labels[i], rl.Vector2.init(bx + 4, by + 8), 14, 1, fg);
        if (clicked and mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh) {
            props.stroke_width = s;
            changed = true;
        }
        cx += bw + 4;
    }

    return changed;
}
