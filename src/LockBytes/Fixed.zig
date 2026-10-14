const Fixed = @This();

const std = @import("std");
const LockBytes = @import("../LockBytes.zig");

buffer: []u8,
len: usize,

pub fn init(buffer: []u8) Fixed {
    return .{ .buffer = buffer, .len = buffer.len };
}

pub fn lockBytes(self: *Fixed) LockBytes {
    return .{
        .ptr = self,
        .vtable = &.{
            .readAt = readAt,
            .setSize = setSize,
            .stat = stat,
            .writeAt = writeAt,
        },
    };
}

fn readAt(ctx: *anyopaque, buffer: []u8, offset: u64, n: *usize) LockBytes.ReadAtError!void {
    const self: *Fixed = @ptrCast(@alignCast(ctx));

    const src = self.buffer[@min(offset, self.len)..self.len];
    n.* = @min(buffer.len, src.len);
    @memcpy(buffer[0..n.*], src[0..n.*]);
}

fn setSize(ctx: *anyopaque, new_size: u64) LockBytes.SetSizeError!void {
    const self: *Fixed = @ptrCast(@alignCast(ctx));

    if (new_size > self.buffer.len) return error.MediumFull;

    const new: usize = @intCast(new_size);
    if (new > self.len) @memset(self.buffer[self.len..new], 0);
    self.len = new;
}

fn stat(ctx: *anyopaque, _: std.mem.Allocator, _: LockBytes.StatFlag) LockBytes.StatError!LockBytes.Stat {
    const self: *Fixed = @ptrCast(@alignCast(ctx));

    return .{
        .name = null,
        .size = self.len,
        .mtime = .zero,
        .ctime = .zero,
        .atime = .zero,
        .locks_supported = .{},
    };
}

fn writeAt(ctx: *anyopaque, buffer: []const u8, offset: u64, n: *usize) LockBytes.WriteAtError!void {
    const self: *Fixed = @ptrCast(@alignCast(ctx));

    n.* = @min(self.buffer.len -| offset, buffer.len);
    if (n.* > 0) {
        const start: usize = @intCast(offset);
        if (start > self.len) @memset(self.buffer[self.len..start], 0);

        const end = start + n.*;
        @memcpy(self.buffer[start..end], buffer[0..n.*]);
        self.len = @max(self.len, end);
    }

    if (n.* < buffer.len) return error.MediumFull;
}
