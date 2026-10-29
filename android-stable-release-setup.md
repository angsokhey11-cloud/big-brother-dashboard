# BIG BROTHER Android — permanently updatable stable APKs

## Why a one-time migration is required

Old BIG BROTHER preview APKs use GitHub runner-generated **debug signing keys**.
Each GitHub Actions runner has a different identity. Android therefore rejects
in-place updates to the legacy preview APKs. Never uninstall an existing Local
preview that still contains needed offline cache or login state.

The permanent build uses these independent package IDs:

| App | Old preview | Permanent stable package |
| --- | --- | --- |
| BIG BROTHER Local | `com.bigbrother.localbrain` | `com.bigbrother.localbrain.stable` |
| BIG BROTHER Online | `com.bigbrother.online` | `com.bigbrother.online.stable` |

The stable APKs can **install alongside old preview APKs**. They have separate
Android app data; offline snapshots do **not** automatically transfer across them.
Log in and complete Local V6 synchronization on the new app before retiring the old.

## Permanent signing setup (once)

A secure backup bundle has been delivered privately to the BIG BROTHER owner.
**Do not commit the .p12 keystore, its Base64 text or password to GitHub.**
Do not upload the backup bundle as a public repository artifact.

1. Download and securely back up the private `BIG_BROTHER_ANDROID_PERMANENT_SIGNING_BACKUP.zip`.
   It contains a private `.p12` signing keystore and
   `BIG_BROTHER_ANDROID_STABLE_SIGNING_SECRETS.txt`.
2. Go to repository **Settings → Secrets and variables → Actions → New repository secret**.
3. Create `BB_STABLE_KEYSTORE_B64` with the full one-line Base64 value
   from the private secrets text.
4. Create `BB_STABLE_KEYSTORE_PASSWORD` with the corresponding password.
5. In repository Actions run **Build BIG BROTHER Stable Android APKs**
   via **Run workflow** on the main branch.
6. Download the **BIG-BROTHER-Local-Stable-Signed-APK** and
   **BIG-BROTHER-Online-Stable-Signed-APK** artifacts. Extract each ZIP to get
   `app-release.apk`.
7. Install the stable APKs on the device. The old preview apps stay untouched.
   Verify HTTPS trust and Local V6 access. Let the stable Local app synchronize
   its read-only offline workspace while V6 is running.
8. Only after verifying the stable app's login and offline data, optionally
   remove the old preview installation. *Uninstalling wipes that app's local data.*

## Every later APK update

- Keep using the SAME two repository secrets and the SAME private key.
- Keep the **same** stable application IDs and increment `versionCode`.
- The stable workflow assigns a fresh monotonically increasing build number
  (10,000 + GitHub Actions run number) every run.
- GitHub Actions runs on Android-source changes or from **Run workflow**.
- Install the newer **stable app APK** directly over the older stable install.
  Android will preserve login, IndexedDB and WebView app data.
- This does not mean silent automatic installation: Android may ask the user
  to approve downloading/installing each APK update.
- A new device still needs to trust the public Local Caddy CA certificate.
- Keep at least two secure backups of the permanent signing keystore/password.
  Losing the signing key would prevent updates to already installed stable APKs.

## Technical rules

- Signing config: Gradle `release` build type with `applicationIdSuffix '.stable'`.
- Keystore: PKCS12, RSA 3072, alias `bigbrother`.
- Only protected GitHub Actions secrets provide the release key.
- The legacy `assembleDebug` workflows are separate and do NOT produce
  updatable stable packages; never distribute preview debug APKs as production releases.
- Verify output with Android SDK `apksigner verify --verbose --print-certs`.
- The signing workflow checks that the secret is present and fails closed if not.
