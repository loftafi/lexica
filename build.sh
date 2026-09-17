#!/bin/ksh

zig build ios \
     -Dapp_name=Lexica \
     -Ddev_mode=false \
     -Dapp_resources=resources/ \
     -Dapp_bundle=app_bundle.bd \
     -Dapp_owner=Lexica \
     -Dorg=org.example.lexica \
     -Dapp_id=org.example.lexica \
     -Dios_splash_screen=assets/generated/splash-screen.jpg \
     -Dios_icon_light=assets/generated/app-icon-1024x1024.png \
     -Dios_icon_dark=assets/generated/app-icon-1024x1024.png

export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/30.0.16248370

zig build android \
     -Dapp_name=Lexica \
     -Dapp_resources=resources/ \
     -Dandroid_app_id=org.lexica \
     -Dapp_owner=Lexica \
     -Dapp_bundle=app_bundle.bd \
     -Dapp_id=org.example.lexica \
     -Dandroid_icon_background_108=assets/generated/app-icon-background-108x108.webp \
     -Dandroid_icon_background_162=assets/generated/app-icon-background-162x162.webp \
     -Dandroid_icon_background_216=assets/generated/app-icon-background-216x216.webp \
     -Dandroid_icon_background_324=assets/generated/app-icon-background-324x324.webp \
     -Dandroid_icon_background_432=assets/generated/app-icon-background-432x432.webp \
     -Dandroid_icon_foreground_108=assets/generated/app-icon-foreground-108x108.webp \
     -Dandroid_icon_foreground_162=assets/generated/app-icon-foreground-162x162.webp \
     -Dandroid_icon_foreground_216=assets/generated/app-icon-foreground-216x216.webp \
     -Dandroid_icon_foreground_324=assets/generated/app-icon-foreground-324x324.webp \
     -Dandroid_icon_foreground_432=assets/generated/app-icon-foreground-432x432.webp \
     -Dandroid_icon_circle_144=assets/generated/app-icon-round-144x144.webp \
     -Dandroid_icon_circle_192=assets/generated/app-icon-round-192x192.webp \
     -Dandroid_icon_circle_48=assets/generated/app-icon-round-48x48.webp \
     -Dandroid_icon_circle_72=assets/generated/app-icon-round-72x72.webp \
     -Dandroid_icon_circle_96=assets/generated/app-icon-round-96x96.webp \
     -Dandroid_icon_rounded_144=assets/generated/app-icon-rounded-144x144.webp \
     -Dandroid_icon_rounded_192=assets/generated/app-icon-rounded-192x192.webp \
     -Dandroid_icon_rounded_48=assets/generated/app-icon-rounded-48x48.webp \
     -Dandroid_icon_rounded_72=assets/generated/app-icon-rounded-72x72.webp \
     -Dandroid_icon_rounded_96=assets/generated/app-icon-rounded-96x96.webp \
     -Ddev_mode=false
