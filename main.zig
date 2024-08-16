const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const Color = enum(u32) {
    Red = 0xFF0000FF,
    Green = 0x00FF00FF,
    Blue = 0x0000FFFF,
    Yellow = 0xFFFF00FF,
    Black = 0x000000FF,
    White = 0xFFFFFFFF,
    // Add more colors as needed

    pub fn toRGBA(self: Color) [4]u8 {
        const value = @intFromEnum(self);
        return .{
            @intCast((value >> 24) & 0xFF),
            @intCast((value >> 16) & 0xFF),
            @intCast((value >> 8) & 0xFF),
            @intCast(value & 0xFF),
        };
    }
};

pub const Point = struct {
    position: [2]f32,
    velocity: [2]f32,
    target: ?*Point,
    color: Color,
    oscillation: struct {
        amplitude: [2]f32,
        frequency: [2]f32,
        offset: f32,
    },

    pub fn init() Point {
        return .{
            .position = .{ 0, 0 },
            .velocity = .{ 0, 0 },
            .target = null,
            .color = .Black,
            .oscillation = .{
                .amplitude = .{ 0, 0 },
                .frequency = .{ 0, 0 },
                .offset = 0,
            },
        };
    }

    pub fn setPosition(self: *Point, x: f32, y: f32) *Point {
        self.position = .{ x, y };
        return self;
    }

    pub fn setVelocity(self: *Point, vx: f32, vy: f32) *Point {
        self.velocity = .{ vx, vy };
        return self;
    }

    pub fn followPoint(self: *Point, other: *Point) *Point {
        self.target = other;
        return self;
    }

    pub fn setColor(self: *Point, new_color: Color) *Point {
        self.color = new_color;
        return self;
    }
    pub fn setOscillation(self: *Point, amplitude_x: f32, amplitude_y: f32, frequency_x: f32, frequency_y: f32) *Point {
        self.oscillation.amplitude = .{ amplitude_x, amplitude_y };
        self.oscillation.frequency = .{ frequency_x, frequency_y };
        return self;
    }

    fn oscillate(self: *Point) void {
        const dx = self.oscillation.amplitude[0] * @sin(self.oscillation.frequency[0] * self.oscillation.offset);
        const dy = self.oscillation.amplitude[1] * @sin(self.oscillation.frequency[1] * self.oscillation.offset);

        self.position[0] += dx;
        self.position[1] += dy;

        self.oscillation.offset += 0.1; // Increment offset for next frame
    }

    pub fn update(self: *Point) *Point {
        if (self.target) |t| {
            const dx = t.position[0] - self.position[0];
            const dy = t.position[1] - self.position[1];
            self.velocity[0] += dx * 0.1;
            self.velocity[1] += dy * 0.1;
        }

        self.position[0] += self.velocity[0];
        self.position[1] += self.velocity[1];

        // Apply oscillation
        self.oscillate();

        // Simple damping
        self.velocity[0] *= 0.994;
        self.velocity[1] *= 0.994;

        // Basic boundary check
        self.position[0] = @max(-1.0, @min(self.position[0], 1.0));
        self.position[1] = @max(-1.0, @min(self.position[1], 1.0));

        return self;
    }
};

pub const Canvas = struct {
    width: usize,
    height: usize,
    buffer: []u8,
    allocator: Allocator,
    clear_pattern: [32]u8,

    pub fn init(allocator: Allocator, width: usize, height: usize) !Canvas {
        const buffer = try allocator.alloc(u8, width * height * 4);
        return Canvas{
            .width = width,
            .height = height,
            .buffer = buffer,
            .allocator = allocator,
            .clear_pattern = undefined,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.buffer);
    }

    pub fn clear(self: *Canvas) void {
        var i: usize = 0;
        while (i + 32 <= self.buffer.len) : (i += 32) {
            @memcpy(self.buffer[i .. i + 32], &self.clear_pattern);
        }
        if (i < self.buffer.len) {
            @memcpy(self.buffer[i..], self.clear_pattern[0 .. self.buffer.len - i]);
        }
    }

    fn translateToScreenSpace(self: *const Canvas, x: f32, y: f32) struct { x: i32, y: i32 } {
        return .{
            .x = @intFromFloat((x + 1) * 0.5 * @as(f32, @floatFromInt(self.width))),
            .y = @intFromFloat((1 - y) * 0.5 * @as(f32, @floatFromInt(self.height))),
        };
    }

    pub fn paintCircle(self: *Canvas, center: Point, radius: f32, stroke_width: f32) void {
        const screen_position = self.translateToScreenSpace(center.position[0], center.position[1]);
        const x0 = screen_position.x;
        const y0 = screen_position.y;
        const r = radius * @as(f32, @floatFromInt(self.width)) * 0.5;
        const stroke = stroke_width * @as(f32, @floatFromInt(self.width)) * 0.5;
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
                    self.setPixel(x0 + x, y0 + y, center.color);
                }
            }
        }
    }

    pub fn drawLine(self: *Canvas, start: Point, end: Point, stroke_width: f32, color: Color) void {
        const start_screen = self.translateToScreenSpace(start.position[0], start.position[1]);
        const end_screen = self.translateToScreenSpace(end.position[0], end.position[1]);
        const half_width: i32 = @intFromFloat(stroke_width * @as(f32, @floatFromInt(self.width)) * 0.25);

        var x0 = start_screen.x;
        var y0 = start_screen.y;
        const dx: i32 = @intCast(@abs(end_screen.x - x0));
        const dy: i32 = @intCast(@abs(end_screen.y - y0));
        const sx: i32 = if (x0 < end_screen.x) 1 else -1;
        const sy: i32 = if (y0 < end_screen.y) 1 else -1;
        var err = dx - dy;

        while (true) {
            // Draw a filled rectangle centered on the current pixel
            self.fillRect(x0 - half_width, y0 - half_width, x0 + half_width, y0 + half_width, color);

            if (x0 == end_screen.x and y0 == end_screen.y) break;
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

    pub fn drawBezierCurve(self: *Canvas, start: Point, end: Point, control: Point, stroke_width: f32, color: Color) void {
        const start_screen = self.translateToScreenSpace(start.position[0], start.position[1]);
        const end_screen = self.translateToScreenSpace(end.position[0], end.position[1]);
        const control_screen = self.translateToScreenSpace(control.position[0], control.position[1]);

        const steps = 1000; // Increase for smoother curve
        const half_width = @as(i32, @intFromFloat(stroke_width * @as(f32, @floatFromInt(self.width)) * 0.25));

        var t: f32 = 0;
        while (t <= 1.0) : (t += 1.0 / @as(f32, steps)) {
            const x = @as(i32, @intFromFloat(math.pow(f32, 1 - t, 2) * @as(f32, @floatFromInt(start_screen.x)) +
                2 * (1 - t) * t * @as(f32, @floatFromInt(control_screen.x)) +
                math.pow(f32, t, 2) * @as(f32, @floatFromInt(end_screen.x))));
            const y = @as(i32, @intFromFloat(math.pow(f32, 1 - t, 2) * @as(f32, @floatFromInt(start_screen.y)) +
                2 * (1 - t) * t * @as(f32, @floatFromInt(control_screen.y)) +
                math.pow(f32, t, 2) * @as(f32, @floatFromInt(end_screen.y))));

            // Draw a filled circle at each point for smooth, thick lines
            var dy: i32 = -half_width;
            while (dy <= half_width) : (dy += 1) {
                var dx: i32 = -half_width;
                while (dx <= half_width) : (dx += 1) {
                    if (dx * dx + dy * dy <= half_width * half_width) {
                        self.setPixel(x + dx, y + dy, color);
                    }
                }
            }
        }
    }

    fn fillRect(self: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        const start_x = @max(0, @min(x1, x2));
        const end_x = @min(@as(i32, @intCast(self.width)) - 1, @max(x1, x2));
        const start_y = @max(0, @min(y1, y2));
        const end_y = @min(@as(i32, @intCast(self.height)) - 1, @max(y1, y2));

        const rgba = color.toRGBA();
        var y = start_y;
        while (y <= end_y) : (y += 1) {
            var x = start_x;
            while (x <= end_x) : (x += 1) {
                const index = (@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))) * 4;
                self.buffer[index] = rgba[0];
                self.buffer[index + 1] = rgba[1];
                self.buffer[index + 2] = rgba[2];
                self.buffer[index + 3] = rgba[3];
            }
        }
    }

    fn setPixel(self: *Canvas, x: i32, y: i32, color: Color) void {
        if (x < 0 or x >= @as(i32, @intCast(self.width)) or y < 0 or y >= @as(i32, @intCast(self.height))) {
            return;
        }

        const index = (@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))) * 4;
        const rgba = color.toRGBA();
        self.buffer[index] = rgba[0]; // R
        self.buffer[index + 1] = rgba[1]; // G
        self.buffer[index + 2] = rgba[2]; // B
        self.buffer[index + 3] = rgba[3]; // A
    }

    pub fn setClearColor(self: *Canvas, color: Color) void {
        const rgba = color.toRGBA();
        var i: usize = 0;
        while (i < self.clear_pattern.len) : (i += 4) {
            self.clear_pattern[i] = rgba[0];
            self.clear_pattern[i + 1] = rgba[1];
            self.clear_pattern[i + 2] = rgba[2];
            self.clear_pattern[i + 3] = rgba[3];
        }
    }

    pub fn chromaticAberration(self: *Canvas, max_offset_x: i32, max_offset_y: i32) void {
        const temp_buffer = self.allocator.alloc(u8, self.buffer.len) catch unreachable;
        defer self.allocator.free(temp_buffer);

        @memcpy(temp_buffer, self.buffer);

        const center_x = @as(f32, @floatFromInt(self.width)) / 2;
        const center_y = @as(f32, @floatFromInt(self.height)) / 2;
        const max_distance = @sqrt(center_x * center_x + center_y * center_y);

        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const dx = @as(f32, @floatFromInt(x)) - center_x;
                const dy = @as(f32, @floatFromInt(y)) - center_y;
                const distance = @sqrt(dx * dx + dy * dy);
                const intensity = distance / max_distance;

                const offset_x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(max_offset_x)) * intensity));
                const offset_y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(max_offset_y)) * intensity));

                const index = (y * self.width + x) * 4;

                // Red channel
                const red_x = @as(i32, @intCast(x)) + offset_x;
                const red_y = @as(i32, @intCast(y)) + offset_y;
                if (red_x >= 0 and red_x < @as(i32, @intCast(self.width)) and
                    red_y >= 0 and red_y < @as(i32, @intCast(self.height)))
                {
                    const red_index = (@as(usize, @intCast(red_y)) * self.width + @as(usize, @intCast(red_x))) * 4;
                    self.buffer[index] = temp_buffer[red_index];
                }

                // Blue channel
                const blue_x = @as(i32, @intCast(x)) - offset_x;
                const blue_y = @as(i32, @intCast(y)) - offset_y;
                if (blue_x >= 0 and blue_x < @as(i32, @intCast(self.width)) and
                    blue_y >= 0 and blue_y < @as(i32, @intCast(self.height)))
                {
                    const blue_index = (@as(usize, @intCast(blue_y)) * self.width + @as(usize, @intCast(blue_x))) * 4 + 2;
                    self.buffer[index + 2] = temp_buffer[blue_index];
                }

                // Green channel and alpha remain unchanged
                self.buffer[index + 1] = temp_buffer[index + 1];
                self.buffer[index + 3] = temp_buffer[index + 3];
            }
        }
    }

    pub fn fastBlur(self: *Canvas, radius: usize) void {
        const temp_buffer = self.allocator.alloc(u8, self.buffer.len) catch unreachable;
        defer self.allocator.free(temp_buffer);

        const integral = self.allocator.alloc([4]u32, (self.width + 1) * (self.height + 1)) catch unreachable;
        defer self.allocator.free(integral);

        // Calculate integral image
        var y: usize = 0;
        while (y <= self.height) : (y += 1) {
            var x: usize = 0;
            while (x <= self.width) : (x += 1) {
                if (x == 0 or y == 0) {
                    integral[y * (self.width + 1) + x] = .{ 0, 0, 0, 0 };
                } else {
                    const index = ((y - 1) * self.width + (x - 1)) * 4;
                    integral[y * (self.width + 1) + x] = .{
                        integral[(y - 1) * (self.width + 1) + x][0] +
                            integral[y * (self.width + 1) + (x - 1)][0] -
                            integral[(y - 1) * (self.width + 1) + (x - 1)][0] +
                            self.buffer[index],

                        integral[(y - 1) * (self.width + 1) + x][1] +
                            integral[y * (self.width + 1) + (x - 1)][1] -
                            integral[(y - 1) * (self.width + 1) + (x - 1)][1] +
                            self.buffer[index + 1],

                        integral[(y - 1) * (self.width + 1) + x][2] +
                            integral[y * (self.width + 1) + (x - 1)][2] -
                            integral[(y - 1) * (self.width + 1) + (x - 1)][2] +
                            self.buffer[index + 2],

                        integral[(y - 1) * (self.width + 1) + x][3] +
                            integral[y * (self.width + 1) + (x - 1)][3] -
                            integral[(y - 1) * (self.width + 1) + (x - 1)][3] +
                            self.buffer[index + 3],
                    };
                }
            }
        }

        // Apply box blur using integral image
        y = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const x1 = if (x >= radius) x - radius else 0;
                const y1 = if (y >= radius) y - radius else 0;
                const x2 = if (x + radius < self.width) x + radius else self.width - 1;
                const y2 = if (y + radius < self.height) y + radius else self.height - 1;

                const count = (x2 - x1 + 1) * (y2 - y1 + 1);

                const sum = [4]u32{
                    integral[(y2 + 1) * (self.width + 1) + (x2 + 1)][0] -
                        integral[(y1) * (self.width + 1) + (x2 + 1)][0] -
                        integral[(y2 + 1) * (self.width + 1) + x1][0] +
                        integral[y1 * (self.width + 1) + x1][0],

                    integral[(y2 + 1) * (self.width + 1) + (x2 + 1)][1] -
                        integral[(y1) * (self.width + 1) + (x2 + 1)][1] -
                        integral[(y2 + 1) * (self.width + 1) + x1][1] +
                        integral[y1 * (self.width + 1) + x1][1],

                    integral[(y2 + 1) * (self.width + 1) + (x2 + 1)][2] -
                        integral[(y1) * (self.width + 1) + (x2 + 1)][2] -
                        integral[(y2 + 1) * (self.width + 1) + x1][2] +
                        integral[y1 * (self.width + 1) + x1][2],

                    integral[(y2 + 1) * (self.width + 1) + (x2 + 1)][3] -
                        integral[(y1) * (self.width + 1) + (x2 + 1)][3] -
                        integral[(y2 + 1) * (self.width + 1) + x1][3] +
                        integral[y1 * (self.width + 1) + x1][3],
                };

                const index = (y * self.width + x) * 4;
                temp_buffer[index] = @intCast(sum[0] / count);
                temp_buffer[index + 1] = @intCast(sum[1] / count);
                temp_buffer[index + 2] = @intCast(sum[2] / count);
                temp_buffer[index + 3] = @intCast(sum[3] / count);
            }
        }

        // Copy result back to main buffer
        @memcpy(self.buffer, temp_buffer);
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

    pub fn addFilmGrain(self: *Canvas, intensity: f32, seed: u32) void {
        var rng = LCG.init(seed);

        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const index = (y * self.width + x) * 4;

                // Generate random noise value
                const noise = (rng.nextFloat() - 0.5) * intensity;

                // Apply noise to each channel
                inline for (0..3) |i| {
                    const pixel_value = @as(f32, @floatFromInt(self.buffer[index + i]));
                    const new_value = @min(255, @max(0, pixel_value + noise * 255));
                    self.buffer[index + i] = @intFromFloat(new_value);
                }

                // Don't modify alpha channel
            }
        }
    }

    pub fn getBufferPtr(self: *Canvas) [*]u8 {
        return self.buffer.ptr;
    }
};

// Allocate 2 points on stack
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points = [_]Point{
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
};

var canvas: Canvas = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();

    canvas = Canvas.init(allocator, width, height) catch unreachable;
    canvas.setClearColor(.White);

    _ = points[0]
        .setPosition(0.9, -0.9)
        .setOscillation(0.04, 0.04, 2, 1)
        .setVelocity(-0.008, 0.004);
    _ = points[1]
        .setPosition(0.0, 0.0)
        .setOscillation(0.04, 0.04, 2, 1)
        .followPoint(&points[2]);
    _ = points[2]
        .setPosition(-0.5, 0.8)
        .setOscillation(0.01, 0.01, 2, 1)
        .setVelocity(0.004, -0.004);
    _ = points[3]
        .setPosition(0.9, 0.9)
        .setVelocity(-0.008, -0.008);
}

export fn go() [*]const u8 {
    canvas.clear();

    for (&points) |*point| {
        _ = point.update();
    }
    canvas.paintCircle(points[0], 0.1, 0.01);
    canvas.paintCircle(points[1], 0.1, 0.01);
    canvas.paintCircle(points[2], 0.1, 0.01);
    canvas.paintCircle(points[3], 0.03, @abs(points[0].position[1]) / 4 + 0.01);
    canvas.drawBezierCurve(points[0], points[1], points[3], 0.012, points[0].color);
    canvas.drawBezierCurve(points[1], points[2], points[3], 0.012, points[0].color);
    canvas.drawBezierCurve(points[2], points[0], points[3], 0.012, points[0].color);
    canvas.drawBezierCurve(points[0], points[1], points[3], 0.012, points[0].color);
    canvas.fastBlur(@intFromFloat(@abs(points[0].position[0]) * 64));
    canvas.chromaticAberration(8, 12);
    canvas.addFilmGrain(0.4, @intFromFloat(@abs(points[0].position[0]) * 16));
    return canvas.getBufferPtr();
}

export fn deinit() void {
    canvas.deinit();
    _ = gpa.deinit();
}
