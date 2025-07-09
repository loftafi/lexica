
zig build -Dassets=assets-bgd \
	-Dorg=scripturial \
	-Dapp_id=com.biblicaltext.app.bgdpp \
	-Dapp_version=4.0 \
	-Dapp_name="Biblical Greek" \
	-Doptimize=ReleaseFast \
	-Dplatform=ios

zig build -Dassets=assets-bgd \
	-Dorg=scripturial \
	-Dapp_id=com.biblicaltext.app.bgdpp \
	-Dapp_version=4.0 \
	-Dapp_name="Biblical Greek" \
	-Doptimize=ReleaseFast \
	-Dplatform=android
