const std = @import("std");

extern fn updateTexture(data: [*]const u8, width: u32, height: u32) void;

var rng = std.rand.DefaultPrng.init(0);

export fn go() void {
    var newData: [64]u8 = undefined; // 4x4 pixels, each with 4 u8 values (RGBA)
    var index: usize = 0;
    while (index < newData.len) : (index += 4) {
        const pixel = getRandomPixel();
        newData[index + 0] = pixel[0];
        newData[index + 1] = pixel[1];
        newData[index + 2] = pixel[2];
        newData[index + 3] = pixel[3];
    }
    updateTexture(newData[0..], 4, 4);
}

fn getRandomPixel() [4]u8 {
    return [4]u8{
        rng.random().uintLessThan(u8, 255),
        rng.random().uintLessThan(u8, 255),
        rng.random().uintLessThan(u8, 255),
        255,
    };
}
