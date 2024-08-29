pub const Color = enum(u32) {
    Red = 0xC40C0CFF,
    Green = 0xFF6500FF,
    Blue = 0xFF8A08FF,
    Yellow = 0xFFC100FF,
    Black = 0x000000FF,
    LightGrey = 0xCCCCCCFF,
    White = 0xFFFFFFFF,
    // Add more colors as needed

    pub fn toRGBA(self: Color) [4]u8 {
        const value = @intFromEnum(self);
        return .{
            @intCast((value >> 24) & 0xFF),
            @intCast((value >> 16) & 0xFF),
            @intCast((value >> 8) & 0xFF),
            @intCast(value & 0xFF),
        };
    }
};
