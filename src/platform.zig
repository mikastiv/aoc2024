const std = @import("std");
const builtin = @import("builtin");
const win32 = struct {
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").system.threading;
    usingnamespace @import("win32").system.process_status;
    usingnamespace @import("win32").system.memory;
    usingnamespace @import("win32").system.system_services;
    usingnamespace @import("win32").security;
};

pub fn readOsTimer() u64 {
    if (builtin.os.tag == .windows) {
        return std.os.windows.QueryPerformanceCounter();
    } else {
        @compileError("Os timer read unimplemented for: " ++ @tagName(builtin.os.tag));
    }
}

pub fn getOsTimerFreq() u64 {
    if (builtin.os.tag == .windows) {
        return std.os.windows.QueryPerformanceFrequency();
    } else {
        @compileError("Os timer frequency unimplemented for: " ++ @tagName(builtin.os.tag));
    }
}

pub fn readCpuTimer() u64 {
    if (builtin.cpu.arch.isX86()) {
        var lo: u64 = undefined;
        var hi: u64 = undefined;

        asm volatile (
            \\rdtsc
            : [low] "={rax}" (lo),
              [hi] "={rdx}" (hi),
        );

        return hi << 32 | lo;
    } else {
        @compileError("Cpu timer read unimplemented for: " ++ @tagName(builtin.cpu.arch));
    }
}

pub fn getCpuTimerFreq() u64 {
    const wait_time_ms = 100;
    const os_freq = getOsTimerFreq();
    const os_start = readOsTimer();
    const cpu_start = readCpuTimer();
    const wait_time = os_freq * wait_time_ms / 1000;

    var os_elapsed: u64 = 0;
    while (os_elapsed < wait_time) {
        os_elapsed = readOsTimer() - os_start;
    }

    const cpu_end = readCpuTimer();
    const cpu_elapsed = cpu_end - cpu_start;

    return os_freq * cpu_elapsed / os_elapsed;
}

pub const Timer = enum {
    Rdtsc,
    Os,
};

pub fn readTimerFn(comptime timer: Timer) *const fn () u64 {
    return switch (timer) {
        .Rdtsc => readCpuTimer,
        .Os => readOsTimer,
    };
}

pub fn readTimer(comptime timer: Timer) u64 {
    return readTimerFn(timer)();
}

pub fn getTimerFreq(comptime timer: Timer) u64 {
    return switch (timer) {
        .Rdtsc => getCpuTimerFreq(),
        .Os => getOsTimerFreq(),
    };
}

const OsData = switch (builtin.os.tag) {
    .windows => struct {
        process_handle: win32.HANDLE,
        large_page_size: usize,
    },
    else => @compileError("os unimplemented"),
};

var global_data: ?OsData = null;

pub fn intitializeOsPlatform() !void {
    switch (builtin.os.tag) {
        .windows => if (global_data == null) {
            const handle = win32.OpenProcess(
                .{ .VM_READ = 1, .QUERY_INFORMATION = 1 },
                win32.FALSE,
                win32.GetCurrentProcessId(),
            ) orelse return error.OsPlatformInitFailed;

            const large_page_size = try enableLargePages();

            global_data = .{
                .process_handle = handle,
                .large_page_size = large_page_size,
            };
        },
        else => @compileError("os unimplemented"),
    }
}

pub fn enableLargePages() !usize {
    if (builtin.os.tag == .windows) {
        var token_handle: ?win32.HANDLE = undefined;
        var res = win32.OpenProcessToken(win32.GetCurrentProcess(), win32.TOKEN_ADJUST_PRIVILEGES, &token_handle);
        if (res == 0) return error.TokenHandleOpenFailed;
        defer _ = win32.CloseHandle(token_handle);

        var privs: win32.TOKEN_PRIVILEGES = .{
            .PrivilegeCount = 1,
            .Privileges = .{
                .{ .Attributes = win32.SE_PRIVILEGE_ENABLED, .Luid = undefined },
            },
        };
        res = win32.LookupPrivilegeValue(null, win32.SE_LOCK_MEMORY_NAME, &privs.Privileges[0].Luid);
        if (res == 0) return error.LookupPrivilegeFailed;

        res = win32.AdjustTokenPrivileges(token_handle, win32.FALSE, &privs, 0, null, null);
        if (res == 0) return error.AdjustPrivilegeFailed;

        return win32.GetLargePageMinimum();
    } else {
        @compileError("unimplemented");
    }
}

pub const large_page_allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &large_page_allocator_vtable,
};
const large_page_allocator_vtable = std.mem.Allocator.VTable{
    .alloc = largePageAlloc,
    .resize = largePageResize,
    .free = largePageFree,
};

fn largePageAlloc(_: *anyopaque, len: usize, _: u8, _: usize) ?[*]u8 {
    const aligned_len = std.mem.alignForward(usize, len, getLargePageSize());
    const mem = win32.VirtualAlloc(null, aligned_len, .{ .COMMIT = 1, .RESERVE = 1, .LARGE_PAGES = 1 }, .{ .PAGE_EXECUTE_READWRITE = 1 });
    return @ptrCast(mem);
}

fn largePageResize(_: *anyopaque, _: []u8, _: u8, _: usize, _: usize) bool {
    return false;
}

fn largePageFree(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
    _ = win32.VirtualFree(buf.ptr, 0, .RELEASE);
}

pub fn getLargePageSize() usize {
    return global_data.?.large_page_size;
}

pub fn readPageFaultCount() !u32 {
    switch (builtin.os.tag) {
        .windows => {
            var memory_counters = std.mem.zeroes(win32.PROCESS_MEMORY_COUNTERS);
            memory_counters.cb = @sizeOf(@TypeOf(memory_counters));

            const result = win32.K32GetProcessMemoryInfo(
                global_data.?.process_handle,
                &memory_counters,
                memory_counters.cb,
            );
            if (result == 0) return error.ProcessInfoFetchFailed;

            return memory_counters.PageFaultCount;
        },
        else => @compileError("os unimplemented"),
    }
}
