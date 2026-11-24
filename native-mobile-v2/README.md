# Native Mobile V2 — development foundation

Two separate Android application flavors with independent development package IDs. Native Java Android UI, no WebView or remote website launch. The initial screen works without internet. This is a scaffold, not a replacement for production: authentication, permission enforcement, API contracts, accounting modules, exports, offline data and signed updater are not implemented. No live database operations occur. Do not distribute as a production accounting app.

Build with JDK 17, Android SDK 35 and Gradle 8.10.2:
`gradle -p native-mobile-v2 :app:assembleOnlineDebug :app:assembleLocalDebug`

Production release requires verified parity, distinct stable package IDs/signing, secure session storage, local TLS validation, and signed versioned APK updates with Android installer confirmation. A fully native code change needs an APK update; do not dynamically load unverified executable code.
