const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const Point = struct {
    x: f32,
    y: f32,
    velocity_x: f32,
    velocity_y: f32,
    target: ?*Point,

    pub fn init() Point {
        return .{
            .x = 0,
            .y = 0,
            .velocity_x = 0,
            .velocity_y = 0,
            .target = null,
        };
    }

    pub fn setPosition(self: *Point, x: f32, y: f32) *Point {
        self.x = x;
        self.y = y;
        return self;
    }

    pub fn setVelocity(self: *Point, vx: f32, vy: f32) *Point {
        self.velocity_x = vx;
        self.velocity_y = vy;
        return self;
    }

    pub fn followPoint(self: *Point, other: *Point) *Point {
        self.target = other;
        return self;
    }

    pub fn update(self: *Point) *Point {
        if (self.target) |t| {
            const dx = t.x - self.x;
            const dy = t.y - self.y;
            self.velocity_x += dx * 0.1;
            self.velocity_y += dy * 0.1;
        }

        self.x += self.velocity_x;
        self.y += self.velocity_y;

        // Simple damping
        self.velocity_x *= 0.994;
        self.velocity_y *= 0.994;

        // Basic boundary check
        self.x = math.clamp(self.x, -1.0, 1.0);
        self.y = math.clamp(self.y, -1.0, 1.0);

        return self;
    }
};

pub const Rasterizer = struct {
    width: usize,
    height: usize,
    buffer: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: usize, height: usize) !Rasterizer {
        const buffer = try allocator.alloc(u8, width * height * 4);
        return Rasterizer{
            .width = width,
            .height = height,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Rasterizer) void {
        self.allocator.free(self.buffer);
    }

    pub fn clear(self: *Rasterizer) void {
        var i: usize = 0;
        while (i < self.buffer.len) : (i += 4) {
            self.buffer[i] = 173; // R
            self.buffer[i + 1] = 216; // G
            self.buffer[i + 2] = 230; // B
            self.buffer[i + 3] = 255; // A
        }
    }

    fn translateToScreenSpace(self: *const Rasterizer, x: f32, y: f32) struct { x: i32, y: i32 } {
        return .{
            .x = @intFromFloat((x + 1) * 0.5 * @as(f32, @floatFromInt(self.width))),
            .y = @intFromFloat((1 - y) * 0.5 * @as(f32, @floatFromInt(self.height))),
        };
    }

    pub fn paintCircle(self: *Rasterizer, center: Point, radius: f32, stroke_width: f32) void {
        const screen_position = self.translateToScreenSpace(center.x, center.y);
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
                    self.setPixel(x0 + x, y0 + y);
                }
            }
        }
    }

    fn setPixel(self: *Rasterizer, x: i32, y: i32) void {
        if (x < 0 or x >= @as(i32, @intCast(self.width)) or y < 0 or y >= @as(i32, @intCast(self.height))) {
            return;
        }

        const index = (@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))) * 4;
        self.buffer[index] = 255; // R
        self.buffer[index + 1] = 0; // G
        self.buffer[index + 2] = 0; // B
        self.buffer[index + 3] = 255; // A
    }

    pub fn getBufferPtr(self: *Rasterizer) [*]u8 {
        return self.buffer.ptr;
    }
};

// Allocate 2 points on stack
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points = [_]Point{
    Point.init(),
    Point.init(),
};

var rasterizer: Rasterizer = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();

    rasterizer = Rasterizer.init(allocator, width, height) catch unreachable;

    _ = points[0]
        .setPosition(0.9, -0.9)
        .setVelocity(-0.008, 0.004);
    _ = points[1]
        .setPosition(0.0, 0.0)
        .followPoint(&points[0]);
}

export fn go() [*]const u8 {
    rasterizer.clear();

    for (&points) |*point| {
        _ = point.update();
        rasterizer.paintCircle(point.*, 0.2, 0.05);
    }

    return rasterizer.getBufferPtr();
}

export fn deinit() void {
    rasterizer.deinit();
    _ = gpa.deinit();
}
