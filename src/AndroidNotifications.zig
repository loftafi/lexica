/// Dummy placeholder code
pub const AndroidNotifications = @This();

pub const jni_version_1_6 = 0x00010006;
pub const jni_ok = 0;
pub const jni_err = -1;
pub const jni_edetached = -2; // thread detached from the VM
pub const jni_eversion = -3; // JNI version error
pub const jni_enomem = -4; // Out of memory
pub const jni_eexist = -5; // VM already created
pub const jni_einval = -6; // Invalid argument

pub var vm: *jni.JavaVM = undefined;
pub var jvm_available: bool = false;

// This function is called during the Android app onCreate function.
pub fn Java_org_libsdl_app_SDLActivity_nativeNotificationCallback(
    env: *jni.JNIEnv,
    _: *jni.jobject,
) callconv(.c) void {
    engine.log.info("java notification setup. jvm_available={any}", .{jvm_available});
    const vtable = @as(*const jni.JNINativeInterface, @ptrCast(env.*));
    const version = vtable.GetVersion.?(env);
    info("jni reported version: {d}", .{version});
}

/// When the android app loads this dynamic library, this function is called
/// to provide an opportunity for initialisation.
pub fn JNI_OnLoad(jni_vm: *jni.JavaVM, _: *anyopaque) callconv(.c) jni.jint {
    engine.log.info("OnLoad called. JVM access available.", .{});
    // Remember the JVM so that it can be used later.
    vm = jni_vm;
    jvm_available = true;
    return jni_version_1_6;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const trace = engine.log.trace;
const debug = engine.log.debug;
const info = engine.log.info;
const err = engine.log.err;
const jni = engine.jni;
const sdl = engine.sdl;
