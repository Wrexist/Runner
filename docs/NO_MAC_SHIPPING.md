# Shipping to the App Store WITHOUT a Mac

The repo's `iOS build` GitHub Actions workflow runs on GitHub's macOS runners:
it exports, signs, and uploads to TestFlight. You install builds on your iPhone
via the **TestFlight app**. No Mac is ever needed locally. This guide is every
setup step, in order — all done in a **browser** plus `openssl` on any
Linux/Windows machine (Windows: use WSL or Git Bash, which bundles openssl).

> Honest expectation: the **first 1–3 workflow runs will likely fail** on a
> signing or preset detail — that's normal for any new iOS pipeline. Send the
> failing run's log to Claude (or open a PR and subscribe it) and iterate.

---

## 0. Prerequisites
- Apple Developer Program enrollment **active** (`docs/SETUP_PHASE0.md` step A).
- The app record exists in App Store Connect with bundle id `com.critterdash.app`.
- An iPhone with the **TestFlight** app installed (App Store, free).

## 1. Create the signing certificate (openssl replaces Keychain)
```bash
# 1a. Private key + certificate signing request (keep ios_dist.key SECRET):
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=YOUR_EMAIL/CN=Critter Dash Distribution/C=SE"
```
- Browser → developer.apple.com → **Certificates** → **+** →
  **Apple Distribution** → upload `ios_dist.csr` → download `distribution.cer`.
```bash
# 1b. Bundle cert + key into the .p12 the CI keychain imports
#     (you will be prompted to invent an export password — save it):
openssl x509 -inform DER -in distribution.cer -out ios_dist.pem
openssl pkcs12 -export -inkey ios_dist.key -in ios_dist.pem -out ios_dist.p12
```

## 2. Provisioning profile (browser only)
developer.apple.com → **Identifiers**: confirm `com.critterdash.app` exists
(create it if not; enable In-App Purchase). Then **Profiles** → **+** →
**App Store** distribution → select the App ID + the certificate from step 1 →
name it `critterdash-appstore` → download `critterdash.mobileprovision`.

## 3. App Store Connect API key (browser only)
App Store Connect → **Users and Access** → **Integrations** → App Store Connect
API → **+**. Role: **App Manager**. Download the `.p8` file (one chance only!)
and note the **Key ID** and **Issuer ID** shown on that page.

## 4. Add the GitHub secrets
Repo → Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID from developer.apple.com → Membership (e.g. `AB12CD34EF`) |
| `IOS_CERT_P12_B64` | `base64 -w0 ios_dist.p12` (macOS-style: `base64 -i ios_dist.p12`) |
| `IOS_CERT_PASSWORD` | the .p12 export password from step 1b |
| `IOS_PROFILE_B64` | `base64 -w0 critterdash.mobileprovision` |
| `ASC_KEY_ID` | Key ID from step 3 |
| `ASC_ISSUER_ID` | Issuer ID from step 3 |
| `ASC_KEY_P8_B64` | `base64 -w0 AuthKey_XXXX.p8` |

Then delete the local `.p12`/`.p8`/key files or store them somewhere safe
offline — never commit them (the repo's `.gitignore` already blocks `*.p12`/`*.pem`).

## 5. The 1024px icon (already done)
`ios/icons/icon_1024.png` is committed (1024×1024, opaque, no transparency —
Apple-compliant). It's generated from `icon.svg` by `tools/render_icon.py`; to
change the icon, edit the SVG (or the script) and rerun
`python3 tools/render_icon.py`, then commit the PNG.

## 6. Run it
GitHub → **Actions** → **iOS build** → **Run workflow** (leave "upload" checked).
- Green run → the build appears in App Store Connect → TestFlight within ~15
  min → add yourself as an internal tester → install on your iPhone.
- Red run → copy the failing step's log to Claude. Expected first-run failure
  classes: a wrong preset key (fix in `ios/export_presets.ios.template.cfg`),
  missing icon, or a signing mismatch (cert type vs. profile).

## 7. What to test on the iPhone (each TestFlight build)
- Touch: swipe + tap-a-side both change lanes; pause button reachable.
- Audio plays; music loops without a click; volumes feel gentle.
- Backgrounding the app auto-pauses; resume works.
- Parental gate: wrong answers lock buttons briefly; gate precedes the Shop.
- IAP: **internal builds use the stub** (instant unlock) until the native
  plugin is wired (LAUNCH_PLAN Phase 6) — sandbox-test purchase + Restore then.

## Known limitation (flagged, not hidden)
The native `InAppStore` plugin is **not** in pipeline v1, so TestFlight builds
grant the unlock via the stub. Fine for internal testing; **must** be wired
before App Review submission. That's the next pipeline iteration once a first
clean build exists.
