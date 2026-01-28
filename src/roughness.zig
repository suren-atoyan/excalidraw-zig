const rl = @import("raylib");
const canvas_mod = @import("canvas.zig");
const Canvas = canvas_mod.Canvas;
const std = @import("std");

pub const SimpleRng = struct {
    state: u32,

    pub fn init(seed: u32) SimpleRng {
        return .{ .state = if (seed == 0) 1 else seed };
    }

    pub fn next(self: *SimpleRng) u32 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.state = x;
        return x;
    }

    pub fn nextFloat(self: *SimpleRng) f32 {
        return @as(f32, @floatFromInt(self.next() & 0x7FFFFF)) / @as(f32, 0x7FFFFF);
    }
};

pub fn wobbleLine(seed: u32, x1: f32, y1: f32, x2: f32, y2: f32, canvas: Canvas, color: rl.Color, thickness: f32) void {
    var rng = SimpleRng.init(seed);

    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = @sqrt(dx * dx + dy * dy);
    const wobble_amount: f32 = 2.0;

    // Perpendicular direction
    var px: f32 = 0;
    var py: f32 = 0;
    if (len > 0.001) {
        px = -dy / len;
        py = dx / len;
    }

    // 5 points: start, 3 midpoints, end
    var points: [5][2]f32 = undefined;
    points[0] = .{ x1, y1 };
    points[4] = .{ x2, y2 };

    for (1..4) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / 4.0;
        const offset = (rng.nextFloat() - 0.5) * 2.0 * wobble_amount;
        points[i] = .{
            x1 + dx * t + px * offset,
            y1 + dy * t + py * offset,
        };
    }

    // Draw segments
    for (0..4) |i| {
        const s = canvas.worldToScreen(points[i][0], points[i][1]);
        const e = canvas.worldToScreen(points[i + 1][0], points[i + 1][1]);
        rl.drawLineEx(
            rl.Vector2.init(s[0], s[1]),
            rl.Vector2.init(e[0], e[1]),
            thickness * canvas.zoom,
            color,
        );
    }
}

pub fn wobbleRect(seed: u32, x: f32, y: f32, w: f32, h: f32, canvas: Canvas, color: rl.Color, thickness: f32) void {
    wobbleLine(seed, x, y, x + w, y, canvas, color, thickness);
    wobbleLine(seed +% 111, x + w, y, x + w, y + h, canvas, color, thickness);
    wobbleLine(seed +% 222, x + w, y + h, x, y + h, canvas, color, thickness);
    wobbleLine(seed +% 333, x, y + h, x, y, canvas, color, thickness);
}

pub fn wobbleEllipse(seed: u32, cx: f32, cy: f32, rx: f32, ry: f32, canvas: Canvas, color: rl.Color, thickness: f32) void {
    var rng = SimpleRng.init(seed);
    const segments: usize = 32;
    const wobble_amount: f32 = 2.0;

    var prev_sx: f32 = 0;
    var prev_sy: f32 = 0;

    for (0..segments + 1) |i| {
        const angle = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments)) * std.math.pi * 2.0;
        const offset = (rng.nextFloat() - 0.5) * 2.0 * wobble_amount;
        const wx = cx + (rx + offset) * @cos(angle);
        const wy = cy + (ry + offset) * @sin(angle);
        const sp = canvas.worldToScreen(wx, wy);

        if (i > 0) {
            rl.drawLineEx(
                rl.Vector2.init(prev_sx, prev_sy),
                rl.Vector2.init(sp[0], sp[1]),
                thickness * canvas.zoom,
                color,
            );
        }
        prev_sx = sp[0];
        prev_sy = sp[1];
    }
}

pub fn fillCrosshatch(x: f32, y: f32, w: f32, h: f32, canvas: Canvas, color: rl.Color) void {
    const spacing: f32 = 8.0;
    const fill_color = rl.Color.init(color.r, color.g, color.b, 60);
    var offset: f32 = 0;
    while (offset < w + h) : (offset += spacing) {
        // Diagonal lines from top-left to bottom-right
        const lx1 = x + @min(offset, w);
        const ly1 = y + @max(0, offset - w);
        const lx2 = x + @max(0, offset - h);
        const ly2 = y + @min(offset, h);
        const s1 = canvas.worldToScreen(lx1, ly1);
        const s2 = canvas.worldToScreen(lx2, ly2);
        rl.drawLineV(rl.Vector2.init(s1[0], s1[1]), rl.Vector2.init(s2[0], s2[1]), fill_color);
    }
}
