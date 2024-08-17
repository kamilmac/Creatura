const std = @import("std");
const math = std.math;
const Canvas = @import("canvas.zig").Canvas;
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
