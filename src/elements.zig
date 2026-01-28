const std = @import("std");
const rl = @import("raylib");

pub const ElementKind = enum {
    rectangle,
    ellipse,
    line,
    arrow,
    text,
};

pub const FillStyle = enum {
    none,
    solid,
    crosshatch,
};

pub const StrokeWidth = enum {
    thin,
    normal,
    bold,

    pub fn toFloat(self: StrokeWidth) f32 {
        return switch (self) {
            .thin => 1.0,
            .normal => 2.0,
            .bold => 4.0,
        };
    }
};

pub const ColorKind = enum {
    black,
    red,
    blue,
    green,
    orange,
    white,

    pub fn toRaylibColor(self: ColorKind) rl.Color {
        return switch (self) {
            .black => rl.Color.init(30, 30, 30, 255),
            .red => rl.Color.init(224, 49, 49, 255),
            .blue => rl.Color.init(28, 126, 214, 255),
            .green => rl.Color.init(47, 158, 68, 255),
            .orange => rl.Color.init(232, 141, 26, 255),
            .white => rl.Color.init(255, 255, 255, 255),
        };
    }
};

pub const Element = struct {
    id: u64,
    kind: ElementKind,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    stroke_color: ColorKind = .black,
    fill_style: FillStyle = .none,
    stroke_width: StrokeWidth = .normal,
    text: ?[]const u8 = null,
    seed: u32 = 42,
    points: ?[2][2]f32 = null,

    pub fn getBoundingBox(self: Element) [4]f32 {
        switch (self.kind) {
            .line, .arrow => {
                if (self.points) |pts| {
                    const x1 = self.x + pts[0][0];
                    const y1 = self.y + pts[0][1];
                    const x2 = self.x + pts[1][0];
                    const y2 = self.y + pts[1][1];
                    const min_x = @min(x1, x2);
                    const min_y = @min(y1, y2);
                    const max_x = @max(x1, x2);
                    const max_y = @max(y1, y2);
                    return .{ min_x, min_y, max_x - min_x, max_y - min_y };
                }
                return .{ self.x, self.y, self.width, self.height };
            },
            else => {
                const w = if (self.width < 0) -self.width else self.width;
                const h = if (self.height < 0) -self.height else self.height;
                const x = if (self.width < 0) self.x + self.width else self.x;
                const y = if (self.height < 0) self.y + self.height else self.y;
                return .{ x, y, w, h };
            },
        }
    }

    pub fn containsPoint(self: Element, px: f32, py: f32) bool {
        switch (self.kind) {
            .rectangle, .text => {
                const bb = self.getBoundingBox();
                const margin: f32 = 5.0;
                return px >= bb[0] - margin and px <= bb[0] + bb[2] + margin and
                    py >= bb[1] - margin and py <= bb[1] + bb[3] + margin;
            },
            .ellipse => {
                const bb = self.getBoundingBox();
                const cx = bb[0] + bb[2] / 2.0;
                const cy = bb[1] + bb[3] / 2.0;
                const rx = bb[2] / 2.0 + 5.0;
                const ry = bb[3] / 2.0 + 5.0;
                if (rx <= 0 or ry <= 0) return false;
                const dx = (px - cx) / rx;
                const dy = (py - cy) / ry;
                return dx * dx + dy * dy <= 1.0;
            },
            .line, .arrow => {
                if (self.points) |pts| {
                    const x1 = self.x + pts[0][0];
                    const y1 = self.y + pts[0][1];
                    const x2 = self.x + pts[1][0];
                    const y2 = self.y + pts[1][1];
                    return pointToSegmentDist(px, py, x1, y1, x2, y2) < 10.0;
                }
                return false;
            },
        }
    }
};

pub fn pointToSegmentDist(px: f32, py: f32, x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len_sq = dx * dx + dy * dy;
    if (len_sq < 0.001) {
        const ex = px - x1;
        const ey = py - y1;
        return @sqrt(ex * ex + ey * ey);
    }
    var t = ((px - x1) * dx + (py - y1) * dy) / len_sq;
    t = @max(0, @min(1, t));
    const proj_x = x1 + t * dx;
    const proj_y = y1 + t * dy;
    const ex = px - proj_x;
    const ey = py - proj_y;
    return @sqrt(ex * ex + ey * ey);
}
