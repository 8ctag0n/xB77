const std = @import("std");
export const user_abi_version: i32 = 1;
export fn user_entrypoint(len: i32) i32 {
    _ = len;
    return 0;
}
