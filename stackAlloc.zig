const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;


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

pub fn alloc( self: *StackAllocator, comptime T: type, num: usize) ?[]T {
    const ptr_align = @alignOf(T);
    const alignment = mem.alignPointerOffset(self.buffer.ptr + self.end_index + @sizeOf(Header), ptr_align) orelse return null;
    const adjust = alignment + @sizeOf(Header);
    const new_end_index = num * @sizeOf(T) + adjust + self.end_index;
    if (self.isAllocationPossible(new_end_index)){
        const header: *Header = @ptrCast(self.buffer.ptr + alignment + self.end_index);
        header.padding = @intCast(alignment);
        const ptr: [*]T = @ptrCast(self.buffer.ptr + self.end_index + adjust);
        self.end_index = new_end_index;
        return ptr[0..num];
    }
    else return null;
}


pub fn free(self: *StackAllocator, slice: anytype) void {
    const T = std.meta.Elem(@TypeOf(slice));

    if (self.isLastAllocation(slice)) {
    const meta_ptr: *Header = @ptrCast(@as([*]u8, @ptrCast(slice.ptr)) - @sizeOf(Header));
    const alignment = meta_ptr.padding;
    self.end_index -= @sizeOf(T) * slice.len + alignment + @sizeOf(Header);
    }
}


pub fn reset(self: *StackAllocator){
    self.end_index = 0;
}


pub fn isLastAllocation(self: *StackAllocator, buf: anytype) bool {
    return @as([*]u8, @ptrCast(buf.ptr + buf.len)) == self.buffer.ptr + self.end_index;
}

fn isAllocationPossible(self: *StackAllocator, new_index: usize) bool {
    return (new_index <= self.buffer.len);
}


};