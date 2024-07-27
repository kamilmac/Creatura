const std = @import("std");

var rng = std.rand.DefaultPrng.init(0);

var newData: [64]u8 = undefined; // 4x4 pixels, each with 4 u8 values (RGBA)

export fn go(timeSinceStart: f32) [*]const u8 {
    var index: usize = 0;
    if (timeSinceStart < 1000) {
        return undefined;
    }
    while (index < newData.len) : (index += 4) {
        const pixel = getRandomPixel();
        newData[index + 0] = pixel[0];
        newData[index + 1] = pixel[1];
        newData[index + 2] = pixel[2];
        newData[index + 3] = pixel[3];
    }
    return newData[0..];
}

fn getRandomPixel() [4]u8 {
    return [4]u8{
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        255,
    };
}
