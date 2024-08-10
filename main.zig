const std = @import("std");

extern "env" fn js_console_log(ptr: [*]const u8, len: usize) void;

const Canvas = struct {
    height: u32,
    width: u32,
};

const Point = struct {
    x: f32,
    y: f32,
};

const AttractorForce = struct {
    x: f32,
    y: f32,
    radius: f32,
    points: []Point,

    pub fn init(x: f32, y: f32, points: []Point) AttractorForce {
        return .{
            .x = x,
            .y = y,
            .radius = 1.0,
            .points = points,
        };
    }

    pub fn process(self: *AttractorForce) void {
        for (self.points) |*point| {
            const dx = self.x - point.x;
            const dy = self.y - point.y;
            const distanceSquared = dx * dx + dy * dy;
            if (distanceSquared <= self.radius * self.radius) {
                point.x += dx / 40;
                point.y += dy / 40;
            }
        }
    }
};

const WindForce = struct {
    strength: f32,
    points: []Point,

    pub fn init(strength: f32, points: []Point) WindForce {
        return .{
            .strength = strength,
            .points = points,
        };
    }

    pub fn process(self: *WindForce) void {
        for (self.points) |*point| {
            point.x += self.strength;
        }
    }
};

const Force = union(enum) {
    Attractor: AttractorForce,
    Wind: WindForce,

    pub fn process(self: *Force) void {
        switch (self.*) {
            inline else => |*force| force.process(),
        }
    }
};

const App = struct {
    points: []Point,
    forces: []Force,
    buffer: []u8,
    canvas: Canvas,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, num_points: usize, num_forces: usize) !App {
        const points = try allocator.alloc(Point, num_points);
        const forces = try allocator.alloc(Force, num_forces);
        const buffer = try allocator.alloc(u8, width * height * 4);

        return App{
            .points = points,
            .forces = forces,
            .buffer = buffer,
            .canvas = Canvas{ .width = width, .height = height },
        };
    }

    pub fn deinit(self: *App, allocator: std.mem.Allocator) void {
        allocator.free(self.points);
        allocator.free(self.forces);
        allocator.free(self.buffer);
    }

    pub fn clearBuffer(self: *App) void {
        var index: usize = 0;
        while (index < self.buffer.len) : (index += 4) {
            self.buffer[index + 0] = 100;
            self.buffer[index + 1] = 255;
            self.buffer[index + 2] = 123;
            self.buffer[index + 3] = 255;
        }
    }

    pub fn drawPointToBuffer(self: *App, xx: f32, yy: f32, brightness: u8) void {
        const cx: f32 = @floatFromInt(self.canvas.width);
        const cy: f32 = @floatFromInt(self.canvas.height);
        const x: i32 = @intFromFloat((xx / 2 + 0.5) * cx);
        const y: i32 = @intFromFloat((yy / 2 + 0.5) * cy);

        if (x >= 0 and y >= 0 and x < self.canvas.width and y < self.canvas.height) {
            const buffer_index: usize = (@as(usize, @intCast(y)) * self.canvas.width + @as(usize, @intCast(x))) * 4;
            if (buffer_index + 3 < self.buffer.len) {
                @memset(self.buffer[buffer_index..][0..4], brightness);
                self.buffer[buffer_index + 3] = 255;
            }
        }
    }
};

var rng = std.rand.DefaultPrng.init(0);
var app: App = undefined;

export fn init(width: u32, height: u32) void {
    const allocator = std.heap.page_allocator;
    app = App.init(allocator, width, height, 128, 4) catch unreachable;

    app.points[0] = .{ .x = 0.0, .y = 0.0 };

    app.forces[0] = Force{ .Attractor = AttractorForce.init(0.6, 0.6, app.points[0..]) };
    app.forces[1] = Force{ .Attractor = AttractorForce.init(0.0, 0.6, app.points[0..]) };
    app.forces[2] = Force{ .Attractor = AttractorForce.init(0.6, -0.6, app.points[0..]) };
    app.forces[3] = Force{ .Wind = WindForce.init(0.01, app.points[0..]) };

    app.clearBuffer();
}

export fn go(timeSinceStart: f32) [*]const u8 {
    if (timeSinceStart > 8000) {
        // You might want to add some behavior here
    }

    for (app.points) |point| {
        app.drawPointToBuffer(point.x, point.y, 255);
    }

    for (app.forces) |*force| {
        force.process();
        switch (force.*) {
            .Attractor => |attractor| app.drawPointToBuffer(attractor.x, attractor.y, 0),
            .Wind => {}, // Wind forces are not drawn
        }
    }

    return app.buffer.ptr;
}

fn log(message: []const u8) void {
    js_console_log(message.ptr, message.len);
}

fn logInt(value: i32) void {
    var buf: [32]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    log(formatted);
}

export fn deinit() void {
    app.deinit(std.heap.page_allocator);
}
