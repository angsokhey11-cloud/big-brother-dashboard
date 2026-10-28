# BIG BROTHER Online for Android — dedicated preview APK

This is a **separate APK** from `BIG BROTHER Local`. It uses the secure public online mobile app:

https://angsokhey11-cloud.github.io/big-brother-dashboard/mobile.html?source=android-online

## What this preview does

- Launcher name **BIG BROTHER Online**, with our existing BIG BROTHER icon.
- Dedicated Android app screen, no Chrome URL or loading UI. A branded in-app loading screen is displayed.
- Independent Android package `com.bigbrother.online`, so Local and Online can be installed side by side.
- Uses the live website and existing Supabase sign-in / permissions. No local LAN URL or Caddy CA.
- Supports Android gallery / document picker in HTML file-upload fields.
- Allows other pages on our GitHub Pages hostname inside the app; external websites open the browser.
- Does not change the dashboard, Cloud database, Control Center, or Local Brain.

## IMPORTANT: Push notification limitations

**A normal Android WebView does not receive background Web Push notifications from the website.** This preview does not yet turn the existing Chrome web push into native notifications, and it must not be described as doing so. Some web features requiring full Chrome APIs (such as push and some download/camera flows) can differ from the browser.

For **real BIG BROTHER notification sender name/icon** with the current web-push backend, plan a **verified Trusted Web Activity (TWA)**:
1. Stable release APK signing key.
2. Digital Asset Links at `https://angsokhey11-cloud.github.io/.well-known/assetlinks.json` (the origin root, not the dashboard repo subpath), mapped to the APK package and signing fingerprint.
3. TWA and its notification-delegation service / Android 13+ notification permission.
4. Test website push delivery and notification branding on a real device.

A verified TWA retains the Chrome web runtime, and its notification delegation can attribute browser Web Push to the Android app. Unlike WebView, this can keep the existing Web Push backend. Do not treat unverified TWA or WebView as equivalent to native push.

An alternative later is direct Android Firebase Cloud Messaging, but it needs Firebase credentials, a server-side token-registration + delivery path, and per-staff permissions.

## Build / installation

GitHub > `big-brother-dashboard` > Actions > **Build BIG BROTHER Online Android APK** > latest successful run > **BIG-BROTHER-Online-Android-preview-APK**. Download, extract, and install `app-debug.apk`.

Android installs this as `BIG BROTHER Online` alongside `BIG BROTHER Local`.

This is a **debug-signed preview**. GitHub Actions runner signing certificates may change; configure a stable privately stored production signing key before a staff rollout. The Online app has its own login/cache/IndexedDB and does not inherit sessions or saved data from Chrome or the Local APK. Existing Chrome notifications are not removed by installation.
