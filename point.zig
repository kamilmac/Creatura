const std = @import("std");

pub const Point = struct {
    position: [2]f32,
    velocity: [2]f32,
    target: ?*Point,
    oscillation: struct {
        amplitude: [2]f32,
        frequency: [2]f32,
        offset: f32,
    },
    rotation: struct {
        speed: f32,
        radius: f32,
        angle: f32,
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

    pub fn setOscillation(self: *Point, amplitude_x: f32, amplitude_y: f32, frequency_x: f32, frequency_y: f32) *Point {
        self.oscillation.amplitude = .{ amplitude_x, amplitude_y };
        self.oscillation.frequency = .{ frequency_x, frequency_y };
        return self;
    }

    pub fn update(self: *Point) *Point {
        updatePoint(self);
        return self;
    }

    pub fn addRotation(self: *Point, speed: f32, radius: f32) *Point {
        self.rotation.speed = speed;
        self.rotation.radius = radius;
        self.rotation.angle = 0;
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
        .oscillation = .{
            .amplitude = .{ 0, 0 },
            .frequency = .{ 0, 0 },
            .offset = 0,
        },
        .rotation = .{
            .speed = 0,
            .radius = 0,
            .angle = 0,
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

    if (point.rotation.radius > 0) {
        point.rotation.angle += point.rotation.speed;
        const rotation_x = point.rotation.radius * @cos(point.rotation.angle);
        const rotation_y = point.rotation.radius * @sin(point.rotation.angle);
        point.position[0] += rotation_x;
        point.position[1] += rotation_y;
    }
}

fn oscillatePoint(point: *Point) void {
    const dx = point.oscillation.amplitude[0] * @sin(point.oscillation.frequency[0] * point.oscillation.offset);
    const dy = point.oscillation.amplitude[1] * @sin(point.oscillation.frequency[1] * point.oscillation.offset);

    point.position[0] += dx;
    point.position[1] += dy;

    point.oscillation.offset += 0.1; // Increment offset for next frame
}
