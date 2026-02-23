const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL.h");
});

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Hello SDL3 (Zig)", 960, 540, 0);
    if (window == null) {
        std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
        return error.SDLWindowFailed;
    }
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null);
    if (renderer == null) {
        std.log.err("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
        return error.SDLRendererFailed;
    }
    defer c.SDL_DestroyRenderer(renderer);

    var running = true;
    var event: c.SDL_Event = undefined;
    var t: f32 = 0.0;

    while (running) {
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.key == c.SDLK_ESCAPE) running = false;
                },
                else => {},
            }
        }

        t += 0.016;

        _ = c.SDL_SetRenderDrawColor(renderer, 15, 15, 20, 255);
        _ = c.SDL_RenderClear(renderer);

        const x = @as(f32, 420.0 + 200.0 * std.math.sin(t));
        const y: f32 = 240.0;
        var rect = c.SDL_FRect{ .x = x, .y = y, .w = 120.0, .h = 80.0 };

        _ = c.SDL_SetRenderDrawColor(renderer, 220, 220, 240, 255);
        _ = c.SDL_RenderFillRect(renderer, &rect);

        _ = c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1);
    }
}
