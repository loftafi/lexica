#!/bin/ksh

 zig build ios \
     -Dapp_name=Lexica \
     -Ddev_mode=false \
     -Dapp_bundle=app_bundle.bd \
     -Dapp_owner=Lexica \
     -Dorg=org.example.lexica \
     -Dapp_id=org.example.lexica \
     -Dsplash_screen=assets/generated/splash-screen.jpg \
     -Dios_icon=assets/generated/app-icon-1024x1024.png
