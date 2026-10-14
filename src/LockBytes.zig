//! An interface to byte-addressable storage. Read and write at explicit offsets,
//! resize the storage, and restrict access to byte ranges. There is no seek
//! position.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes

const LockBytes = @This();

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Fixed = @import("LockBytes/Fixed.zig");

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Write any internal buffers out to the underlying storage.
    flush: *const fn (ctx: *anyopaque) FlushError!void = defaultFlush,

    /// Restrict access to a portion, or all, of the underlying storage. Allow
    /// ranges past the end. Return `error.InvalidFunction` for an unsupported
    /// `lock_type`.
    lockRegion: *const fn (ctx: *anyopaque, offset: u64, len: u64, lock_type: LockType) LockRegionError!void = unsupportedLockRegion,

    /// Read up to `buffer.len` bytes at `offset` from the underlying storage.
    /// Set `n` even on error. Read short only at the end or on error.
    readAt: *const fn (ctx: *anyopaque, buffer: []u8, offset: u64, n: *usize) ReadAtError!void,

    /// Truncate or extend the underlying storage. Extended bytes may be left
    /// undefined.
    setSize: *const fn (ctx: *anyopaque, new_size: u64) SetSizeError!void,

    /// Return information about the underlying storage. Allocate `Stat.name`
    /// with `alloc` unless `flag` is `.no_name`.
    stat: *const fn (ctx: *anyopaque, alloc: Allocator, flag: StatFlag) StatError!Stat,

    /// Remove a restriction placed by `lockRegion`. Unlock only an exact match
    /// of `offset`, `len`, and `lock_type`.
    unlockRegion: *const fn (ctx: *anyopaque, offset: u64, len: u64, lock_type: LockType) UnlockRegionError!void = unsupportedUnlockRegion,

    /// Write `buffer` at `offset` to the underlying storage. Set `n` even on
    /// error. Extend the storage when writing past the end; the gap may be
    /// left undefined.
    writeAt: *const fn (ctx: *anyopaque, buffer: []const u8, offset: u64, n: *usize) WriteAtError!void,
};

pub fn defaultFlush(_: *anyopaque) FlushError!void {}

pub fn unsupportedLockRegion(_: *anyopaque, _: u64, _: u64, _: LockType) LockRegionError!void {
    return error.InvalidFunction;
}

pub fn unsupportedUnlockRegion(_: *anyopaque, _: u64, _: u64, _: LockType) UnlockRegionError!void {
    return error.InvalidFunction;
}

pub const FlushError = error{
    /// The caller doesn't have permission to edit the underlying storage.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
    /// The underlying device is full.
    ///
    /// STG_E_MEDIUMFULL
    MediumFull,
    /// Unknown failure while writing data.
    ///
    /// E_FAIL
    Fail,
    /// Exhausted the OS's limits for open files.
    ///
    /// STG_E_TOOMANYFILESOPEN
    TooManyFilesOpen,
    /// The underlying file was closed or its media replaced.
    ///
    /// STG_E_INVALIDHANDLE
    InvalidHandle,
};

pub const LockRegionError = error{
    /// Locking, or the requested `LockType`, is not supported.
    ///
    /// STG_E_INVALIDFUNCTION
    InvalidFunction,
    /// The caller doesn't have permission, or another caller holds a lock on
    /// the range.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
    /// Another caller holds a lock on the range.
    ///
    /// STG_E_LOCKVIOLATION
    LockViolation,
    /// The underlying file was closed or its media replaced.
    ///
    /// STG_E_INVALIDHANDLE
    InvalidHandle,
};

pub const ReadAtError = error{
    /// Unknown failure while reading data.
    ///
    /// E_FAIL
    Fail,
    /// Asynchronous storage only. Some or all of the data is not yet
    /// available.
    ///
    /// E_PENDING
    Pending,
    /// The caller doesn't have permission to read the byte array.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
    /// Fewer bytes were read than requested, before the end of the byte
    /// array.
    ///
    /// STG_E_READFAULT
    ReadFault,
};

pub const SetSizeError = error{
    /// The caller doesn't have permission to edit the byte array.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
    /// The underlying device is full.
    ///
    /// STG_E_MEDIUMFULL
    MediumFull,
};

pub const StatError = error{
    /// No memory for `Stat.name`.
    ///
    /// E_OUTOFMEMORY, STG_E_INSUFFICIENTMEMORY
    OutOfMemory,
    /// The caller doesn't have permission to access the byte array.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
};

pub const UnlockRegionError = error{
    /// Locking, or the requested `LockType`, is not supported.
    ///
    /// STG_E_INVALIDFUNCTION
    InvalidFunction,
    /// The unlock can't be granted.
    ///
    /// STG_E_LOCKVIOLATION
    LockViolation,
};

pub const WriteAtError = error{
    /// Unknown failure while writing data.
    ///
    /// E_FAIL
    Fail,
    /// Asynchronous storage only. Some or all of the data cannot yet be
    /// written.
    ///
    /// E_PENDING
    Pending,
    /// The caller doesn't have permission to write the byte array.
    ///
    /// STG_E_ACCESSDENIED
    AccessDenied,
    /// Fewer bytes were written than requested.
    ///
    /// STG_E_WRITEFAULT
    WriteFault,
    /// The underlying device is full.
    ///
    /// STG_E_MEDIUMFULL
    MediumFull,
};

pub const LockType = enum {
    /// Excludes other writers.
    write,
    /// Excludes other readers and writers.
    exclusive,
    /// Only one requester may hold a lock on the range. Usually an alias for
    /// `write` or `exclusive`.
    only_once,
};

pub const StatFlag = enum {
    default,
    no_name,
};

pub const Stat = struct {
    name: ?[:0]u16,
    size: u64,
    mtime: Io.Timestamp,
    ctime: Io.Timestamp,
    atime: Io.Timestamp,
    locks_supported: std.EnumSet(LockType),
};

test {
    _ = Fixed;
}
