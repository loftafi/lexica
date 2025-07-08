LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := lexica-android
LOCAL_SRC_FILES := ../jniLibs/arm64-v8a/liblexica-android.so
include $(PREBUILT_SHARED_LIBRARY)
#include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := main
LOCAL_SRC_FILES := \
    sample.c
SDL_PATH := ../SDL  # SDL
LOCAL_C_INCLUDES := $(LOCAL_PATH)/$(SDL_PATH)/include  # SDL
LOCAL_SHARED_LIBRARIES := SDL3 SDL3_ttf lexica-android
#LOCAL_STATIC_LIBRARIES := lexica-android
LOCAL_LDLIBS := -lGLESv1_CM -lGLESv2 -lOpenSLES -llog -landroid  # SDL
include $(BUILD_SHARED_LIBRARY)
