const std = @import("std");
const Color = @import("color.zig").Color;

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
        return initPoint();
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

    pub fn update(self: *Point) *Point {
        updatePoint(self);
        return self;
    }

    fn oscillate(self: *Point) void {
        oscillatePoint(self);
    }
};

fn initPoint() Point {
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

fn updatePoint(point: *Point) void {
    if (point.target) |t| {
        const dx = t.position[0] - point.position[0];
        const dy = t.position[1] - point.position[1];
        point.velocity[0] += dx * 0.1;
        point.velocity[1] += dy * 0.1;
    }

    point.position[0] += point.velocity[0];
    point.position[1] += point.velocity[1];

    // Apply oscillation
    point.oscillate();

    // Simple damping
    point.velocity[0] *= 0.994;
    point.velocity[1] *= 0.994;

    // Basic boundary check
    point.position[0] = @max(-1.0, @min(point.position[0], 1.0));
    point.position[1] = @max(-1.0, @min(point.position[1], 1.0));
}

fn oscillatePoint(point: *Point) void {
    const dx = point.oscillation.amplitude[0] * @sin(point.oscillation.frequency[0] * point.oscillation.offset);
    const dy = point.oscillation.amplitude[1] * @sin(point.oscillation.frequency[1] * point.oscillation.offset);

    point.position[0] += dx;
    point.position[1] += dy;

    point.oscillation.offset += 0.1; // Increment offset for next frame
}
