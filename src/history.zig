const std = @import("std");
const elements_mod = @import("elements.zig");
const Element = elements_mod.Element;
const scene_mod = @import("scene.zig");
const Scene = scene_mod.Scene;

pub const Snapshot = struct {
    elements: std.ArrayList(Element),
    next_id: u64,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        for (self.elements.items) |*el| {
            if (el.text) |t| {
                allocator.free(t);
            }
        }
        self.elements.deinit(allocator);
    }
};

fn deepCopyElements(allocator: std.mem.Allocator, source: []const Element) !std.ArrayList(Element) {
    var list: std.ArrayList(Element) = .{};
    errdefer {
        for (list.items) |*el| {
            if (el.text) |t| allocator.free(t);
        }
        list.deinit(allocator);
    }
    for (source) |el| {
        var copy = el;
        if (el.text) |t| {
            copy.text = try allocator.dupe(u8, t);
        }
        try list.append(allocator, copy);
    }
    return list;
}

fn takeSnapshot(allocator: std.mem.Allocator, scene: *Scene) !Snapshot {
    return .{
        .elements = try deepCopyElements(allocator, scene.elements.items),
        .next_id = scene.next_id,
    };
}

fn restoreSnapshot(allocator: std.mem.Allocator, scene: *Scene, snap: Snapshot) void {
    // Free current
    for (scene.elements.items) |*el| {
        if (el.text) |t| allocator.free(t);
    }
    scene.elements.deinit(allocator);

    scene.elements = deepCopyElements(allocator, snap.elements.items) catch .{};
    scene.next_id = snap.next_id;
}

pub const History = struct {
    undo_stack: std.ArrayList(Snapshot),
    redo_stack: std.ArrayList(Snapshot),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) History {
        return .{
            .undo_stack = .{},
            .redo_stack = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.undo_stack.items) |*s| s.deinit(self.allocator);
        self.undo_stack.deinit(self.allocator);
        for (self.redo_stack.items) |*s| s.deinit(self.allocator);
        self.redo_stack.deinit(self.allocator);
    }

    pub fn pushSnapshot(self: *History, scene: *Scene) !void {
        const snap = try takeSnapshot(self.allocator, scene);
        try self.undo_stack.append(self.allocator, snap);

        // Clear redo
        for (self.redo_stack.items) |*s| s.deinit(self.allocator);
        self.redo_stack.clearRetainingCapacity();

        // Cap at 50
        while (self.undo_stack.items.len > 50) {
            var old = self.undo_stack.orderedRemove(0);
            old.deinit(self.allocator);
        }
    }

    pub fn undo(self: *History, scene: *Scene) bool {
        if (self.undo_stack.items.len == 0) return false;

        // Save current to redo
        const current = takeSnapshot(self.allocator, scene) catch return false;
        self.redo_stack.append(self.allocator, current) catch return false;

        // Restore from undo
        var snap = self.undo_stack.pop() orelse return false;
        restoreSnapshot(self.allocator, scene, snap);
        snap.deinit(self.allocator);
        return true;
    }

    pub fn redo(self: *History, scene: *Scene) bool {
        if (self.redo_stack.items.len == 0) return false;

        // Save current to undo
        const current = takeSnapshot(self.allocator, scene) catch return false;
        self.undo_stack.append(self.allocator, current) catch return false;

        // Restore from redo
        var snap = self.redo_stack.pop() orelse return false;
        restoreSnapshot(self.allocator, scene, snap);
        snap.deinit(self.allocator);
        return true;
    }
};
