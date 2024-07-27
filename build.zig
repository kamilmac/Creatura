const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const exe = b.addExecutable(.{
        .name = "zigl",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });

    // <https://github.com/ziglang/zig/issues/8633>
    // exe.global_base = 6560;
    // exe.entry = .disabled;
    // exe.rdynamic = true;
    // exe.import_memory = true;
    // exe.stack_size = std.wasm.page_size;
    // exe.initial_memory = std.wasm.page_size * 2;
    // exe.max_memory = std.wasm.page_size * 2;

    b.installArtifact(exe);
}
