# BIG BROTHER Local Android APK (testing build)

Native Android WebView wrapper for the **private company LAN**, independent of the Android Chrome WebAPK installer.

- Starts at https://bigbrother.local:8443/big-brother-dashboard/mobile.html?localbrain=1
- Dedicated launcher icon, no Chrome address bar.
- Requires company Wi-Fi access to Local Brain V6 and Caddy.
- Requires the tablet to trust the public Caddy root CA; never transfers private root.key.
- Explicitly trusts user-installed certificate authorities only for bigbrother.local; never bypasses SSL errors.
- WebView has a separate cache and IndexedDB from Chrome. The Chrome PWA cache will not transfer.
- This package is **not a confirmation of disconnected offline access**. The page's WebView Service Worker and read-only sync must be verified separately.
- GitHub Actions produces a DEBUG APK for testing; debug-signing identity may change on later runs. Stable production signing must be set up before staff rollout.

Download: GitHub Actions -> Build BIG BROTHER Local Android APK -> latest successful workflow -> artifact "BIG-BROTHER-Local-Android-preview-APK". Extract `app-debug.apk` and install on the tablet. Android may request permission to install this APK from your file manager.
