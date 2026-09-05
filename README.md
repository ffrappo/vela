<div align="center">
  <img src="assets/yattee-logo.png" width="112" height="112" alt="Vela app icon" />
  <h1>Vela</h1>
  <p>A calm, ad-free video client for iPhone, iPad, Apple TV, and Mac.</p>
</div>

Vela starts from the actively maintained [Yattee](https://github.com/yattee/yattee) codebase and focuses first on durable iPhone playback. Browsing remains comfortable in portrait. Wide videos can enter landscape automatically, and consecutive wide videos stay there through loading, queue changes, and autoplay.

## First milestone

- Native SwiftUI browsing and custom MPV playback
- No advertising surfaces
- Persistent landscape playback between consecutive wide videos
- Explicit fullscreen entry and exit through public scene geometry APIs
- Picture in Picture readiness that follows AVKit state
- Queue, history, subscriptions, captions, SponsorBlock, background audio, and downloads inherited from the upstream foundation
- iOS 18+, macOS 15+, tvOS 18+

## Build

Open `Yattee.xcodeproj`, select the `Yattee` scheme, and run the iOS app. The installed app is displayed as **Vela** and uses bundle identifier `app.vela.video`.

Command-line verification:

```bash
xcodebuild -project Yattee.xcodeproj \
  -scheme Yattee \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Focused orientation policy tests:

```bash
xcodebuild test -project Yattee.xcodeproj \
  -scheme Yattee \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Plus' \
  -only-testing:YatteeTests/PlayerOrientationPolicyTests
```

## Architecture decision

Research found no stable direct YouTube contract. Extractors continue adapting to SABR, player-signature, client-profile, and proof-of-origin token changes. Vela therefore keeps content APIs behind the existing service boundary and keeps orientation policy independent from extraction.

The complete, cited research is preserved in:

- [`Docs/Research/youtube-client-foundations-2026.md`](Docs/Research/youtube-client-foundations-2026.md)
- [`Docs/Research/youtube-client-foundations-2026.json`](Docs/Research/youtube-client-foundations-2026.json)

## Distribution and policy

Technical capability and distribution permission are separate decisions. The cited research records YouTube API policy, Terms of Service, and App Store constraints. Review those constraints before publishing binaries or operating an extraction service.

## Upstream and license

Vela keeps `https://github.com/yattee/yattee.git` as the `upstream` Git remote. The project remains licensed under the GNU Affero General Public License v3. See [`LICENSE`](LICENSE).
