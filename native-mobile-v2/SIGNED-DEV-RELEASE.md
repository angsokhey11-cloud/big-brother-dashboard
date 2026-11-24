# Signed development build procedure

The branch-only signed development workflow uses existing repository signing secrets inside CI, without storing the key in source or uploading it as an artifact. Development package IDs remain separate from production. Signed V2 builds use versionCode 20000 + the signed workflow run number. Reruns do not create a new version; a new run does. Do not install a debug APK as the baseline for this update chain.

The workflow creates signed APK and SHA-256 artifacts, but does not publish them. After testing a baseline and a newer signed build on devices, publish only approved development assets to the dedicated native-v2-online-dev and native-v2-local-dev release tags. The controller can then fetch the Local asset and expose its manifest and APK over LAN. Never publish production credentials or use production release tags. Do not delete existing production applications.
