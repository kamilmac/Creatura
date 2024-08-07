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

    pub fn init(x: f32, y: f32) AttractorForce {
        return AttractorForce{
            .x = x,
            .y = y,
        };
    }

    pub fn process(self: *AttractorForce, point: *Point) void {
        const dx = self.x - point.x;
        const dy = self.y - point.y;
        const distanceSquared = dx * dx + dy * dy;
        if (distanceSquared <= self.radius * self.radius) {
            point.x += dx / 40;
            point.y += dy / 40;
        }
    }
};

const App = struct {
    points: std.ArrayList(Point),
    forces: std.ArrayList(AttractorForce),
    buffer: []u8,
    canvas: Canvas,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !App {
        var _app = App{
            .points = std.ArrayList(Point).init(allocator),
            .forces = std.ArrayList(AttractorForce).init(allocator),
            .buffer = allocator.alloc(u8, width * height * 4) catch unreachable,
            .canvas = Canvas{ .width = width, .height = height },
        };

        try _app.points.append(Point{ .x = 0.0, .y = 0.0 });
        try _app.forces.append(AttractorForce.init(0.6, 0.6));

        return _app;
    }

    pub fn deinit(self: *App) void {
        self.points.deinit();
        self.forces.deinit();
    }
};

var rng = std.rand.DefaultPrng.init(0);
var app: App = undefined;

export fn init(width: u32, height: u32) void {
    const allocator = std.heap.page_allocator;
    app = App.init(allocator, width, height) catch unreachable;

    var index: usize = 0;
    while (index < app.buffer.len) : (index += 4) {
        app.buffer[index + 0] = 100;
        app.buffer[index + 1] = 255;
        app.buffer[index + 2] = 123;
        app.buffer[index + 3] = 255;
    }
}

fn log(message: []const u8) void {
    js_console_log(message.ptr, message.len);
}

fn logInt(value: i32) void {
    var buf: [32]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    log(formatted);
}

fn drawPointToBuffer(xx: f32, yy: f32, brightness: u8) void {
    const cx: f32 = @floatFromInt(app.canvas.width);
    const cy: f32 = @floatFromInt(app.canvas.height);
    const x: i32 = @intFromFloat((xx / 2 + 0.5) * cx);
    const y: i32 = @intFromFloat((yy / 2 + 0.5) * cy);

    if (x >= 0 and y >= 0 and x < app.canvas.width and y < app.canvas.height) {
        const buffer_index: u32 = (@as(u32, @intCast(y)) * app.canvas.width + @as(u32, @intCast(x))) * 4;
        if (buffer_index + 3 < app.buffer.len) {
            app.buffer[buffer_index + 0] = brightness;
            app.buffer[buffer_index + 1] = brightness;
            app.buffer[buffer_index + 2] = brightness;
            app.buffer[buffer_index + 3] = 255;
        }
    }
}

export fn go(timeSinceStart: f32) [*]const u8 {
    if (timeSinceStart > 8000) {
        // You might want to add some behavior here
    }

    if (app.forces.items.len > 0 and app.points.items.len > 0) {
        app.forces.items[0].process(&app.points.items[0]);
    }

    for (app.points.items) |point| {
        drawPointToBuffer(point.x, point.y, 255);
    }

    for (app.forces.items) |force| {
        drawPointToBuffer(force.x, force.y, 0);
    }

    return app.buffer.ptr;
}

export fn deinit() void {
    app.deinit();
}
