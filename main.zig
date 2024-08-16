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
        self.velocity_x *= 0.99;
        self.velocity_y *= 0.99;

        // Basic boundary check
        self.x = math.clamp(self.x, 0, 255);
        self.y = math.clamp(self.y, 0, 255);

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
        @memset(self.buffer, 0);
    }

    pub fn paintCircle(self: *Rasterizer, center: Point, radius: f32) void {
        const x0: i32 = @intFromFloat(center.x);
        const y0: i32 = @intFromFloat(center.y);
        var r: i32 = @intFromFloat(radius);

        var x: i32 = -r;
        var y: i32 = 0;
        var err: i32 = 2 - 2 * r;

        while (x < 0) : ({
            r = err;
            if (r <= y) {
                y += 1;
                err += y * 2 + 1;
            }
            if (r > x or err > y) {
                x += 1;
                err += x * 2 + 1;
            }
        }) {
            self.setPixel(x0 - x, y0 + y);
            self.setPixel(x0 - y, y0 - x);
            self.setPixel(x0 + x, y0 - y);
            self.setPixel(x0 + y, y0 + x);
        }
    }

    fn setPixel(self: *Rasterizer, x: i32, y: i32) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return;
        }

        const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        self.buffer[index] = 255;
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
        .setPosition(100, 100)
        .setVelocity(1, 1.5);
    _ = points[1]
        .setPosition(200, 200)
        .followPoint(&points[0]);
}

export fn go() [*]const u8 {
    rasterizer.clear();

    for (&points) |*point| {
        _ = point.update();
        rasterizer.paintCircle(point.*, 5);
    }

    return rasterizer.getBufferPtr();
}

export fn deinit() void {
    rasterizer.deinit();
    _ = gpa.deinit();
}
