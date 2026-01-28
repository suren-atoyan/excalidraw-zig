const std = @import("std");
const rl = @import("raylib");
const canvas_mod = @import("canvas.zig");
const Canvas = canvas_mod.Canvas;
const scene_mod = @import("scene.zig");
const Scene = scene_mod.Scene;
const tools_mod = @import("tools.zig");
const ToolKind = tools_mod.ToolKind;
const ToolState = tools_mod.ToolState;
const history_mod = @import("history.zig");
const History = history_mod.History;
const properties_mod = @import("properties.zig");
const ElementProps = properties_mod.ElementProps;
const text_input_mod = @import("text_input.zig");
const TextInput = text_input_mod.TextInput;
const renderer = @import("renderer.zig");
const ui = @import("ui.zig");
const selection_mod = @import("selection.zig");

pub const App = struct {
    scene: Scene,
    canvas: Canvas,
    active_tool: ToolKind,
    tool_state: ToolState,
    selection: ?u64,
    history: History,
    current_props: ElementProps,
    text_input: TextInput,
    font: rl.Font,
    allocator: std.mem.Allocator,
    // Double-click detection
    last_click_time: f64,
    last_click_x: f32,
    last_click_y: f32,

    pub fn init(allocator: std.mem.Allocator) App {
        const font = rl.getFontDefault() catch unreachable;
        return .{
            .scene = Scene.init(allocator),
            .canvas = Canvas{},
            .active_tool = .select,
            .tool_state = .idle,
            .selection = null,
            .history = History.init(allocator),
            .current_props = ElementProps{},
            .text_input = TextInput{},
            .font = font,
            .allocator = allocator,
            .last_click_time = 0,
            .last_click_x = 0,
            .last_click_y = 0,
        };
    }

    pub fn deinit(self: *App) void {
        self.scene.deinit();
        self.history.deinit();
    }

    pub fn detectDoubleClick(self: *App) bool {
        if (rl.isMouseButtonPressed(.left)) {
            const now = rl.getTime();
            const mouse = rl.getMousePosition();
            const dt = now - self.last_click_time;
            const dx = mouse.x - self.last_click_x;
            const dy = mouse.y - self.last_click_y;
            const dist = @sqrt(dx * dx + dy * dy);

            // Record this click
            self.last_click_time = now;
            self.last_click_x = mouse.x;
            self.last_click_y = mouse.y;

            // Check if double click (within 400ms and 10px)
            if (dt < 0.4 and dist < 10) {
                self.last_click_time = 0; // reset to prevent triple
                return true;
            }
        }
        return false;
    }

    pub fn update(self: *App) void {
        // Update canvas pan/zoom (always, even when typing)
        self.canvas.update();

        // Handle escape for text input BEFORE shortcuts
        if (self.tool_state == .typing) {
            // Escape is handled by text_input, don't let it propagate
            // Tool input handles the typing state
            tools_mod.processInput(self);
            return;
        }

        // Keyboard shortcuts (only when not typing)
        self.handleShortcuts();

        // Tool input
        tools_mod.processInput(self);
    }

    fn handleShortcuts(self: *App) void {
        const ctrl = rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control) or
            rl.isKeyDown(.left_super) or rl.isKeyDown(.right_super);
        const shift = rl.isKeyDown(.left_shift) or rl.isKeyDown(.right_shift);

        // Undo/Redo
        if (ctrl and shift and rl.isKeyPressed(.z)) {
            _ = self.history.redo(&self.scene);
            self.selection = null;
        } else if (ctrl and rl.isKeyPressed(.z)) {
            _ = self.history.undo(&self.scene);
            self.selection = null;
        }

        // Save
        if (ctrl and rl.isKeyPressed(.s)) {
            if (self.scene.serialize(self.allocator)) |json| {
                defer self.allocator.free(json);
                const file = std.fs.cwd().createFile("drawing.json", .{}) catch return;
                defer file.close();
                file.writeAll(json) catch {};
            } else |_| {}
        }

        // Delete
        if (rl.isKeyPressed(.delete) or rl.isKeyPressed(.backspace)) {
            if (self.selection) |sel_id| {
                if (self.tool_state == .idle) {
                    self.history.pushSnapshot(&self.scene) catch {};
                    self.scene.removeElement(sel_id);
                    self.selection = null;
                }
            }
        }

        // Tool switching via keys
        if (rl.isKeyPressed(.v) or rl.isKeyPressed(.one)) self.active_tool = .select;
        if (rl.isKeyPressed(.r) or rl.isKeyPressed(.two)) self.active_tool = .rectangle;
        if (rl.isKeyPressed(.d) or rl.isKeyPressed(.three)) self.active_tool = .ellipse;
        if (rl.isKeyPressed(.e) or rl.isKeyPressed(.four)) self.active_tool = .circle_shape;
        if ((rl.isKeyPressed(.a) and !ctrl) or rl.isKeyPressed(.five)) self.active_tool = .arrow;
        if (rl.isKeyPressed(.l) or rl.isKeyPressed(.six)) self.active_tool = .line;
        if (rl.isKeyPressed(.t) or rl.isKeyPressed(.seven)) self.active_tool = .text;
    }

    pub fn draw(self: *App) void {
        rl.clearBackground(rl.Color.init(250, 250, 250, 255));

        // Grid
        self.canvas.drawGrid();

        // Scene
        renderer.drawScene(&self.scene, self.canvas, self.font);

        // Selection handles
        if (self.selection) |sel_id| {
            if (self.scene.getElementById(sel_id)) |el| {
                renderer.drawSelectionHighlight(el.*, self.canvas);
            }
        }

        // Text cursor
        if (self.tool_state == .typing) {
            if (self.tool_state.typing.element_id != 0) {
                if (self.scene.getElementById(self.tool_state.typing.element_id)) |el| {
                    const sp = self.canvas.worldToScreen(el.x, el.y);
                    self.text_input.drawCursor(sp[0], sp[1], self.font, 20.0 * self.canvas.zoom);
                }
            }
        }

        // UI
        if (ui.drawToolbar(self.active_tool, rl.getScreenWidth(), self.font)) |new_tool| {
            self.active_tool = new_tool;
        }
        _ = ui.drawPropertyBar(&self.current_props, rl.getScreenWidth(), rl.getScreenHeight(), self.font);
    }
};
