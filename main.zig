const std = @import("std");

extern fn updateTexture(data: [*]const u8, width: u32, height: u32) void;

pub fn main() void {
    const newData = [_] u8 {
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
        ...getRandomPixel(),
    };

    updateTexture(newData[0..], 4, 4);
}

fn getRandomPixel() []u8 {
    return [
        std.math.random() % 256,
        std.math.random() % 256,
        std.math.random() % 256,
        255,
    ];
}
