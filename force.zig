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
    start: Point,
    control: Point,
    target: Point,
    t: f32,

    pub fn init(strength: f32, pid: u32) RandomForce {
        return .{
            .pid = pid,
            .strength = strength,
            .start = Point.init(0, 0, null),
            .control = Point.init(0, 0, null),
            .target = Point.init(0, 0, null),
            .t = 1.0, // Start at 1.0 to generate a new curve immediately
        };
    }

    pub fn process(self: *RandomForce, points: []Point) void {
        if (self.t >= 1.0) {
            // Generate new Bézier curve
            self.start = self.target;
            self.control = Point.init(rng.random().float(f32) * 2 - 1, rng.random().float(f32) * 2 - 1, null);
            self.target = Point.init(rng.random().float(f32) * 2 - 1, rng.random().float(f32) * 2 - 1, null);
            self.t = 0.0;
        }

        for (points) |*point| {
            if (point.id == self.pid) {
                // Calculate position on the Bézier curve
                const bx = quadraticBezier(self.start.x, self.control.x, self.target.x, self.t);
                const by = quadraticBezier(self.start.y, self.control.y, self.target.y, self.t);

                // Move the point towards the Bézier curve position
                point.x += (bx - point.x) * self.strength;
                point.y += (by - point.y) * self.strength;
            }
        }

        self.t += 0.01 * self.strength; // Increase t for smooth transition, scaled by strength
    }

    fn quadraticBezier(p0: f32, p1: f32, p2: f32, t: f32) f32 {
        const oneMinusT = 1.0 - t;
        return oneMinusT * oneMinusT * p0 + 2.0 * oneMinusT * t * p1 + t * t * p2;
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
