const std = @import("std");
const math = std.math;
const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;
const setup = @import("setups.zig").setupB;
const animate = @import("setups.zig").animateB;
const Allocator = std.mem.Allocator;

pub const NUM_POINTS: i32 = 16;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points: [NUM_POINTS]Point = undefined;
var canvas: Canvas = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();
    canvas = Canvas.init(allocator, width, height) catch unreachable;
    for (&points) |*point| {
        point.* = Point.init();
    }
    setup(&canvas, &points);
}

export fn go(mouseX: f32, mouseY: f32) [*]const u8 {
    animate(&canvas, &points, mouseX, mouseY);
    return canvas.getBufferPtr();
}

export fn deinit() void {
    canvas.deinit();
    _ = gpa.deinit();
}
