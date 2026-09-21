# Lexica — Ancient Greek Dictionary

Dictionary and grammar quiz tool for Ancient Greek students using Athenaze
or similar resources.

## How to run

Lexica requires a small handful of images and fonts
to operate. During development, run lexica pointing to
the `resources` folder containing these fonts and images:

    git clone https://github.com/loftafi/lexica.git
    cd lexica
    zig build run -- /resources

Builds on macOS and linux when SDL and SDL_mixer libraries are installed.
Patches to add windows support are welcome

## Package for IOS/Android

Build for android and/or ios as follows.

    zig build android
    zig build ios

These depends on the `engine` module to export an android or iOS xcode
template folder into `zig-out/android` and `zig-out/xcode`. The application
code and resource bundle files are dropped into the appopriate template folders.

Remove `zig-out/android` and/or `zig-out/xcode` for a clean rebuild of
the template and application library file.

Building for android depends on the android NDK being installed. Before
executing `zig build android` install the NDK and set the `ANDROID_NDK_HOME`
as follows, i.e:

    export ANDROID_NDK_HOME=/Users/user/Library/Android/sdk/ndk/30.0.16138531

## Build settings

Configuration options are available to customise the application template
files:

    zig build -Doptimize=ReleaseFast -Dplatform=ios \
        -Dapp_name="Lexica"\
        -Dapp_version="1.0"\
        -Dapp_id=com.example.lexica
        -Dorg="Example"\
        -Dassets="assets"

## References

Greek Grammar terms derived from:

 - https://el.wikisource.org/wiki/Τέχνη_Γραμματική
 - https://en.wikisource.org/wiki/The_grammar_of_Dionysios_Thrax
