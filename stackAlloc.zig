const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

const StackAllocator = struct {
    buffer: []u8,
    end_index: usize,

    const Header = struct {
        padding: u8,
    };

    pub fn init(buffer: []u8) StackAllocator {
        return .{
            .buffer = buffer,
            .end_index = 0,
        };
    }

    pub fn alloc(self: *StackAllocator, comptime T: type, num: usize) ?[]T {
        const ptr_align = @alignOf(T);
        const alignment = mem.alignPointerOffset(self.buffer.ptr + self.end_index + @sizeOf(Header), ptr_align) orelse return null;
        const adjust = alignment + @sizeOf(Header);
        const new_end_index = num * @sizeOf(T) + adjust + self.end_index;
        if (self.isAllocationPossible(new_end_index)) {
            const header: *Header = @ptrCast(self.buffer.ptr + alignment + self.end_index);
            header.padding = @intCast(alignment);
            const ptr: [*]T = @ptrCast(@alignCast(self.buffer.ptr + self.end_index + adjust));
            self.end_index = new_end_index;
            return ptr[0..num];
        } else return null;
    }

    pub fn free(self: *StackAllocator, slice: anytype) void {
        const T = std.meta.Elem(@TypeOf(slice));

        if (self.isLastAllocation(slice)) {
            const meta_ptr: *Header = @ptrCast(@as([*]u8, @ptrCast(slice.ptr)) - @sizeOf(Header));
            const alignment = meta_ptr.padding;
            self.end_index -= @sizeOf(T) * slice.len + alignment + @sizeOf(Header);
        }
    }

    pub fn reset(self: *StackAllocator) void {
        self.end_index = 0;
    }

    pub fn isLastAllocation(self: *StackAllocator, buf: anytype) bool {
        return @as([*]u8, @ptrCast(buf.ptr + buf.len)) == self.buffer.ptr + self.end_index;
    }

    fn isAllocationPossible(self: *StackAllocator, new_index: usize) bool {
        return (new_index <= self.buffer.len);
    }
};

test "base alloc and free" {
    var buffer: [1024]u8 = undefined;
    var allocator = StackAllocator.init(&buffer);

    const numbers = allocator.alloc(u32, 10) orelse @panic("Не хватило памяти");
    try testing.expect(numbers.len == 10);

    numbers[0] = 42;
    numbers[9] = 100;
    allocator.free(numbers);

    try testing.expect(allocator.end_index == 0);
}

test "pointer alignment" {
    var buffer: [1024]u8 = undefined;
    var allocator = StackAllocator.init(&buffer);

    const u32_slice = allocator.alloc(u32, 5) orelse @panic("alloc failed");
    const ptr_address = @intFromPtr(u32_slice.ptr);
    try testing.expect(ptr_address % @alignOf(u32) == 0);

    allocator.free(u32_slice);

    const f64_slice = allocator.alloc(f64, 3) orelse @panic("alloc failed");
    const f64_ptr_address = @intFromPtr(f64_slice.ptr);
    try testing.expect(f64_ptr_address % @alignOf(f64) == 0);

    allocator.free(f64_slice);
}

test "Multiple allocs and frees in LIFO order" {
    var buffer: [2048]u8 = undefined;
    var allocator = StackAllocator.init(&buffer);

    const first = allocator.alloc(u8, 100) orelse @panic("alloc 1 failed");
    const second = allocator.alloc(u32, 50) orelse @panic("alloc 2 failed");
    const third = allocator.alloc(f64, 10) orelse @panic("alloc 3 failed");

    allocator.free(third);
    allocator.free(second);
    allocator.free(first);

    try testing.expect(allocator.end_index == 0);
}

test "buffer overflow" {
    var buffer: [256]u8 = undefined;
    var allocator = StackAllocator.init(&buffer);
    const result = allocator.alloc(u64, 1000);

    try testing.expect(result == null);

    try testing.expect(allocator.end_index == 0);
}

test "reset" {
    var buffer: [1024]u8 = undefined;
    var allocator = StackAllocator.init(&buffer);

    _ = allocator.alloc(u32, 10) orelse @panic("alloc failed");
    _ = allocator.alloc(f64, 5) orelse @panic("alloc failed");
    try testing.expect(allocator.end_index > 0);
    allocator.reset();

    try testing.expect(allocator.end_index == 0);

    const new_alloc = allocator.alloc(u8, 100) orelse @panic("alloc after reset failed");
    try testing.expect(new_alloc.len == 100);
}
