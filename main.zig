const std = @import("std");

const Canvas = struct {
    height: u32,
    width: u32,
};

var rng = std.rand.DefaultPrng.init(0);
var canvas: Canvas = undefined;
var newData: []u8 = undefined;

export fn init(width: u32, height: u32) void {
    canvas = Canvas{
        .width = width,
        .height = height,
    };
    const total_size = canvas.width * canvas.height * 4;
    newData = std.heap.page_allocator.alloc(u8, total_size) catch unreachable;
}

export fn go(timeSinceStart: f32) *[]const u8 {
    var index: usize = 0;
    if (timeSinceStart > 6000) {
        return undefined;
    }
    while (index < newData.len) : (index += 4) {
        const pixel = getRandomPixel();
        newData[index + 0] = pixel[0];
        newData[index + 1] = pixel[1];
        newData[index + 2] = pixel[2];
        newData[index + 3] = pixel[3];
    }
    return &newData;
}

fn getRandomPixel() [4]u8 {
    return [4]u8{
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        255,
    };
}
