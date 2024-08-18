const std = @import("std");
const math = std.math;
const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;
const Allocator = std.mem.Allocator;

// Allocate 2 points on stack
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var points = [_]Point{
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
    canvas.setClearColor(.White);

    _ = points[0]
        .setPosition(0.9, -0.9)
        .setOscillation(0.04, 0.04, 2, 1)
        .setVelocity(-0.008, 0.004);
    _ = points[1]
        .setPosition(0.0, 0.0)
        .setOscillation(0.04, 0.04, 2, 1)
        .followPoint(&points[2]);
    _ = points[2]
        .setPosition(-0.5, 0.8)
        .setOscillation(0.01, 0.01, 2, 1)
        .setVelocity(0.004, -0.004);
    _ = points[3]
        .setPosition(0.9, 0.9)
        .setVelocity(-0.008, -0.008);

    _ = points[4]
        .setPosition(-0.6, 0.6);
    _ = points[5]
        .setPosition(0.6, 0.6);
    _ = points[6]
        .setPosition(0.6, -0.6);
    _ = points[7]
        .setPosition(-0.6, -0.6);
}

export fn go() [*]const u8 {
    canvas.clear();

    for (&points) |*point| {
        _ = point.update();
    }
    canvas.paintCircle(points[0], 0.1, 0.01, .Black);
    canvas.paintCircle(points[1], 0.1, 0.01, .Black);
    canvas.paintCircle(points[2], 0.1, 0.01, .Black);
    canvas.paintCircle(points[3], 0.3, @abs(points[0].position[1]) / 4 + 0.01, .Black);

    canvas.paintCircle(points[4], 0.5, @abs(points[0].position[1]) / 4 + 0.01, .Black);
    canvas.paintCircle(points[5], 0.37, @abs(points[1].position[1]) / 3 + 0.01, .Black);
    canvas.paintCircle(points[6], 0.29, @abs(points[1].position[1]) / 4 + 0.01, .Black);
    canvas.paintCircle(points[7], 0.22, @abs(points[0].position[1]) / 3 + 0.01, .Black);

    canvas.drawBezierCurve(points[0], points[1], points[3], 0.012, .Black);
    canvas.drawBezierCurve(points[1], points[2], points[3], 0.012, .Black);
    canvas.drawBezierCurve(points[2], points[0], points[3], 0.012, .Black);
    canvas.drawBezierCurve(points[0], points[1], points[3], 0.012, .Black);
    canvas.chromaticAberration(8, 8);
    canvas.fastBlur(1, 20);
    // canvas.applyLensDistortion(1024);
    canvas.addFilmGrain(0.5);
    return canvas.getBufferPtr();
}

export fn deinit() void {
    canvas.deinit();
    _ = gpa.deinit();
}
