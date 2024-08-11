const std = @import("std");
const Point = @import("point.zig").Point;

var rng = std.rand.DefaultPrng.init(8);

pub const AttractorForce = struct {
    origin: *Point,
    radius: f32,
    pid: u32,

    pub fn init(origin: *Point, pid: u32) AttractorForce {
        return .{
            .origin = origin,
            .radius = 1.0,
            .pid = pid,
        };
    }

    pub fn process(self: *AttractorForce, points: []Point) void {
        for (points) |*point| {
            if (point.id == self.pid) {
                const dx = self.origin.x - point.x;
                const dy = self.origin.y - point.y;
                const distanceSquared = dx * dx + dy * dy;
                if (distanceSquared <= self.radius * self.radius) {
                    point.x += dx / 40;
                    point.y += dy / 40;
                }
            }
        }
    }
};

pub const RandomForce = struct {
    strength: f32,
    pid: u32,
    target: Point,
    t: f32,

    pub fn init(strength: f32, pid: u32) RandomForce {
        return .{
            .pid = pid,
            .strength = strength,
            .target = Point.init(0, 0, null),
            .t = 1.0, // Start at 1.0 to generate a new target immediately
        };
    }

    pub fn process(self: *RandomForce, points: []Point) void {
        if (self.t >= 1.0) {
            // Generate new random target
            self.target.x = rng.random().float(f32) * 2 - 1; // Range: -1 to 1
            self.target.y = rng.random().float(f32) * 2 - 1; // Range: -1 to 1
            self.t = 0.0;
        }

        for (points) |*point| {
            if (point.id == self.pid) {
                // Linear interpolation (lerp)
                point.x += (self.target.x - point.x) * self.strength * self.t;
                point.y += (self.target.y - point.y) * self.strength * self.t;
            }
        }

        self.t += 0.01; // Increase t for smooth transition
    }
};

pub const Force = union(enum) {
    Attractor: AttractorForce,
    Random: RandomForce,

    pub fn process(self: *Force, points: []Point) void {
        switch (self.*) {
            inline else => |*force| force.process(points),
        }
    }
};
