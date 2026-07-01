# Stack Allocator in Zig (LIFO Bump Allocator)

## Preliminary Notes
1) The implementation is intentionally done outside the standard form, i.e., it does not use a vtable and the `Allocator` interface through which developers typically write their allocators.
   ### Why?
   1. This would shift the focus from the alignment logic for different types to studying compatibility with existing solutions.
   2. A similar allocator already exists in the developers' repository (`FixedBufferAllocator`), so writing another would simply be duplication. Again, there would be no opportunity to explore the alignment problem for different types.
2) Using `u8` as the type that stores the alignment size is sufficient for regular users, as alignment > 255 bytes is not often required. Using `usize`/`u16` instead would necessitate adding alignment for the `Header` itself, as well as adding an extra field to it. Conclusion: for most tasks, `u8` is sufficient; this reduces overhead and simplifies the alloc and free logic.
3) The author apologizes for the code quality and is sure it could have been done better. Unfortunately, the proficiency level in the language is still at a beginner stage, but it's just the beginning :3

## Overview
A simple, fast, and efficient memory allocator written in Zig. It allocates memory linearly from a user-provided buffer and requires memory deallocation in strict **LIFO** order.
This allocator is ideal for scenarios where memory is allocated and freed in a predictable, nested order.

## Features

- **$O(1)$ Allocation and Deallocation:** Extremely fast, achieved through a simple pointer bump.
- **Zero Fragmentation:** Memory is reused perfectly as long as the LIFO order is maintained.
- **Strict Alignment Handling:** Automatically aligns pointers for any type and stores the padding in a 1-byte header.
- **Safe Bounds Checking:** Returns `null` if the buffer overflows, preventing memory corruption.
- **No Hidden Allocations:** Uses a static buffer provided by the user. No hidden `malloc` calls.

## How It Works

1. **Bump Pointer:** The allocator stores an `end_index`. On each memory allocation, it shifts this index by the requested size.
2. **Alignment and Header:** To guarantee correct memory alignment for types like `f64` or `u32`, the allocator may need to skip a few bytes. It stores the exact number of skipped bytes (padding) in a 1-byte `Header`, which is placed immediately before the allocated data.
3. **LIFO Deallocation:** When `free()` is called, the allocator checks if the passed slice is the **last** allocated block. If so, it reads the `Header`, rewinds the `end_index`, and the memory is freed. If it is not the last block, the free operation is ignored.

## Usage

```zig
const std = @import("std");
const StackAllocator = @import("stack_allocator.zig").StackAllocator;

pub fn main() !void {
    // 1. Create a buffer for the allocator
    var buffer: [1024]u8 = undefined;
    
    // 2. Initialize the allocator
    var allocator = StackAllocator.init(&buffer);

    // 3. Allocate memory
    const numbers = allocator.alloc(u32, 10) orelse @panic("Out of memory");
    numbers[0] = 42;
    numbers[9] = 100;

    const text = allocator.alloc(u8, 20) orelse @panic("Out of memory");
    @memcpy(text, "Hello, Stack Allocator!");

    // 4. Free memory
    allocator.free(text);    
    allocator.free(numbers);

    // 5. Reset everything at once
    allocator.reset();
}
```

## API Reference

### `init(buffer: []u8) -> StackAllocator`
Initializes the allocator with the given byte slice. The allocator will use this slice as its backing memory.

### `alloc(comptime T: type, num: usize) -> ?[]T`
Allocates an array of `num` elements of type `T`. 
- Automatically handles pointer alignment.
- Returns `null` if there is not enough space in the buffer.

### `free(slice: anytype) -> void`
Frees a previously allocated slice. 
- **Important:** Only works if the slice is the **last** allocated block. If you try to free an older block while a newer one is still allocated, this function will do nothing.

### `reset() -> void`
Instantly resets the allocator, effectively freeing all memory and setting the `end_index` back to 0.

## Limitations

1. **Strict LIFO Order:** You must free allocations in the exact reverse order of their creation. You cannot free a block located in the middle of the stack.
2. **Header Overhead:** Each allocation uses exactly 1 extra byte to store the alignment padding (see the note above for details).

## License
MIT, see LICENSE file for details
```
