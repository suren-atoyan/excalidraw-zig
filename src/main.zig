const std = @import("std");
const rl = @import("raylib");
const app_mod = @import("app.zig");
const App = app_mod.App;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(1280, 720, "Excalidraw-Zig");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Disable ESC to close window — we use ESC for text cancel
    rl.setExitKey(.@"null");

    var app = App.init(allocator);
    defer app.deinit();

    while (!rl.windowShouldClose()) {
        app.update();
        rl.beginDrawing();
        app.draw();
        rl.endDrawing();
    }
}
