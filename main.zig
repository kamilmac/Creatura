const std = @import("std");
const math = std.math;
const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;
const setup = @import("setups.zig").setupA;
const animate = @import("setups.zig").animateA;
const Allocator = std.mem.Allocator;

// Allocate 2 points on stack
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points = [16]Point{
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
    Point.init(),
};

var canvas: Canvas = undefined;

export fn init(width: usize, height: usize) void {
    const allocator = gpa.allocator();
    canvas = Canvas.init(allocator, width, height) catch unreachable;
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
