const std = @import("std");
const elements_mod = @import("elements.zig");
const Element = elements_mod.Element;
const ElementKind = elements_mod.ElementKind;
const FillStyle = elements_mod.FillStyle;
const StrokeWidth = elements_mod.StrokeWidth;
const ColorKind = elements_mod.ColorKind;

pub const Scene = struct {
    elements: std.ArrayList(Element),
    next_id: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Scene {
        return .{
            .elements = .{},
            .next_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scene) void {
        for (self.elements.items) |*el| {
            if (el.text) |t| {
                self.allocator.free(t);
            }
        }
        self.elements.deinit(self.allocator);
    }

    pub fn addElement(self: *Scene, element: Element) !*Element {
        var el = element;
        el.id = self.next_id;
        self.next_id += 1;
        try self.elements.append(self.allocator, el);
        return &self.elements.items[self.elements.items.len - 1];
    }

    pub fn removeElement(self: *Scene, id: u64) void {
        for (self.elements.items, 0..) |*el, i| {
            if (el.id == id) {
                if (el.text) |t| {
                    self.allocator.free(t);
                }
                _ = self.elements.orderedRemove(i);
                return;
            }
        }
    }

    pub fn getElementById(self: *Scene, id: u64) ?*Element {
        for (self.elements.items) |*el| {
            if (el.id == id) return el;
        }
        return null;
    }

    const JsonElement = struct {
        id: u64,
        kind: []const u8,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        strokeColor: []const u8,
        fillStyle: []const u8,
        strokeWidth: []const u8,
        seed: u32,
        text: ?[]const u8 = null,
        points_0_0: ?f32 = null,
        points_0_1: ?f32 = null,
        points_1_0: ?f32 = null,
        points_1_1: ?f32 = null,
    };

    const JsonDoc = struct {
        version: u32,
        elements: []const JsonElement,
    };

    pub fn serialize(self: *Scene, allocator: std.mem.Allocator) ![]const u8 {
        var json_els: std.ArrayList(JsonElement) = .{};
        defer json_els.deinit(allocator);

        for (self.elements.items) |el| {
            var je = JsonElement{
                .id = el.id,
                .kind = @tagName(el.kind),
                .x = el.x,
                .y = el.y,
                .width = el.width,
                .height = el.height,
                .strokeColor = @tagName(el.stroke_color),
                .fillStyle = @tagName(el.fill_style),
                .strokeWidth = @tagName(el.stroke_width),
                .seed = el.seed,
                .text = el.text,
            };
            if (el.points) |pts| {
                je.points_0_0 = pts[0][0];
                je.points_0_1 = pts[0][1];
                je.points_1_0 = pts[1][0];
                je.points_1_1 = pts[1][1];
            }
            try json_els.append(allocator, je);
        }

        const doc = JsonDoc{
            .version = 1,
            .elements = json_els.items,
        };

        return try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(doc, .{})});
    }

    pub fn deserialize(allocator: std.mem.Allocator, json: []const u8) !Scene {
        const parsed = try std.json.parseFromSlice(JsonDoc, allocator, json, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        var scene = Scene.init(allocator);
        errdefer scene.deinit();

        for (parsed.value.elements) |je| {
            var el = Element{
                .id = je.id,
                .kind = std.meta.stringToEnum(ElementKind, je.kind) orelse .rectangle,
                .x = je.x,
                .y = je.y,
                .width = je.width,
                .height = je.height,
                .stroke_color = std.meta.stringToEnum(ColorKind, je.strokeColor) orelse .black,
                .fill_style = std.meta.stringToEnum(FillStyle, je.fillStyle) orelse .none,
                .stroke_width = std.meta.stringToEnum(StrokeWidth, je.strokeWidth) orelse .normal,
                .seed = je.seed,
            };
            if (je.text) |t| {
                el.text = try allocator.dupe(u8, t);
            }
            if (je.points_0_0) |p00| {
                el.points = .{
                    .{ p00, je.points_0_1 orelse 0 },
                    .{ je.points_1_0 orelse 0, je.points_1_1 orelse 0 },
                };
            }
            if (el.id >= scene.next_id) scene.next_id = el.id + 1;
            try scene.elements.append(allocator, el);
        }

        return scene;
    }
};
