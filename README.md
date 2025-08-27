# Lexica — Dictionary and Parsing

## Build and Run

Lexica requires a small handful of images and fonts
to operate. During development, run lexica pointing to
the `resources` folder containing these fonts and images:

    zig build run -- /resources

To trigger lexica int searching for the the prepackaged
`resources.bd` file that is required for making an app
package, don't specify the resources folder:

    zig build run

## Build for IOS/Android

Build and run locally first, and hit the `b` key to export a
resources.bd file to `/tmp/resources.bd`

    zig build run
    cp /tmp/resources.bd ios/lexica/resources.bd

Compile the zig library and install it into the ios or
android folder:

    zig build -Doptimize=ReleaseFast -Dplatform=ios \
        -Dapp_name="Lexica"\
        -Dapp_version="1.0"\
        -Dapp_id=com.example.lexica
        -Dorg="Example"\
        -Dassets="assets"

To build for android, also set the ndk environemnt variable, i.e:

    export ANDROID_NDK_HOME=/Users/user/Library/Android/sdk/ndk/27.3.13750724

And update android_libc.txt to point to the same ndk.

## Setup for the android project

The home folder contains an `android_libc.txt` file which zig uses
to find the android ndk to do building/linking.

The `/android/` folder was created using the script
`build-scripts/create-android-project.py` from the SDL repo.

See the following for how the lexica library is added to the
`Android.mk` file to make sure it can be run.

 - https://developer.android.com/ndk/guides/prebuilts.html
 - https://stackoverflow.com/questions/40712837/how-to-add-some-third-party-so-files-in-android-mk
 - https://github.com/Ravbug/sdl3-sample

The sample SDL3 android project needs the following
to be included in `app/jni/src/Android.mk`:

    include $(CLEAR_VARS)
    LOCAL_MODULE := lexica-android
    LOCAL_SRC_FILES := ../jniLibs/arm64-v8a/liblexica.so
    include $(PREBUILT_SHARED_LIBRARY)
    #include $(PREBUILT_STATIC_LIBRARY)

And later in this file:

    LOCAL_SHARED_LIBRARIES := SDL3 lexica-android
    #LOCAL_STATIC_LIBRARIES := 

The android project also needs SDL_ttf. First uncomment
this line in `android/app/jni/CMakeLists.txt`:

    add_subdirectory(SDL_ttf)

Checkout sdl_ttf and dependencies into `android/app/jni`:

    git clone https://github.com/libsdl-org/SDL
    git clone https://github.com/libsdl-org/SDL_ttf.git
    cd SDL_ttf/external/
    ./download.sh

The name of the android app is set by changing the filename, and
the class name inside it:

    app/src/main/java/com/gamemaker/game/MyGame.java

    public class MyGame extends SDLActivity { }

Then replace "SDLActivity" in AndroidManifest.xml with the name of
the app, .e.g. "MyGame" becomes "Lexica"

## References

Greek Grammar terms derived from:

 - https://el.wikisource.org/wiki/Τέχνη_Γραμματική
 - https://en.wikisource.org/wiki/The_grammar_of_Dionysios_Thrax

## Android bookmarks

The build folder contains an `android_libc.txt` as per:

 - https://github.com/ziglang/zig/issues/3332
 - https://github.com/ziglang/zig/issues/22308

