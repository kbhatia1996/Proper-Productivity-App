# Installing on your iPhone without the App Store (and without Xcode)

You do not need a Mac with Xcode. GitHub builds the app for you on a free macOS runner; you then
sign it with your own Apple ID and put it on your phone.

**Cost:** free. **Limitation of a free Apple ID:** the app stops opening after **7 days** and must be
re-signed (AltStore can do this automatically). A paid Apple Developer account ($99/yr) gives 1-year
signing and TestFlight, but is not required.

## 1. Create the Firebase backend (10 min)

1. https://console.firebase.google.com → **Add project**.
2. **Build → Authentication → Get started → Email/Password → Enable.**
3. **Build → Firestore Database → Create database** (production mode, any region).
4. Firestore → **Rules** tab → paste the contents of [`firestore.rules`](./firestore.rules) → **Publish**.
5. **Project settings → Your apps → Add app → iOS.**
   - Bundle ID: pick something unique, e.g. `com.<yourname>.properproductivepigeons`.
   - Put the *same* id in [`project.yml`](./project.yml) (`PRODUCT_BUNDLE_IDENTIFIER`).
   - Download `GoogleService-Info.plist`.

## 2. Let GitHub build the app

1. Push this folder to a **private** GitHub repo.
2. Convert the plist to a secret value: `base64 -i GoogleService-Info.plist | pbcopy`
   (Windows: `certutil -encode GoogleService-Info.plist out.b64`).
3. Repo → **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `GOOGLE_SERVICE_INFO_PLIST_BASE64`, value: the base64 text.
4. Repo → **Actions → Build iOS app → Run workflow.**
   It first runs the scenario tests, then builds. When green, download the **ProperProductivePigeons-ipa** artifact
   and unzip it to get `ProperProductivePigeons.ipa`.

The workflow fails early with a clear message if the Firebase plist's bundle ID differs from `project.yml`.

> The first build is the first time this project has ever been compiled for iOS. Expect to fix a few
> compile errors; paste the Actions log back and they can be fixed quickly.

## 3. Put it on your phone

Pick one:

**Sideloadly (simplest, Windows or Mac)**
1. Install Sideloadly from sideloadly.io. Plug in the iPhone, tap *Trust*.
2. Drag `ProperProductivePigeons.ipa` in, enter your Apple ID, press *Start*.
3. iPhone: **Settings → General → VPN & Device Management →** your Apple ID **→ Trust**.
4. iPhone (iOS 16+): **Settings → Privacy & Security → Developer Mode → On**, restart.

**AltStore** (same idea, but refreshes the 7-day signature automatically while AltServer runs on your computer).

**TestFlight** (needs the paid account): upload a signed build to App Store Connect; testers install through the
TestFlight app. No App Store review for internal testers.

## 4. First-run checklist

0. Open the gear on Home → turn on **Reward reminders** and allow notifications (a 7 PM nudge when a reward is one check-in away). Dark/light is switchable there too.

1. Sign up with email + password (min 6 chars) on phone A → *Create Nest* → note the invite code on Home.
2. Phone B (or a second account): Sign up → *Join Nest* → enter the code (max 2 people per nest).
3. Add a task, check it in on Home, open the **Activity** tab: today's ring should fill.
4. Force-quit and reopen: you should still be signed in and land on Home (not the nest screen).

## If something goes wrong

| Symptom | Cause |
|---|---|
| "Firebase isn't configured" screen | `GoogleService-Info.plist` wasn't bundled → re-check the secret |
| "Permission denied" on create/join/check-in | Firestore rules not published (step 1.4) |
| Sign-up error "network" | Email/Password sign-in not enabled (step 1.2) |
| App closes after 7 days | Free Apple ID limit → re-sign with Sideloadly |
| Build fails on Actions | Paste the log; this has not been compiled on iOS before |

## Not the same thing: the web demo

`web-demo.html` is a standalone prototype with built-in sample data. It is *not* the iOS app and does not talk to
Firebase. Opening it on your phone via "Add to Home Screen" gives an icon, but no real data.
