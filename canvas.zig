const std = @import("std");
const builtin = @import("builtin");
const Point = @import("point.zig").Point;
const Color = @import("color.zig").Color;

pub const Canvas = struct {
    width: usize,
    height: usize,
    buffer: []u8,
    allocator: std.mem.Allocator,
    clear_pattern: [32]u8,
    grain_buffer: []i16,
    grain_size: usize,
    temp_buffer: []u8,
    integral_buffer: [][4]u32,
    chromatic_buffer: []u8,

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

    pub fn fastBlur(self: *Canvas, min_radius: usize, max_radius: usize) void {
        applyFastBlur(self, min_radius, max_radius);
    }

    pub fn addFilmGrain(self: *Canvas, intensity: f32) void {
        applyFilmGrain(self, intensity);
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

    fn generateGrainPattern(self: *Canvas, seed: u32) !void {
        var rng = LCG.init(seed);

        for (self.grain_buffer) |*noise| {
            // Pre-compute noise values in the range [-128, 127]
            noise.* = @as(i16, @intFromFloat(rng.nextFloat() * 256 - 128));
        }
    }
};

fn initCanvas(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
    const buffer = try allocator.alloc(u8, width * height * 4);
    const grain_size = 2048; // You can adjust this value
    const grain_buffer = try allocator.alloc(i16, grain_size * grain_size);
    const temp_buffer = try allocator.alloc(u8, width * height * 4);
    const integral_buffer = try allocator.alloc([4]u32, (width + 1) * (height + 1));
    const chromatic_buffer = try allocator.alloc(u8, width * height * 4);

    var canvas = Canvas{
        .width = width,
        .height = height,
        .buffer = buffer,
        .allocator = allocator,
        .clear_pattern = undefined,
        .grain_buffer = grain_buffer,
        .grain_size = grain_size,
        .temp_buffer = temp_buffer,
        .integral_buffer = integral_buffer,
        .chromatic_buffer = chromatic_buffer,
    };
    try canvas.generateGrainPattern(12345);
    return canvas;
}

fn deinitCanvas(canvas: *Canvas) void {
    canvas.allocator.free(canvas.buffer);
    canvas.allocator.free(canvas.grain_buffer);
    canvas.allocator.free(canvas.temp_buffer);
    canvas.allocator.free(canvas.integral_buffer);
    canvas.allocator.free(canvas.chromatic_buffer);
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
    const r = @as(i32, @intFromFloat(radius * @as(f32, @floatFromInt(canvas.width)) * 0.5));
    const stroke = @as(i32, @intFromFloat(stroke_width * @as(f32, @floatFromInt(canvas.width)) * 0.5));
    const outer_r = r + @divTrunc(stroke, 2);
    const inner_r = r - @divTrunc(stroke, 2);

    var y: i32 = -outer_r;
    while (y <= outer_r) : (y += 1) {
        var x: i32 = -outer_r;
        while (x <= outer_r) : (x += 1) {
            const dx = x;
            const dy = y;
            const distance_sq = dx * dx + dy * dy;
            if (distance_sq <= outer_r * outer_r and distance_sq >= inner_r * inner_r) {
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

    const steps: f32 = 12 / stroke_width;
    const step_size = 1.0 / steps;
    const half_width = @as(i32, @intFromFloat(stroke_width * @as(f32, @floatFromInt(canvas.width)) * 0.25));
    const half_width_sq = half_width * half_width;

    // Pre-compute constants for the quadratic Bezier formula
    const ax = @as(f32, @floatFromInt(start_screen[0] - 2 * control_screen[0] + end_screen[0]));
    const ay = @as(f32, @floatFromInt(start_screen[1] - 2 * control_screen[1] + end_screen[1]));
    const bx = @as(f32, @floatFromInt(2 * (control_screen[0] - start_screen[0])));
    const by = @as(f32, @floatFromInt(2 * (control_screen[1] - start_screen[1])));
    const start_x = @as(f32, @floatFromInt(start_screen[0]));
    const start_y = @as(f32, @floatFromInt(start_screen[1]));

    var t: f32 = 0;
    while (t <= 1.0) : (t += step_size) {
        const t2 = t * t;
        const x = @as(i32, @intFromFloat(ax * t2 + bx * t + start_x));
        const y = @as(i32, @intFromFloat(ay * t2 + by * t + start_y));

        // Use a more efficient nested loop for drawing filled circles
        var dy: i32 = -half_width;
        while (dy <= half_width) : (dy += 1) {
            var dx: i32 = -half_width;
            while (dx <= half_width) : (dx += 1) {
                if (dx * dx + dy * dy <= half_width_sq) {
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

fn applyChromaticAberration(self: *Canvas, max_offset_x: i32, max_offset_y: i32) void {
    @memcpy(self.chromatic_buffer, self.buffer);

    const center_x = @as(f32, @floatFromInt(self.width)) / 2;
    const center_y = @as(f32, @floatFromInt(self.height)) / 2;
    const max_distance_sq = center_x * center_x + center_y * center_y;
    const max_offset_x_f = @as(f32, @floatFromInt(max_offset_x));
    const max_offset_y_f = @as(f32, @floatFromInt(max_offset_y));

    // Pre-compute intensity lookup table
    var intensity_lut: [256]f32 = undefined;
    for (&intensity_lut, 0..) |*intensity, i| {
        intensity.* = @sqrt(@as(f32, @floatFromInt(i)) / 255.0);
    }

    // Downsample factor (adjust as needed)
    const downsample = 8;

    var y: usize = 0;
    while (y < self.height) : (y += downsample) {
        const dy = @as(f32, @floatFromInt(y)) - center_y;
        const dy_sq = dy * dy;
        var x: usize = 0;
        while (x < self.width) : (x += downsample) {
            const dx = @as(f32, @floatFromInt(x)) - center_x;
            const distance_sq = dx * dx + dy_sq;
            const intensity_index = @as(usize, @intFromFloat((@min(distance_sq / max_distance_sq, 1.0)) * 255.0));
            const intensity = intensity_lut[intensity_index];
            const offset_x = @as(i32, @intFromFloat(max_offset_x_f * intensity));
            const offset_y = @as(i32, @intFromFloat(max_offset_y_f * intensity));

            // Apply effect to a block of pixels
            var by: usize = 0;
            while (by < downsample and y + by < self.height) : (by += 1) {
                var bx: usize = 0;
                while (bx < downsample and x + bx < self.width) : (bx += 1) {
                    const index = ((y + by) * self.width + (x + bx)) * 4;

                    // Red channel
                    const red_x = @as(i32, @intCast(x + bx)) + offset_x;
                    const red_y = @as(i32, @intCast(y + by)) + offset_y;
                    if (red_x >= 0 and red_x < @as(i32, @intCast(self.width)) and
                        red_y >= 0 and red_y < @as(i32, @intCast(self.height)))
                    {
                        const red_index = (@as(usize, @intCast(red_y)) * self.width + @as(usize, @intCast(red_x))) * 4;
                        self.buffer[index] = self.chromatic_buffer[red_index];
                    }

                    // Blue channel
                    const blue_x = @as(i32, @intCast(x + bx)) - offset_x;
                    const blue_y = @as(i32, @intCast(y + by)) - offset_y;
                    if (blue_x >= 0 and blue_x < @as(i32, @intCast(self.width)) and
                        blue_y >= 0 and blue_y < @as(i32, @intCast(self.height)))
                    {
                        const blue_index = (@as(usize, @intCast(blue_y)) * self.width + @as(usize, @intCast(blue_x))) * 4 + 2;
                        self.buffer[index + 2] = self.chromatic_buffer[blue_index];
                    }

                    // Green channel and alpha remain unchanged
                    self.buffer[index + 1] = self.chromatic_buffer[index + 1];
                    self.buffer[index + 3] = self.chromatic_buffer[index + 3];
                }
            }
        }
    }
}

fn applyFastBlur(canvas: *Canvas, min_radius: usize, max_radius: usize) void {
    const center_x = @as(f32, @floatFromInt(canvas.width)) / 2;
    const center_y = @as(f32, @floatFromInt(canvas.height)) / 2;
    const max_distance = @sqrt(center_x * center_x + center_y * center_y);

    // Calculate integral image
    var y: usize = 0;
    while (y <= canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x <= canvas.width) : (x += 1) {
            if (x == 0 or y == 0) {
                canvas.integral_buffer[y * (canvas.width + 1) + x] = .{ 0, 0, 0, 0 };
            } else {
                const index = ((y - 1) * canvas.width + (x - 1)) * 4;
                const current = @Vector(4, u32){
                    canvas.buffer[index],
                    canvas.buffer[index + 1],
                    canvas.buffer[index + 2],
                    canvas.buffer[index + 3],
                };
                const above = @Vector(4, u32){ canvas.integral_buffer[(y - 1) * (canvas.width + 1) + x][0], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + x][1], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + x][2], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + x][3] };
                const left = @Vector(4, u32){ canvas.integral_buffer[y * (canvas.width + 1) + (x - 1)][0], canvas.integral_buffer[y * (canvas.width + 1) + (x - 1)][1], canvas.integral_buffer[y * (canvas.width + 1) + (x - 1)][2], canvas.integral_buffer[y * (canvas.width + 1) + (x - 1)][3] };
                const diagonal = @Vector(4, u32){ canvas.integral_buffer[(y - 1) * (canvas.width + 1) + (x - 1)][0], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + (x - 1)][1], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + (x - 1)][2], canvas.integral_buffer[(y - 1) * (canvas.width + 1) + (x - 1)][3] };
                const result = above + left - diagonal + current;
                canvas.integral_buffer[y * (canvas.width + 1) + x] = .{ result[0], result[1], result[2], result[3] };
            }
        }
    }

    // Apply radial box blur using integral image
    y = 0;
    while (y < canvas.height) : (y += 1) {
        var x: usize = 0;
        while (x < canvas.width) : (x += 1) {
            const dx = @as(f32, @floatFromInt(x)) - center_x;
            const dy = @as(f32, @floatFromInt(y)) - center_y;
            const distance = @sqrt(dx * dx + dy * dy);
            const blur_factor = distance / max_distance;
            const radius = @as(usize, @intFromFloat(@as(f32, @floatFromInt(min_radius)) + blur_factor * @as(f32, @floatFromInt(max_radius - min_radius))));

            const x1 = if (x >= radius) x - radius else 0;
            const y1 = if (y >= radius) y - radius else 0;
            const x2 = if (x + radius < canvas.width) x + radius else canvas.width - 1;
            const y2 = if (y + radius < canvas.height) y + radius else canvas.height - 1;

            const count = @as(u32, (x2 - x1 + 1) * (y2 - y1 + 1));

            const sum = @Vector(4, u32){ canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][0], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][1], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][2], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + (x2 + 1)][3] } - @Vector(4, u32){ canvas.integral_buffer[(y1) * (canvas.width + 1) + (x2 + 1)][0], canvas.integral_buffer[(y1) * (canvas.width + 1) + (x2 + 1)][1], canvas.integral_buffer[(y1) * (canvas.width + 1) + (x2 + 1)][2], canvas.integral_buffer[(y1) * (canvas.width + 1) + (x2 + 1)][3] } - @Vector(4, u32){ canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + x1][0], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + x1][1], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + x1][2], canvas.integral_buffer[(y2 + 1) * (canvas.width + 1) + x1][3] } + @Vector(4, u32){ canvas.integral_buffer[y1 * (canvas.width + 1) + x1][0], canvas.integral_buffer[y1 * (canvas.width + 1) + x1][1], canvas.integral_buffer[y1 * (canvas.width + 1) + x1][2], canvas.integral_buffer[y1 * (canvas.width + 1) + x1][3] };

            const index = (y * canvas.width + x) * 4;
            const result = @divFloor(sum, @as(@Vector(4, u32), @splat(count)));
            canvas.temp_buffer[index] = @intCast(result[0]);
            canvas.temp_buffer[index + 1] = @intCast(result[1]);
            canvas.temp_buffer[index + 2] = @intCast(result[2]);
            canvas.temp_buffer[index + 3] = @intCast(result[3]);
        }
    }

    // Copy result back to main buffer
    @memcpy(canvas.buffer, canvas.temp_buffer);
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

pub fn applyFilmGrain(self: *Canvas, intensity: f32) void {
    const scaled_intensity = @as(i32, @intFromFloat(intensity * 256)); // Pre-compute scaled intensity

    var y: usize = 0;
    while (y < self.height) : (y += 1) {
        var x: usize = 0;
        while (x < self.width) : (x += 1) {
            const index = (y * self.width + x) * 4;
            const grain_index = (y % self.grain_size) * self.grain_size + (x % self.grain_size);
            const noise = (self.grain_buffer[grain_index] * scaled_intensity) >> 8; // Fast division by 256

            inline for (0..3) |i| {
                const pixel_value = @as(i32, self.buffer[index + i]);
                const new_value = @as(u8, @intCast(@min(255, @max(0, pixel_value + noise))));
                self.buffer[index + i] = new_value;
            }
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
