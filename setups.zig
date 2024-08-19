const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;

pub fn setupA(c: *Canvas, p: *[16]Point) void {
    c.setClearColor(.White);
    _ = p[0]
        .setPosition(0.9, -0.9)
    // .setOscillation(0.04, 0.04, 2, 1)
        .addRotation(0.1, 0.05)
        .setVelocity(-0.008, 0.004);
    _ = p[1]
        .setPosition(0.0, 0.0)
        .setOscillation(0.09, -0.04, 2, 2)
        .followPoint(&p[2]);
    _ = p[2]
        .setPosition(-0.5, 0.8)
        .setOscillation(0.01, 0.01, 2, 1)
        .setVelocity(0.004, -0.004);
    _ = p[3]
        .setPosition(0.9, 0.9)
        .setVelocity(-0.008, -0.008);

    _ = p[4]
        .setPosition(-0.6, 0.6)
        .setOscillation(0.001, 0.001, 1.3, 0.3);
    _ = p[5]
        .setPosition(0.6, 0.6)
        .setOscillation(0.001, 0.001, 1.3, 0.3);
    _ = p[6]
        .setPosition(0.6, -0.6)
        .setOscillation(0.001, 0.001, 1.3, 0.3);
    _ = p[7]
        .setPosition(-0.6, -0.6);
    // .setOscillation(0.001, 0.001, 1.3, 0.3);

    _ = p[8]
        .setPosition(-0.6, -0.0);
}

pub fn animateA(c: *Canvas, p: *[16]Point, mx: f32, my: f32) void {
    c.clear();

    if (mx != 0 and my != 0) {
        _ = p[0].setPosition(mx, my);
    }

    for (p) |*point| {
        _ = point.update();
    }

    // c.paintCircle(p[0], 0.3, 0.01, .Blue);
    c.paintCircle(p[1], 0.1, 0.4, .Black);
    c.paintCircle(p[2], 0.3, 0.01, .Black);
    c.paintCircle(p[3], 0.3, @abs(p[0].position[1]) / 4 + 0.01, .Black);

    c.renderWetSpot(p[0], 2.0, .LightGrey);

    c.paintCircle(p[4], 0.5, @abs(p[0].position[1]) / 4 + 0.01, .Black);
    c.paintCircle(p[5], 0.37, @abs(p[1].position[1]) / 3 + 0.01, .Black);
    c.paintCircle(p[6], 0.29, @abs(p[1].position[1]) / 4 + 0.01, .Black);
    c.paintCircle(p[7], 0.22, @abs(p[0].position[1]) / 3 + 0.01, .Black);

    c.drawBezierCurve(p[0], p[1], p[3], 0.012, .Black);
    c.drawBezierCurve(p[1], p[2], p[3], 0.012, .Black);
    c.drawBezierCurve(p[2], p[0], p[3], 0.012, .Black);
    c.drawBezierCurve(p[0], p[1], p[3], 0.012, .Black);

    c.drawWigglyLine(p[7], p[1], 0.05, p[7].position[0] * 20, p[7].position[1] * 2, 0.01, .Black);

    c.fastBlur(1, 6, p[0]);
    c.chromaticAberration(4, 4);
    c.applyLensDistortion(384);
    c.addFilmGrain(0.3);
}

pub fn setupB(c: *Canvas, p: *[16]Point) void {
    c.setClearColor(.White);
    _ = p[0]
        .setPosition(0.0, 0.0);
    _ = p[1]
        .setPosition(0.4, -0.4)
        .addRotation(0.01, 0.01);
    _ = p[2]
        .setPosition(0.4, 0.4)
        .addRotation(0.02, 0.02);
    _ = p[3]
        .setPosition(-0.4, -0.4)
        .addRotation(0.02, 0.05);
    _ = p[4]
        .setPosition(-0.4, 0.4)
        .addRotation(0.03, 0.03);
}

pub fn animateB(c: *Canvas, p: *[16]Point, mx: f32, my: f32) void {
    c.clear();

    if (mx != 0 and my != 0) {
        _ = p[0].setPosition(mx, my);
    }

    for (p) |*point| {
        _ = point.update();
    }

    c.renderWetSpot(p[1], 2.0, .Black);
    c.renderWetSpot(p[2], 3.0, .LightGrey);
    c.renderWetSpot(p[3], 1.0, .Black);
    c.renderWetSpot(p[4], 2.0, .LightGrey);

    // c.drawBezierCurve(p[1], p[2], p[0], 0.212, .Black);
    // c.drawBezierCurve(p[2], p[3], p[0], 0.212, .Black);
    // c.drawBezierCurve(p[3], p[4], p[0], 0.212, .Black);
    // c.drawBezierCurve(p[4], p[1], p[0], 0.212, .Black);

    c.drawWigglyLine(p[1], p[2], 0.05, 10, 2, 0.03, .White);
    c.drawWigglyLine(p[2], p[3], 0.05, 20, 2, 0.03, .White);
    c.drawWigglyLine(p[3], p[4], 0.05, 40, 2, 0.03, .White);
    c.drawWigglyLine(p[4], p[1], 0.05, 20, 2, 0.03, .White);
    c.drawWigglyLine(p[3], p[1], 0.05, 8, 2, 0.03, .White);
    c.drawWigglyLine(p[2], p[4], 0.05, 20, 2, 0.03, .White);

    c.fastBlur(1, 16, p[0]);
    // c.chromaticAberration(4, 4);
    c.applyLensDistortion(384);
    c.addFilmGrain(0.1);
}
