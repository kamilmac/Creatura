const std = @import("std");
const Point = @import("point.zig").Point;
const Color = @import("main.zig").Color;

pub const Canvas = struct {
    width: usize,
    height: usize,
    buffer: []u8,
    allocator: std.mem.Allocator,
    clear_pattern: [32]u8,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
        return initCanvas(allocator, width, height);
    }

    pub fn deinit(self: *Canvas) void {
        deinitCanvas(self);
    }

    pub fn clear(self: *Canvas) void {
        clearCanvas(self);
    }

    pub fn paintCircle(self: *Canvas, center: Point, radius: f32, stroke_width: f32) void {
        paintCircleOnCanvas(self, center, radius, stroke_width);
    }

    pub fn drawLine(self: *Canvas, start: Point, end: Point, stroke_width: f32, color: Color) void {
        drawLineOnCanvas(self, start, end, stroke_width, color);
    }

    pub fn drawBezierCurve(self: *Canvas, start: Point, end: Point, control: Point, stroke_width: f32, color: Color) void {
        drawBezierCurveOnCanvas(self, start, end, control, stroke_width, color);
    }

    pub fn setClearColor(self: *Canvas, color: Color) void {
        setClearColorForCanvas(self, color);
    }

    pub fn chromaticAberration(self: *Canvas, max_offset_x: i32, max_offset_y: i32) void {
        applyChromaticAberration(self, max_offset_x, max_offset_y);
    }

    pub fn fastBlur(self: *Canvas, radius: usize) void {
        applyFastBlur(self, radius);
    }

    pub fn addFilmGrain(self: *Canvas, intensity: f32, seed: u32) void {
        applyFilmGrain(self, intensity, seed);
    }

    pub fn getBufferPtr(self: *Canvas) [*]u8 {
        return self.buffer.ptr;
    }

    pub fn fillRect(self: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        fillRectOnCanvas(self, x1, y1, x2, y2, color);
    }

    pub fn setPixel(canvas: *Canvas, x: i32, y: i32, color: Color) void {
        setPixelOnCanvas(canvas, x, y, color);
    }

    fn translateToScreenSpace(canvas: *const Canvas, x: f32, y: f32) [2]i32 {
        return translateToScreenSpaceOnCanvas(canvas, x, y);
    }
};

fn initCanvas(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
    const buffer = try allocator.alloc(u8, width * height * 4);
    return Canvas{
        .width = width,
        .height = height,
        .buffer = buffer,
        .allocator = allocator,
        .clear_pattern = undefined,
    };
}

fn deinitCanvas(canvas: *Canvas) void {
    canvas.allocator.free(canvas.buffer);
}

fn clearCanvas(canvas: *Canvas) void {
    var i: usize = 0;
    while (i + 32 <= canvas.buffer.len) : (i += 32) {
        @memcpy(canvas.buffer[i .. i + 32], &canvas.clear_pattern);
    }
    if (i < canvas.buffer.len) {
        @memcpy(canvas.buffer[i..], canvas.clear_pattern[0 .. canvas.buffer.len - i]);
    }
}

fn paintCircleOnCanvas(canvas: *Canvas, center: Point, radius: f32, stroke_width: f32) void {
    const screen_position = canvas.translateToScreenSpace(center.position[0], center.position[1]);
    const x0 = screen_position[0];
    const y0 = screen_position[1];
    const r = radius * @as(f32, @floatFromInt(canvas.width)) * 0.5;
    const stroke = stroke_width * @as(f32, @floatFromInt(canvas.width)) * 0.5;
    const outer_radius_sq = (r + stroke * 0.5) * (r + stroke * 0.5);
    const inner_radius_sq = (r - stroke * 0.5) * (r - stroke * 0.5);

    const bounding_box: i32 = @intFromFloat(r + stroke * 0.5 + 1);

    var y: i32 = -bounding_box;
    while (y <= bounding_box) : (y += 1) {
        var x: i32 = -bounding_box;
        while (x <= bounding_box) : (x += 1) {
            const dx: f32 = @floatFromInt(x);
            const dy: f32 = @floatFromInt(y);
            const distance_sq = dx * dx + dy * dy;

            if (distance_sq <= outer_radius_sq and distance_sq >= inner_radius_sq) {
                canvas.setPixel(x0 + x, y0 + y, center.color);
            }
        }
    }
}

fn drawLineOnCanvas(canvas: *Canvas, start: Point, end: Point, stroke_width: f32, color: Color) void {
    const start_screen = canvas.translateToScreenSpace(start.position[0], start.position[1]);
    const end_screen = canvas.translateToScreenSpace(end.position[0], end.position[1]);
    const half_width: i32 = @intFromFloat(stroke_width * @as(f32, @floatFromInt(canvas.width)) * 0.25);

    var x0 = start_screen[0];
    var y0 = start_screen[1];
    const dx: i32 = @intCast(@abs(end_screen[0] - x0));
    const dy: i32 = @intCast(@abs(end_screen[1] - y0));
    const sx: i32 = if (x0 < end_screen[0]) 1 else -1;
    const sy: i32 = if (y0 < end_screen[1]) 1 else -1;
    var err = dx - dy;

    while (true) {
        // Draw a filled rectangle centered on the current pixel
        canvas.fillRect(x0 - half_width, y0 - half_width, x0 + half_width, y0 + half_width, color);

        if (x0 == end_screen[0] and y0 == end_screen[1]) break;
        const e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0 += sy;
        }
    }
}

fn drawBezierCurveOnCanvas(canvas: *Canvas, start: Point, end: Point, control: Point, stroke_width: f32, color: Color) void {
    const start_screen = canvas.translateToScreenSpace(start.position[0], start.position[1]);
    const end_screen = canvas.translateToScreenSpace(end.position[0], end.position[1]);
    const control_screen = canvas.translateToScreenSpace(control.position[0], control.position[1]);

    const steps = 1000; // Increase for smoother curve
    const half_width = @as(i32, @intFromFloat(stroke_width * @as(f32, @floatFromInt(canvas.width)) * 0.25));

    var t: f32 = 0;
    while (t <= 1.0) : (t += 1.0 / @as(f32, steps)) {
        const x = @as(i32, @intFromFloat(std.math.pow(f32, 1 - t, 2) * @as(f32, @floatFromInt(start_screen[0])) +
            2 * (1 - t) * t * @as(f32, @floatFromInt(control_screen[0])) +
            std.math.pow(f32, t, 2) * @as(f32, @floatFromInt(end_screen[0]))));
        const y = @as(i32, @intFromFloat(std.math.pow(f32, 1 - t, 2) * @as(f32, @floatFromInt(start_screen[1])) +
            2 * (1 - t) * t * @as(f32, @floatFromInt(control_screen[1])) +
            std.math.pow(f32, t, 2) * @as(f32, @floatFromInt(end_screen[1]))));

        // Draw a filled circle at each point for smooth, thick lines
        var dy: i32 = -half_width;
        while (dy <= half_width) : (dy += 1) {
            var dx: i32 = -half_width;
            while (dx <= half_width) : (dx += 1) {
                if (dx * dx + dy * dy <= half_width * half_width) {
                    canvas.setPixel(x + dx, y + dy, color);
                }
            }
        }
    }
}

fn setClearColorForCanvas(canvas: *Canvas, color: Color) void {
    const rgba = color.toRGBA();
    var i: usize = 0;
    while (i < canvas.clear_pattern.len) : (i += 4) {
        canvas.clear_pattern[i] = rgba[0];
        canvas.clear_pattern[i + 1] = rgba[1];
        canvas.clear_pattern[i + 2] = rgba[2];
        canvas.clear_pattern[i + 3] = rgba[3];
    }
}

fn applyChromaticAberration(canvas: *Canvas, max_offset_x: i32, max_offset_y: i32) void {
    const temp_buffer = canvas.allocator.alloc(u8, canvas.buffer.len) catch unreachable;
    defer canvas.allocator.free(temp_buffer);

    @memcpy(temp_buffer, canvas.buffer);

    const center_x = @as(f32, @floatFromInt(canvas.width)) / 2;
    const center_y = @as(f32, @floatFromInt(canvas.height)) / 2;
    const max_distance = @sqrt(center_x * center_x + center_y * center_y);

    var y: usize = 0;
    while (y < canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x < canvas.width) : (x += 1) {
            const dx = @as(f32, @floatFromInt(x)) - center_x;
            const dy = @as(f32, @floatFromInt(y)) - center_y;
            const distance = @sqrt(dx * dx + dy * dy);
            const intensity = distance / max_distance;

            const offset_x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(max_offset_x)) * intensity));
            const offset_y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(max_offset_y)) * intensity));

            const index = (y * canvas.width + x) * 4;

            // Red channel
            const red_x = @as(i32, @intCast(x)) + offset_x;
            const red_y = @as(i32, @intCast(y)) + offset_y;
            if (red_x >= 0 and red_x < @as(i32, @intCast(canvas.width)) and
                red_y >= 0 and red_y < @as(i32, @intCast(canvas.height)))
            {
                const red_index = (@as(usize, @intCast(red_y)) * canvas.width + @as(usize, @intCast(red_x))) * 4;
                canvas.buffer[index] = temp_buffer[red_index];
            }

            // Blue channel
            const blue_x = @as(i32, @intCast(x)) - offset_x;
            const blue_y = @as(i32, @intCast(y)) - offset_y;
            if (blue_x >= 0 and blue_x < @as(i32, @intCast(canvas.width)) and
                blue_y >= 0 and blue_y < @as(i32, @intCast(canvas.height)))
            {
                const blue_index = (@as(usize, @intCast(blue_y)) * canvas.width + @as(usize, @intCast(blue_x))) * 4 + 2;
                canvas.buffer[index + 2] = temp_buffer[blue_index];
            }

            // Green channel and alpha remain unchanged
            canvas.buffer[index + 1] = temp_buffer[index + 1];
            canvas.buffer[index + 3] = temp_buffer[index + 3];
        }
    }
}

fn applyFastBlur(canvas: *Canvas, radius: usize) void {
    const temp_buffer = canvas.allocator.alloc(u8, canvas.buffer.len) catch unreachable;
    defer canvas.allocator.free(temp_buffer);

    const integral = canvas.allocator.alloc([4]u32, (canvas.width + 1) * (canvas.height + 1)) catch unreachable;
    defer canvas.allocator.free(integral);

    // Calculate integral image
    var y: usize = 0;
    while (y <= canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x <= canvas.width) : (x += 1) {
            if (x == 0 or y == 0) {
                integral[y * (canvas.width + 1) + x] = .{ 0, 0, 0, 0 };
            } else {
                const index = ((y - 1) * canvas.width + (x - 1)) * 4;
                integral[y * (canvas.width + 1) + x] = .{
                    integral[(y - 1) * (canvas.width + 1) + x][0] +
                        integral[y * (canvas.width + 1) + (x - 1)][0] -
                        integral[(y - 1) * (canvas.width + 1) + (x - 1)][0] +
                        canvas.buffer[index],

                    integral[(y - 1) * (canvas.width + 1) + x][1] +
                        integral[y * (canvas.width + 1) + (x - 1)][1] -
                        integral[(y - 1) * (canvas.width + 1) + (x - 1)][1] +
                        canvas.buffer[index + 1],

                    integral[(y - 1) * (canvas.width + 1) + x][2] +
                        integral[y * (canvas.width + 1) + (x - 1)][2] -
                        integral[(y - 1) * (canvas.width + 1) + (x - 1)][2] +
                        canvas.buffer[index + 2],

                    integral[(y - 1) * (canvas.width + 1) + x][3] +
                        integral[y * (canvas.width + 1) + (x - 1)][3] -
                        integral[(y - 1) * (canvas.width + 1) + (x - 1)][3] +
                        canvas.buffer[index + 3],
                };
            }
        }
    }

    // Apply box blur using integral image
    y = 0;
    while (y < canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x < canvas.width) : (x += 1) {
            const x1 = if (x >= radius) x - radius else 0;
            const y1 = if (y >= radius) y - radius else 0;
            const x2 = if (x + radius < canvas.width) x + radius else canvas.width - 1;
            const y2 = if (y + radius < canvas.height) y + radius else canvas.height - 1;

            const count = (x2 - x1 + 1) * (y2 - y1 + 1);

            const sum = [4]u32{
                integral[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][0] -
                    integral[(y1) * (canvas.width + 1) + (x2 + 1)][0] -
                    integral[(y2 + 1) * (canvas.width + 1) + x1][0] +
                    integral[y1 * (canvas.width + 1) + x1][0],

                integral[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][1] -
                    integral[(y1) * (canvas.width + 1) + (x2 + 1)][1] -
                    integral[(y2 + 1) * (canvas.width + 1) + x1][1] +
                    integral[y1 * (canvas.width + 1) + x1][1],

                integral[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][2] -
                    integral[(y1) * (canvas.width + 1) + (x2 + 1)][2] -
                    integral[(y2 + 1) * (canvas.width + 1) + x1][2] +
                    integral[y1 * (canvas.width + 1) + x1][2],

                integral[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][3] -
                    integral[(y1) * (canvas.width + 1) + (x2 + 1)][3] -
                    integral[(y2 + 1) * (canvas.width + 1) + x1][3] +
                    integral[y1 * (canvas.width + 1) + x1][3],
            };

            const index = (y * canvas.width + x) * 4;
            temp_buffer[index] = @intCast(sum[0] / count);
            temp_buffer[index + 1] = @intCast(sum[1] / count);
            temp_buffer[index + 2] = @intCast(sum[2] / count);
            temp_buffer[index + 3] = @intCast(sum[3] / count);
        }
    }

    // Copy result back to main buffer
    @memcpy(canvas.buffer, temp_buffer);
}

// Simple Linear Congruential Generator
const LCG = struct {
    state: u32,

    pub fn init(seed: u32) LCG {
        return LCG{ .state = seed };
    }

    pub fn next(self: *LCG) u32 {
        self.state = (1103515245 * self.state + 12345) & 0x7fffffff;
        return self.state;
    }

    pub fn nextFloat(self: *LCG) f32 {
        return @as(f32, @floatFromInt(self.next())) / @as(f32, @floatFromInt(0x7fffffff));
    }
};

fn applyFilmGrain(canvas: *Canvas, intensity: f32, seed: u32) void {
    var rng = LCG.init(seed);
    var y: usize = 0;
    while (y < canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x < canvas.width) : (x += 1) {
            const index = (y * canvas.width + x) * 4;

            // Generate random noise value
            const noise = (rng.nextFloat() - 0.5) * intensity;

            // Apply noise to each channel
            inline for (0..3) |i| {
                const pixel_value = @as(f32, @floatFromInt(canvas.buffer[index + i]));
                const new_value = @min(255, @max(0, pixel_value + noise * 255));
                canvas.buffer[index + i] = @intFromFloat(new_value);
            }

            // Don't modify alpha channel
        }
    }
}

fn fillRectOnCanvas(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
    const start_x = @max(0, @min(x1, x2));
    const end_x = @min(@as(i32, @intCast(canvas.width)) - 1, @max(x1, x2));
    const start_y = @max(0, @min(y1, y2));
    const end_y = @min(@as(i32, @intCast(canvas.height)) - 1, @max(y1, y2));

    const rgba = color.toRGBA();
    var y = start_y;
    while (y <= end_y) : (y += 1) {
        var x = start_x;
        while (x <= end_x) : (x += 1) {
            const index = (@as(usize, @intCast(y)) * canvas.width + @as(usize, @intCast(x))) * 4;
            canvas.buffer[index] = rgba[0];
            canvas.buffer[index + 1] = rgba[1];
            canvas.buffer[index + 2] = rgba[2];
            canvas.buffer[index + 3] = rgba[3];
        }
    }
}

fn setPixelOnCanvas(canvas: *Canvas, x: i32, y: i32, color: Color) void {
    if (x < 0 or x >= @as(i32, @intCast(canvas.width)) or y < 0 or y >= @as(i32, @intCast(canvas.height))) {
        return;
    }

    const index = (@as(usize, @intCast(y)) * canvas.width + @as(usize, @intCast(x))) * 4;
    const rgba = color.toRGBA();
    canvas.buffer[index] = rgba[0]; // R
    canvas.buffer[index + 1] = rgba[1]; // G
    canvas.buffer[index + 2] = rgba[2]; // B
    canvas.buffer[index + 3] = rgba[3]; // A
}

fn translateToScreenSpaceOnCanvas(canvas: *const Canvas, x: f32, y: f32) [2]i32 {
    return .{
        @intFromFloat((x + 1) * 0.5 * @as(f32, @floatFromInt(canvas.width))),
        @intFromFloat((1 - y) * 0.5 * @as(f32, @floatFromInt(canvas.height))),
    };
}
