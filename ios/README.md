# Volleyball Trainer — iPhone app

A thin native wrapper around the booking site in the repo root (`index.html`).
It loads that exact file into a `WKWebView`, so the web app and the iPhone app
always share one source of truth — edit `index.html` at the repo root and both
the GitHub Pages site and the app pick up the change.

## Open it in Xcode

1. On a Mac, open `ios/VolleyballTrainer/VolleyballTrainer.xcodeproj` in Xcode
   (15 or newer recommended).
2. Select the `VolleyballTrainer` target, then under **Signing & Capabilities**
   pick your Apple ID / team so Xcode can code-sign the app (required even for
   the simulator on newer Xcode versions in some setups, and always required
   for a real device).
3. Pick an iPhone simulator (or your plugged-in iPhone) from the scheme
   selector and hit **Run**.

Bundle identifier is currently `com.juicseph.volleyballtrainer` — change it
under **Signing & Capabilities → Bundle Identifier** if you want your own
reverse-DNS namespace, or if Xcode complains it's taken.

## How it's structured

```
ios/
  README.md
  VolleyballTrainer/
    VolleyballTrainer.xcodeproj/     ← open this in Xcode
    VolleyballTrainer/
      VolleyballTrainerApp.swift     ← @main entry point
      ContentView.swift              ← WKWebView wrapper + link/download handling
      Info.plist
      Assets.xcassets/               ← app icon + accent color
```

`index.html` itself is **not** duplicated into the app folder — the Xcode
project references the repo-root file directly (`../../index.html`), so
there's only ever one copy to keep in sync.

### What `ContentView.swift` handles beyond a plain web view

- Links the page opens with `target="_blank"` (Instagram, "Add to Calendar")
  or `mailto:` / `tel:` open in Safari/Mail/Phone instead of doing nothing.
- The admin dashboard's **Export CSV** button triggers a real file download
  and hands it to the iOS share sheet (Save to Files, AirDrop, etc.).
- Safe-area insets (notch / home indicator) are passed through to the page
  via CSS `env(safe-area-inset-*)`, which `index.html` already uses.

## Before you ship this

A few things worth knowing about the current app, carried over from the web
version:

- **The admin password is a hardcoded string in the client-side JavaScript**
  (`ADMIN_PW` in `index.html`) — anyone who views source (or unzips the app
  bundle) can read it. Fine for a solo-operator MVP; not fine once this is a
  real business with money on the line. Worth moving admin auth server-side
  before you rely on it to gate anything sensitive.
- **Booking data is stored via a Google Apps Script web app** (`SHEETS_URL`)
  and confirmation emails go through **EmailJS** (`EJS_*` keys, also visible
  client-side). Both need network access — the app doesn't work fully offline,
  which is normal for a live booking flow but worth knowing if you demo it
  somewhere without signal.
- No push notifications, no App Store listing/assets beyond the generated
  icon, and this hasn't been run through an actual Xcode build (this
  environment doesn't have Xcode/macOS available) — so first build may
  surface a small thing or two Xcode wants adjusted (signing team, bundle ID
  conflicts). Everything above was hand-verified for structural correctness,
  but a first-build pass on your Mac is worth doing before you rely on it.
