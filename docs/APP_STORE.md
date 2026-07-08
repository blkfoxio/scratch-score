# App Store submission kit — Scratch Score

Everything you paste into App Store Connect, plus the build/submit runbook.
Bundle ID: `app.scratchscore`.

> URLs below assume the legal pages are hosted at `https://blkfoxio.github.io/scratch-score/`.
> If you host them elsewhere (custom domain, Netlify, etc.), update these and `LegalLinks` in `SignInView.swift`.

---

## 1. Listing metadata

**App name** (≤30): `Scratch Score`

**Subtitle** (≤30): `Score smarter, shoot lower`

**Primary category:** Sports  ·  **Secondary (optional):** Health & Fitness

**Promotional text** (≤170, editable without review):
```
Track every round with the scoring-zone method and see exactly where you're losing strokes — inside 100 yards, on the greens, and off the tee.
```

**Keywords** (≤100 chars, comma-separated, no spaces):
```
golf,scorecard,scoring,handicap,stats,round,putts,tracker,strokes,scoring zone,practice,tee,fairway,birdie
```

**Description** (≤4000):
```
Scratch Score is a golf scorecard built around one simple idea: lower scores come from better decisions inside 100 yards. Instead of just counting strokes, Scratch Score breaks every hole into the two things that actually move your score.

THE SCORING-ZONE METHOD
• Strokes to the scoring zone — how many shots to get within 100 yards of the green
• Strokes in the scoring zone — how many to hole out from there (the goal: 3 or fewer)
• Your hole total is the sum of the two, with putts tracked separately so you can see where strokes are really going.

It's the fast, tap-friendly, hole-by-hole scoring you're used to — just focused on the part of the game that decides your round.

FEATURES
• Quick hole-by-hole scoring with big, glanceable controls
• Automatic round totals, front/back splits, and score-to-par
• Scoring-zone stats: how often you get down in three, average strokes to the zone, up-and-downs, and putts
• Trends across rounds so you can see real improvement
• Full course support — par, stroke index, and per-tee yardages
• Search and download thousands of real courses, or add your own
• Works completely offline on the course and syncs automatically when you reconnect
• Sign in with Apple, Google, or email

Play smarter. Score lower. Scratch Score.
```

**Support URL:** `https://blkfoxio.github.io/scratch-score/support.html`
**Marketing URL (optional):** `https://blkfoxio.github.io/scratch-score/`
**Privacy Policy URL:** `https://blkfoxio.github.io/scratch-score/privacy.html`

**Copyright:** `2026 <your name or entity>`

**Age rating:** answer every content question **None** → results in **4+**.

---

## 2. App Privacy ("nutrition labels")

App Store Connect → App Privacy. Declare these; **none used for tracking**, no third-party ads.

| Data type | Category | Linked to user? | Purpose |
|-----------|----------|-----------------|---------|
| Email address | Contact Info | Yes | App Functionality |
| Name | Contact Info | Yes | App Functionality |
| User ID | Identifiers | Yes | App Functionality |
| Other user content (rounds/scores/courses) | User Content | Yes | App Functionality |

- "Do you or your third-party partners use data for tracking?" → **No**
- No location, health, contacts, browsing, or advertising data is collected.

---

## 3. Demo account for App Review

Reviewers can't use your Apple/Google, so give them **email/password** credentials:

1. In the app, sign up a dedicated account, e.g. `appreview@scratchscore.app` with a strong password.
2. Add a course (or download one) and score at least one round so the reviewer sees data.
3. In App Store Connect → App Review Information:
   - **Sign-in required:** Yes
   - **Username / Password:** the demo account
   - **Notes:**
     ```
     Scratch Score uses a "scoring-zone" method: per hole you enter strokes to reach
     within 100 yards of the green (A) and strokes to hole out from there (B); the hole
     total is A + B, with putts tracked separately. To test: Rounds tab → + → pick a
     course → score holes → Finish to see the summary. Account deletion is in
     Settings → Delete Account.
     ```

---

## 4. Screenshot shot-list

Required: **iPhone 6.9"** (1320×2868, e.g. iPhone 16 Pro Max). 6.5" is optional but nice.
Capture these 5–6, portrait, on a real device or once the simulator is fixed:

1. **Sign In** — the branded hero screen with the tagline. Caption: "Score smarter with the scoring-zone method."
2. **Hole scoring** — a hole mid-entry showing the big A/B steppers and the total badge. Caption: "Fast, focused hole-by-hole scoring."
3. **Round summary** — totals, to-par, down-in-3 %. Caption: "See where your strokes actually go."
4. **Stats/trends** — the charts across rounds. Caption: "Track real improvement over time."
5. **Course search** — the download-a-course screen. Caption: "Thousands of real courses, ready to play."
6. *(optional)* **Scorecard grid** — the 9/18 overview. Caption: "Your whole round at a glance."

Tip: score a demo round first so the screens show realistic data, not empty states.

---

## 5. Build → upload → TestFlight → submit runbook

**Prerequisites**
- Paid Apple Developer Program membership (you have this).
- App record created in App Store Connect (My Apps → ➕ → New App; bundle id `app.scratchscore`, SKU e.g. `scratchscore`, primary language English).
- All Edge Functions deployed and Apple `.p8` secrets set (account deletion working).

**Archive & upload (Xcode)**
1. In `Secrets.xcconfig`, confirm real Supabase values are set (release uses the same config file).
2. Xcode → target **ScratchScore** → Signing & Capabilities → Team set, **Automatically manage signing** on.
3. Run destination dropdown → **Any iOS Device (arm64)**.
4. **Product → Archive**. When it finishes, the Organizer opens.
5. Select the archive → **Distribute App → App Store Connect → Upload** → accept defaults → Upload.
   - Export compliance: no prompt, because `ITSAppUsesNonExemptEncryption = false` is already set.

**CLI alternative**
```bash
xcodegen generate
xcodebuild -project ScratchScore.xcodeproj -scheme ScratchScore \
  -destination 'generic/platform=iOS' -archivePath build/ScratchScore.xcarchive archive
xcodebuild -exportArchive -archivePath build/ScratchScore.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
# then upload build/export/*.ipa via Xcode Organizer or `xcrun altool`/Transporter
```
(ExportOptions.plist: method `app-store`, your team id, automatic signing.)

**TestFlight**
1. After upload, the build shows in App Store Connect → TestFlight (a few minutes to process).
2. Answer the export-compliance question if prompted (No).
3. Add yourself to **Internal Testing**, install via the TestFlight app, and smoke-test: sign in (all 3 methods), score a round, offline→sync, delete account.

**Submit for review**
1. App Store Connect → your app → **(＋ version 1.0)**.
2. Fill the metadata (§1), upload screenshots (§4), attach the processed build.
3. Complete **App Privacy** (§2) and **App Review Information** with the demo account (§3).
4. **Add for Review → Submit**.

**Common rejection triggers (already handled)**
- ✅ Sign in with Apple present (required because Google is offered)
- ✅ In-app account deletion with token revocation
- ✅ Privacy policy reachable + App Privacy completed
- ✅ Works without crashing; no placeholder content
- ⚠️ Make sure the demo account actually logs in and has data before submitting.
