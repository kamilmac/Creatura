pub const Point = struct {
    x: f32,
    y: f32,
    id: u32 = 0,

    pub fn init(x: f32, y: f32, id: ?u32) Point {
        return .{
            .x = x,
            .y = y,
            .id = id orelse 0,
        };
    }
};
