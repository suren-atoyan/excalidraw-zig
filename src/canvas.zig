const rl = @import("raylib");

pub const Canvas = struct {
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    zoom: f32 = 1.0,
    prev_mouse_x: f32 = 0,
    prev_mouse_y: f32 = 0,
    panning: bool = false,
    space_held: bool = false,

    pub fn screenToWorld(self: Canvas, sx: f32, sy: f32) [2]f32 {
        return .{
            (sx - self.offset_x) / self.zoom,
            (sy - self.offset_y) / self.zoom,
        };
    }

    pub fn worldToScreen(self: Canvas, wx: f32, wy: f32) [2]f32 {
        return .{
            wx * self.zoom + self.offset_x,
            wy * self.zoom + self.offset_y,
        };
    }

    pub fn update(self: *Canvas) void {
        const mouse_pos = rl.getMousePosition();
        const mx = mouse_pos.x;
        const my = mouse_pos.y;

        self.space_held = rl.isKeyDown(.space);

        // Start panning
        const middle_pressed = rl.isMouseButtonPressed(.middle);
        const space_left_pressed = self.space_held and rl.isMouseButtonPressed(.left);
        if (middle_pressed or space_left_pressed) {
            self.panning = true;
            self.prev_mouse_x = mx;
            self.prev_mouse_y = my;
        }

        // Continue panning
        if (self.panning) {
            const middle_down = rl.isMouseButtonDown(.middle);
            const space_left_down = self.space_held and rl.isMouseButtonDown(.left);
            if (middle_down or space_left_down) {
                const dx = mx - self.prev_mouse_x;
                const dy = my - self.prev_mouse_y;
                self.offset_x += dx;
                self.offset_y += dy;
                self.prev_mouse_x = mx;
                self.prev_mouse_y = my;
            } else {
                self.panning = false;
            }
        }

        // Zoom with scroll wheel towards mouse position
        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const zoom_factor: f32 = if (wheel > 0) 1.1 else 1.0 / 1.1;
            const new_zoom = self.zoom * zoom_factor;
            const clamped = @max(0.1, @min(5.0, new_zoom));

            const world_before = self.screenToWorld(mx, my);
            self.zoom = clamped;
            const screen_after = self.worldToScreen(world_before[0], world_before[1]);
            self.offset_x += mx - screen_after[0];
            self.offset_y += my - screen_after[1];
        }

        // +/- keys for zoom
        if (rl.isKeyPressed(.equal) or rl.isKeyPressed(.kp_add)) {
            self.zoomAt(mx, my, 1.2);
        }
        if (rl.isKeyPressed(.minus) or rl.isKeyPressed(.kp_subtract)) {
            self.zoomAt(mx, my, 1.0 / 1.2);
        }
    }

    fn zoomAt(self: *Canvas, sx: f32, sy: f32, factor: f32) void {
        const new_zoom = @max(0.1, @min(5.0, self.zoom * factor));
        const world_before = self.screenToWorld(sx, sy);
        self.zoom = new_zoom;
        const screen_after = self.worldToScreen(world_before[0], world_before[1]);
        self.offset_x += sx - screen_after[0];
        self.offset_y += sy - screen_after[1];
    }

    pub fn drawGrid(self: Canvas) void {
        const sw: f32 = @floatFromInt(rl.getScreenWidth());
        const sh: f32 = @floatFromInt(rl.getScreenHeight());

        const spacing: f32 = 20.0;
        const dot_radius: f32 = 1.0;
        const dot_color = rl.Color.init(200, 200, 200, 255);

        // Visible world bounds
        const top_left = self.screenToWorld(0, 0);
        const bottom_right = self.screenToWorld(sw, sh);

        const start_x = @floor(top_left[0] / spacing) * spacing;
        const start_y = @floor(top_left[1] / spacing) * spacing;

        var wy = start_y;
        while (wy <= bottom_right[1]) : (wy += spacing) {
            var wx = start_x;
            while (wx <= bottom_right[0]) : (wx += spacing) {
                const sp = self.worldToScreen(wx, wy);
                rl.drawCircleV(rl.Vector2.init(sp[0], sp[1]), dot_radius * self.zoom, dot_color);
            }
        }
    }
};
