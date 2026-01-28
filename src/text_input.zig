const rl = @import("raylib");

pub const TextInput = struct {
    buffer: [512]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    active: bool = false,
    blink_timer: f32 = 0,
    was_cancelled: bool = false,
    finished: bool = false,

    pub fn start(self: *TextInput, initial_text: ?[]const u8) void {
        self.active = true;
        self.finished = false;
        self.was_cancelled = false;
        self.blink_timer = 0;
        if (initial_text) |t| {
            const copy_len = @min(t.len, 512);
            @memcpy(self.buffer[0..copy_len], t[0..copy_len]);
            self.len = copy_len;
            self.cursor = copy_len;
        } else {
            self.len = 0;
            self.cursor = 0;
        }
    }

    pub fn update(self: *TextInput) void {
        if (!self.active) return;

        self.blink_timer += rl.getFrameTime();

        // Check finish keys
        if (rl.isKeyPressed(.enter)) {
            self.finished = true;
            self.was_cancelled = false;
            return;
        }
        if (rl.isKeyPressed(.escape)) {
            self.finished = true;
            self.was_cancelled = true;
            return;
        }

        // Backspace
        if (rl.isKeyPressed(.backspace)) {
            if (self.cursor > 0) {
                // Shift left
                var i = self.cursor - 1;
                while (i < self.len - 1) : (i += 1) {
                    self.buffer[i] = self.buffer[i + 1];
                }
                self.len -= 1;
                self.cursor -= 1;
            }
        }

        // Arrow keys
        if (rl.isKeyPressed(.left)) {
            if (self.cursor > 0) self.cursor -= 1;
        }
        if (rl.isKeyPressed(.right)) {
            if (self.cursor < self.len) self.cursor += 1;
        }

        // Character input
        var ch = rl.getCharPressed();
        while (ch > 0) : (ch = rl.getCharPressed()) {
            if (ch >= 32 and ch < 127 and self.len < 511) {
                // Insert at cursor
                var i = self.len;
                while (i > self.cursor) : (i -= 1) {
                    self.buffer[i] = self.buffer[i - 1];
                }
                self.buffer[self.cursor] = @intCast(@as(u32, @intCast(ch)));
                self.len += 1;
                self.cursor += 1;
            }
        }
    }

    pub fn isFinished(self: TextInput) bool {
        return self.finished;
    }

    pub fn getText(self: *const TextInput) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn drawCursor(self: TextInput, x: f32, y: f32, font: rl.Font, font_size: f32) void {
        if (!self.active) return;

        // Blinking
        const blink = @as(u32, @intFromFloat(self.blink_timer * 2.0)) % 2;
        if (blink == 1) return;

        // Measure text up to cursor to find x position
        var buf: [513]u8 = undefined;
        const cursor_len = @min(self.cursor, 512);
        @memcpy(buf[0..cursor_len], self.buffer[0..cursor_len]);
        buf[cursor_len] = 0;
        const z_text: [:0]const u8 = buf[0..cursor_len :0];
        const measure = rl.measureTextEx(font, z_text, font_size, 1.0);

        const cx = x + measure.x;
        rl.drawLineEx(
            rl.Vector2.init(cx, y),
            rl.Vector2.init(cx, y + font_size),
            2.0,
            rl.Color.init(30, 30, 30, 255),
        );
    }
};
