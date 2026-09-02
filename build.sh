#!/bin/ksh

#dialogos bundle

zig build ios \
    -Dapp_name=Biblical\ Greek \
    -Ddev_mode=false \
    -Dapp_bundle=app_bundle.bd \
    -Dapp_owner=Jacob\ Rhoden \
    -Dorg=com.scripturial.dapp \
    -Dapp_id=com.scripturial.bgd \
    -Dsplash_screen=assets-bgd/generated/splash-screen.jpg \
    -Dios_icon=assets-bgd/generated/app-icon-1024x1024.png 


