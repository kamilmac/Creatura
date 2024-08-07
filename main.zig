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
    radius: f32 = 1.0,
    points: std.ArrayList(*Point),

    pub fn init(allocator: std.mem.Allocator, x: f32, y: f32) AttractorForce {
        return AttractorForce{
            .x = x,
            .y = y,
            .points = std.ArrayList(*Point).init(allocator),
        };
    }

    pub fn connectPoint(self: *AttractorForce, p: *Point) !void {
        try self.points.append(p);
    }

    pub fn process(self: *AttractorForce) void {
        for (self.points.items) |point| {
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

const App = struct {
    allocator: std.mem.Allocator,
    points: std.ArrayList(*Point),
    forces: std.ArrayList(*AttractorForce),
    buffer: []u8,
    canvas: Canvas,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !App {
        return App{
            .allocator = allocator,
            .points = std.ArrayList(*Point).init(allocator),
            .forces = std.ArrayList(*AttractorForce).init(allocator),
            .buffer = allocator.alloc(u8, width * height * 4) catch unreachable,
            .canvas = Canvas{ .width = width, .height = height },
        };
    }

    pub fn addForce(self: *App, force: AttractorForce) !*AttractorForce {
        const forcePtr = try self.allocator.create(AttractorForce);
        forcePtr.* = force;
        try self.forces.append(forcePtr);
        return forcePtr;
    }

    pub fn addPoint(self: *App, x: f32, y: f32) !*Point {
        const pointPtr = try self.allocator.create(Point);
        pointPtr.* = Point{ .x = x, .y = y };
        try self.points.append(pointPtr);
        return pointPtr;
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
            const buffer_index: u32 = (@as(u32, @intCast(y)) * self.canvas.width + @as(u32, @intCast(x))) * 4;
            if (buffer_index + 3 < self.buffer.len) {
                self.buffer[buffer_index + 0] = brightness;
                self.buffer[buffer_index + 1] = brightness;
                self.buffer[buffer_index + 2] = brightness;
                self.buffer[buffer_index + 3] = 255;
            }
        }
    }

    pub fn deinit(self: *App) void {
        for (self.points.items) |pointPtr| {
            self.allocator.destroy(pointPtr);
        }
        self.points.deinit();

        for (self.forces.items) |forcePtr| {
            self.allocator.destroy(forcePtr);
        }
        self.forces.deinit();

        self.allocator.free(self.buffer);
    }
};

var rng = std.rand.DefaultPrng.init(0);
var app: App = undefined;

export fn init(width: u32, height: u32) void {
    app = App.init(std.heap.page_allocator, width, height) catch unreachable;
    defer app.deinit();
    const a1 = app.addForce(AttractorForce.init(app.allocator, 0.6, 0.6)) catch unreachable;
    const a2 = app.addForce(AttractorForce.init(app.allocator, 0.0, 0.6)) catch unreachable;
    const a3 = app.addForce(AttractorForce.init(app.allocator, 0.6, -0.6)) catch unreachable;
    const p1 = app.addPoint(0.0, 0.0) catch unreachable;
    _ = a1.connectPoint(p1) catch unreachable;
    _ = a2.connectPoint(p1) catch unreachable;
    _ = a3.connectPoint(p1) catch unreachable;
    app.clearBuffer();
}

export fn go(timeSinceStart: f32) [*]const u8 {
    if (timeSinceStart > 8000) {
        // You might want to add some behavior here
    }

    for (app.points.items) |point| {
        app.drawPointToBuffer(point.x, point.y, 255);
    }

    for (app.forces.items) |item| {
        item.process();
        app.drawPointToBuffer(item.x, item.y, 0);
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

// export fn deinit() void {
//     app.deinit();
// }
