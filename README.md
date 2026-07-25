# Zetaris Central — iOS

Native SwiftUI client for the Zetaris Central backend (the `zetbook` Next.js
app, which serves `/api/v1`).

## Requirements
- Xcode 15+
- [XcodeGen](https://github.com/yonwoo/XcodeGen) — `brew install xcodegen`
  (used to generate the `.xcodeproj` from `project.yml`, so the project file
  itself isn't checked in).

## Open it
```bash
cd ios
xcodegen generate        # creates ZetarisCentral.xcodeproj
open ZetarisCentral.xcodeproj
```
Then pick an iPhone simulator and hit Run.

## Point it at the backend
`ZetarisCentral/Config.swift` holds the base URL. Defaults to
`http://localhost:3030/api/v1`, which the **iOS Simulator** can reach directly
(it shares the Mac's network). Make sure the backend is running:

```bash
# in the zetbook repo
npm run dev -- -p 3030
```

Log in with any existing account's email + password (the same credentials as
the web app).

> On a **physical device**, change the base URL to your Mac's LAN IP
> (e.g. `http://192.168.1.20:3030/api/v1`) and ensure both are on the same
> network.

## What's here (v1)
- Bearer-token auth against `POST /api/v1/auth/login`; token stored in the
  Keychain.
- Feed screen (`GET /api/v1/feed`) with pull-to-refresh and a composer
  (`POST /api/v1/posts`).

This is the first vertical slice; screens for messages, spaces, groups, events,
notifications, and profiles come next against the same API.
