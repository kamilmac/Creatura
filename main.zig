const std = @import("std");
const math = std.math;
const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;
const setupB = @import("setups.zig").setupB;
const animateB = @import("setups.zig").animateB;
const Allocator = std.mem.Allocator;

pub const NUM_POINTS: i32 = 256;

const Setup = struct {
    setup: *const fn (*Canvas, *[NUM_POINTS]Point) void,
    animate: *const fn (*Canvas, *[NUM_POINTS]Point, f32, f32) void,
};

const setups = [_]Setup{
    .{ .setup = @import("setups.zig").setupA, .animate = @import("setups.zig").animateA },
    .{ .setup = @import("setups.zig").setupB, .animate = @import("setups.zig").animateB },
};

var current_setup: usize = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points: [NUM_POINTS]Point = undefined;
var canvas: Canvas = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();
    canvas = Canvas.init(allocator, width, height) catch unreachable;
    for (&points) |*point| {
        point.* = Point.init();
    }
    setups[current_setup].setup(&canvas, &points);
}

export fn go(mouseX: f32, mouseY: f32) [*]const u8 {
    setups[current_setup].animate(&canvas, &points, mouseX, mouseY);
    return canvas.getBufferPtr();
}

export fn toggle() void {
    current_setup = (current_setup + 1) % setups.len;
    init(canvas.width, canvas.height);
    init(canvas.width, canvas.height);
    // deinit();
}

export fn deinit() void {
    canvas.deinit();
    points = undefined;
    _ = gpa.deinit();
}
