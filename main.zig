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

    pub fn init() Point {
        return .{
            .position = .{ 0, 0 },
            .velocity = .{ 0, 0 },
            .target = null,
            .color = .Black,
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

    pub fn update(self: *Point) *Point {
        if (self.target) |t| {
            const dx = t.position[0] - self.position[0];
            const dy = t.position[1] - self.position[1];
            self.velocity[0] += dx * 0.1;
            self.velocity[1] += dy * 0.1;
        }

        self.position[0] += self.velocity[0];
        self.position[1] += self.velocity[1];

        // Simple damping
        self.velocity[0] *= 0.994;
        self.velocity[1] *= 0.994;

        // Basic boundary check
        self.position[0] = math.clamp(self.position[0], -1.0, 1.0);
        self.position[1] = math.clamp(self.position[1], -1.0, 1.0);

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

var rasterizer: Canvas = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();

    rasterizer = Canvas.init(allocator, width, height) catch unreachable;
    rasterizer.setClearColor(.White);

    _ = points[0]
        .setPosition(0.9, -0.9)
        .setVelocity(-0.008, 0.004);
    _ = points[1]
        .setPosition(0.0, 0.0)
        .followPoint(&points[2]);
    _ = points[2]
        .setPosition(-0.5, 0.8)
        .setVelocity(0.004, -0.004);

    // Control point for bezier curve
    _ = points[3]
        .setPosition(0.9, 0.9)
        .setVelocity(-0.008, -0.008);
    // .followPoint(&points[1]);
}

export fn go() [*]const u8 {
    rasterizer.clear();

    for (&points) |*point| {
        _ = point.update();
    }
    rasterizer.paintCircle(points[0], 0.1, 0.01);
    rasterizer.paintCircle(points[1], 0.1, 0.01);
    rasterizer.paintCircle(points[2], 0.1, 0.01);
    rasterizer.paintCircle(points[3], 0.03, @abs(points[3].position[1]) / 4 + 0.01);
    rasterizer.drawBezierCurve(points[0], points[1], points[3], 0.008, points[0].color);
    rasterizer.drawBezierCurve(points[1], points[2], points[3], 0.008, points[0].color);
    rasterizer.drawBezierCurve(points[2], points[0], points[3], points[0].position[0] / 4, points[0].color);
    rasterizer.drawBezierCurve(points[0], points[1], points[3], 0.008, points[0].color);
    return rasterizer.getBufferPtr();
}

export fn deinit() void {
    rasterizer.deinit();
    _ = gpa.deinit();
}
