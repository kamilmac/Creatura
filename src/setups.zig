const Canvas = @import("canvas.zig").Canvas;
const Point = @import("point.zig").Point;
const NUM_POINTS = @import("main.zig").NUM_POINTS;

pub fn setupA(c: *Canvas, p: *[NUM_POINTS]Point) void {
    c.setClearColor(.White);
    _ = p[0]
        .setPosition(0.9, -0.9)
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
    _ = p[8]
        .setPosition(-0.6, -0.0);
}

pub fn animateA(c: *Canvas, p: *[NUM_POINTS]Point, mx: f32, my: f32) void {
    c.clear();

    if (mx != 0 and my != 0) {
        _ = p[0].setPosition(mx, my);
    }

    for (p) |*point| {
        _ = point.update();
    }

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
    // c.applyLensDistortion(384);
    c.addFilmGrain(0.3);
}

pub fn setupB(c: *Canvas, p: *[NUM_POINTS]Point) void {
    c.setClearColor(.White);
    _ = p[0]
        .setPosition(0.0, 0.0);
    _ = p[1]
        .setPosition(0.4, -0.4)
        .orbitAround(&p[0], 0.2, 0.2);
    _ = p[2]
        .setPosition(0.4, 0.4)
        .orbitAround(&p[1], 0.2, 0.22);
    _ = p[3]
        .setPosition(-0.4, -0.4)
        .orbitAround(&p[2], 0.2, 0.24);
    _ = p[4]
        .setPosition(-0.4, 0.4)
        .orbitAround(&p[3], 0.2, 0.26);
    _ = p[5]
        .setPosition(-0.4, 0.4)
        .orbitAround(&p[4], 0.2, 0.28);

    _ = p[6]
        .orbitAround(&p[0], 0.8, 0.01);
    _ = p[7]
        .orbitAround(&p[0], 0.8, 0.02);
    _ = p[8]
        .orbitAround(&p[0], 0.8, 0.03);
    _ = p[9]
        .orbitAround(&p[0], 0.8, 0.05);
    _ = p[10]
        .orbitAround(&p[0], 0.8, 0.07);
    _ = p[11]
        .orbitAround(&p[0], 0.8, 0.1);
    _ = p[12]
        .orbitAround(&p[0], 0.8, 0.14);
    _ = p[13]
        .orbitAround(&p[0], 0.8, 0.19);
}

pub fn animateB(c: *Canvas, p: *[NUM_POINTS]Point, mx: f32, my: f32) void {
    c.clear();

    if (mx != 0 and my != 0) {
        _ = p[14].setPosition(mx, my);
    }

    for (p) |*point| {
        _ = point.update();
    }

    c.paintCircle(p[6], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[7], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[8], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[9], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[10], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[11], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[12], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[13], 0.05 + p[14].position[0], 0.04, .LightGrey);

    c.paintCircle(p[14], 0.01, 0.04, .LightGrey);

    c.paintCircle(p[1], 0.1, 0.03, .Black);
    c.renderWetSpot(p[1], 0.2 + p[14].position[1], .LightGrey);
    c.paintCircle(p[2], 0.1, 0.06, .Black);
    c.renderWetSpot(p[2], 0.3 + p[14].position[1], .LightGrey);
    c.paintCircle(p[3], 0.1, 0.08, .Black);
    c.renderWetSpot(p[3], 0.1 + p[14].position[1], .Black);
    c.paintCircle(p[4], 0.1, 0.1, .Black);
    c.paintCircle(p[5], 0.1, 0.1, .Black);

    c.fastBlur(1, 16, p[0]);
    c.chromaticAberration(16, 16);
    // c.applyLensDistortion(512);
    c.addFilmGrain(0.3);
}

pub fn setupC(c: *Canvas, p: *[NUM_POINTS]Point) void {
    c.setClearColor(.Black);
    _ = p[0]
        .setPosition(0.0, 0.0);
    _ = p[1]
        .setPosition(0.4, -0.4)
        .orbitAround(&p[0], 0.2, 0.2);
    _ = p[2]
        .setPosition(0.4, 0.4)
        .orbitAround(&p[1], 0.2, 0.22);
    _ = p[3]
        .setPosition(-0.4, -0.4)
        .orbitAround(&p[2], 0.2, 0.24);
    _ = p[4]
        .setPosition(-0.4, 0.4)
        .orbitAround(&p[3], 0.2, 0.26);
    _ = p[5]
        .setPosition(-0.4, 0.4)
        .orbitAround(&p[4], 0.2, 0.28);

    _ = p[6]
        .orbitAround(&p[0], 0.8, 0.01);
    _ = p[7]
        .orbitAround(&p[0], 0.8, 0.02);
    _ = p[8]
        .orbitAround(&p[0], 0.8, 0.03);
    _ = p[9]
        .orbitAround(&p[0], 0.8, 0.05);
    _ = p[10]
        .orbitAround(&p[0], 0.8, 0.07);
    _ = p[11]
        .orbitAround(&p[0], 0.8, 0.1);
    _ = p[12]
        .orbitAround(&p[0], 0.8, 0.14);
    _ = p[13]
        .orbitAround(&p[0], 0.8, 0.19);
}

pub fn animateC(c: *Canvas, p: *[NUM_POINTS]Point, mx: f32, my: f32) void {
    c.clear();

    if (mx != 0 and my != 0) {
        _ = p[14].setPosition(mx, my);
    }

    for (p) |*point| {
        _ = point.update();
    }

    c.paintCircle(p[6], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[7], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[8], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[9], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[10], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[11], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[12], 0.05 + p[14].position[0], 0.04, .LightGrey);
    c.paintCircle(p[13], 0.05 + p[14].position[0], 0.04, .LightGrey);

    c.paintCircle(p[14], 0.01, 0.04, .LightGrey);

    c.paintCircle(p[1], 0.1, 0.03, .Black);
    c.renderWetSpot(p[1], 0.2 + p[14].position[1], .LightGrey);
    c.paintCircle(p[2], 0.1, 0.06, .Black);
    c.renderWetSpot(p[2], 0.3 + p[14].position[1], .LightGrey);
    c.paintCircle(p[3], 0.1, 0.08, .Black);
    c.renderWetSpot(p[3], 0.1 + p[14].position[1], .Black);
    c.paintCircle(p[4], 0.1, 0.1, .Black);
    c.paintCircle(p[5], 0.1, 0.1, .Black);

    c.fastBlur(1, 16, p[0]);
    c.chromaticAberration(6, 6);
    c.applyLensDistortion(512);
    c.addFilmGrain(0.3);
}
