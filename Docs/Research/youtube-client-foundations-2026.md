# Building a Stable Ad-Free YouTube Client in 2026

## Executive Summary

- **Recommended Product Boundary**: Official YouTube APIs and the IFrame Player API provide the lowest policy and distribution risk, but the IFrame documentation describes an embedded JavaScript-controlled player rather than native media URLs, downloads, or background playback [14] -> Ship an official-player App Store edition first, and do not promise ad removal, offline downloads, or background video in that edition.
- **Best iOS Reference**: Yattee is an active AGPL-3.0 SwiftUI client for iOS, tvOS, and macOS, with **3,007 commits**, SponsorBlock, queue/history, fullscreen, PiP, and background audio; its Yattee Server is self-hosted and powered by yt-dlp [12][235.45-53] -> Reuse its architectural ideas and test cases, but avoid an unreviewed fork unless AGPL obligations and backend ownership are acceptable.
- **Best Extraction Components**: NewPipe Extractor is a mature GPL-3.0 independent library with **3,282 commits**, while yt-dlp is Unlicense and supports thousands of sites with stable, nightly, and master release channels [10][236.29-30][239.39-40][239.72-75] -> Put extraction behind a replaceable server adapter; do not make the iOS UI depend directly on either project.
- **Playback Reliability**: NewPipe v0.29.1 included a YouTube SABR workaround, live-stream fixes, rotation fixes, and download fixes [23][234.64-80]. LibreTube v32.1 addressed playback failures caused by YouTube's newer SABR protocol [4] -> Treat SABR, player-client changes, signatures, and token requirements as normal operational incidents, not one-time integration work.
- **Policy Divide**: YouTube Developer Policies prohibit API clients from downloading or caching audiovisual content, enabling offline playback, separating audio, background playback, modifying the player, or blocking YouTube advertisements [21][249.95-99] -> Technical feasibility must not be presented as policy permission.
- **Terms Risk**: YouTube's Terms permit personal, non-commercial viewing/listening and embeddable-player use, but restrict downloading, copying, circumvention, and automated access without permission [13] -> Obtain counsel before shipping an extraction service, and keep technical and legal product decisions separate.
- **App Store Risk**: Apple requires public APIs and the currently shipping OS under guideline 2.5.1 [18]. Apple also reviews submitted apps and updates -> Avoid private InnerTube calls in the App Store binary and make the app substantially native rather than a thin web wrapper.
- **Orientation Recommendation**: Keep browsing portrait by default, present a dedicated landscape-native player scene, request landscape scene geometry on entry, and keep the player scene's supported orientations locked to landscape until dismissal. `requestGeometryUpdate` is available from iOS 16 and accepts preferred iOS orientations [8][253.78-84].
- **Player Recommendation**: Start with AVPlayerViewController for standard controls, PiP, subtitles, alternate audio, and AirPlay support [9]. Move to a custom AVPlayer/AVPlayerLayer only when the product needs custom controls, SponsorBlock seeking, source failover, or a special landscape UX.

## Decision Context: What Can Actually Be Shipped

The central decision is not simply which open-source repository has the most features. It is which combination of source acquisition, player, account model, and distribution channel can remain useful when YouTube changes its delivery stack. A technically capable extractor can deliver more control than the official player, but it also creates the greatest upstream, policy, account-security, and App Store exposure.

The official route is narrow but defensible. The IFrame Player API embeds and controls a YouTube player with JavaScript, including queuing, playback control, volume, video information, and state events [14]. It does not document native media playback, downloads, or background playback [14]. YouTube's Terms expressly permit showing videos through the embeddable player [13], which makes this the practical baseline for a public App Store release.

The extraction route is feature-rich but conditional. Yattee, NewPipe, LibreTube, Piped, Invidious, yt-dlp, and InnerTube clients demonstrate that subscriptions, local history, SponsorBlock, background audio, captions, and direct media playback are feasible. That evidence supports engineering feasibility, not a conclusion that a commercial distribution model is permitted.

**Decision-ready insight:** define two product profiles before writing the player: an App Store profile based on supported player APIs, and a self-hosted or sideloaded experimental profile based on replaceable extraction adapters. Do not let the experimental profile determine the public product's data model.

## Open-Source Starting Points Compared

| Candidate | Current evidence | License and architecture | Strongest reuse | Main weakness for native iOS |
|---|---|---|---|---|
| Yattee | **3,007 commits**; latest visible release **2.0.0-beta.270**, a prerelease with recent fixes [12][237.18-27][237.41-57] | AGPL-3.0; native SwiftUI; optional self-hosted Yattee Server powered by yt-dlp [12] | iOS UX, queue/history, SponsorBlock, fullscreen, PiP, background audio | AGPL and server coupling; several requested capability details are not documented in the extracted evidence |
| NewPipe | **12,280 commits**, GPL-3.0; Android app with app, desktopApp, iosApp, and shared directories visible in the repository [19][233.13-23] | GPL-3.0; mature Android implementation | Feature behavior, playback state, local subscriptions/history, downloads, captions | Android-first implementation and GPL integration constraints |
| NewPipe Extractor | **3,282 commits**, GPL-3.0; independent extractor library [10][236.29-30] | GPL-3.0; extractor/Gradle-oriented library | Service extraction and a useful reference for stream models | Not an iOS-native library; GPL and upstream YouTube breakage remain |
| LibreTube | **13,379 commits**, GPL-3.0; Android frontend with optional Piped accounts [1][240.58-69] | GPL-3.0; Android app, Piped backend option | Subscriptions, groups, playlists, history, downloads, background playback, SponsorBlock | Piped dependency and recent playback/API breakage |
| FreeTube | AGPL-3.0 Electron desktop app; current beta work includes SABR/local API playback changes [22][238.28-60] | AGPL-3.0; desktop Electron and Shaka/local API path | Desktop UX, local API design, privacy-oriented account model | Not a mobile-native starting point; built-in downloader was removed after SABR made it unusable [16] |
| Piped | Frontend **4,930 commits**, backend **1,322 commits**; both AGPL-3.0 [11][244.3-9] | AGPL frontend/backend; backend uses NewPipe Extractor and proxies media | Self-hosting, API boundary, proxy architecture | Operational server, proxy, instance, and upstream dependency burden |
| Invidious | AGPL-3.0; **5,958 commits** and release **v2.20260804.1** [7][280.0][370.38-39] | Server-side alternative frontend and API; documentation exposes authenticated endpoints | Public API shape, server-side frontend patterns | Scraping/instance model, availability variation, and ToS risk |
| yt-dlp | **23,997 commits**, Unlicense; stable, nightly, and master channels [20][239.72-75] | Python extractor/downloader and postprocessor | Broad format, caption, live, and site support | Stable builds can be stale after external site changes [20]; PO-token requirements are increasing [29] |
| YouTube.js | **1,688 commits**, MIT; JavaScript InnerTube client for Node, Deno, and browsers [36][360.35-36] | MIT; private InnerTube API client | Search, metadata, sessions, and API experimentation | Private API instability and App Store review exposure |

The table points to a clear choice. Yattee is the best iOS product reference, NewPipe Extractor is the best extraction reference if GPL is acceptable, and yt-dlp is the best server-side breadth adapter. Piped and Invidious should be treated as independently operated services, not assumed to be reliable public dependencies.

## Feature and Reliability Matrix

| Capability | Official IFrame/API | Yattee | NewPipe/Extractor | LibreTube | Piped/Invidious | yt-dlp/InnerTube |
|---|---|---|---|---|---|---|
| Native direct media | No documented native URL capability [14] | Yes by architecture, via server | Yes | Yes | Yes through proxy/extraction | Yes |
| Authentication | IFrame documentation does not describe user auth [14] | Not fully established in extracted evidence | No account required; local subscriptions [19][233.84] | Optional Piped accounts [1] | Authenticated endpoints exist in Invidious [32] | Cookies can work around extractor login gaps [34] |
| Subscriptions/history | Official API can support account data, but policy/data rules apply | Queue/history documented [12] | Local subscriptions and watch history [19][233.88] | Subscriptions and history [1] | Server account/storage model | Must be implemented by the product |
| SponsorBlock | Not an official IFrame feature | Documented [12] | Not documented in supplied NewPipe evidence | Documented [1] | Frontend-dependent | Product layer |
| Background playback | Policy-prohibited for API clients [21] | Documented [12] | Background audio documented [19] | Documented [1] | Depends on client/player | Product layer |
| Downloads/offline | Policy prohibits without approval [21] | Server/client capability not fully established | Video, audio, and subtitle downloads documented [19] | Downloads documented [1] | Proxy/cache operational issue | Core strength, but PO-token risk [29] |
| Captions | IFrame player can expose player behavior but not extraction | Not fully documented in supplied evidence | Closed captions and subtitle downloads [19][233.91] | Not fully documented in supplied evidence | API-dependent | Broad extractor capability |
| PiP/AirPlay | Web embedding, not native AVKit | PiP documented [12] | Android-specific behavior | Android-specific behavior | Client-specific | iOS player layer |
| Casting | Not established | Not established | Not established | Not established | Frontend-specific | Not a downloader feature |
| Live/age-restricted/Shorts | Official player is the most defensible baseline | Not fully documented | Live fixes exist; SABR workaround has a made-for-kids limitation [23][234.76] | Recent SABR fixes [4] | Upstream dependent | Client/token dependent |

The feature matrix shows why no single repository should own the entire product. Account state, history, SponsorBlock, and playback policy belong in the app's domain layer. Extraction and source selection belong behind a server adapter. The player should consume a normalized manifest rather than NewPipe, Piped, InnerTube, or yt-dlp objects directly.

## Recommended Architecture: Native Shell, Replaceable Source Adapters

Use SwiftUI for browsing, navigation, settings, subscriptions, history, and queue management. Embed UIKit where the platform requires precise scene orientation, AVKit lifecycle control, PiP restoration, AirPlay routing, remote-command handling, and safe-area coordination. Keep a `PlayerCoordinator` owned by the scene rather than by an individual SwiftUI view so consecutive landscape videos reuse the same player session.

The domain model should include `VideoID`, `VideoMetadata`, `PlaybackSource`, `CaptionTrack`, `AudioTrack`, `Chapter`, `SponsorSegment`, and `PlaybackSession`. A source adapter should expose `resolveVideo`, `resolveFeed`, `resolveCaptions`, `resolveRelated`, and `health`. Implement at least `OfficialEmbedAdapter` and one experimental `ExtractedMediaAdapter`; keep their capabilities explicit so the UI can disable unsupported actions rather than failing silently.

For extraction, prefer a server-side process. Yattee Server demonstrates the pattern of a self-hosted backend powered by yt-dlp [12]. Piped demonstrates a larger frontend/backend split and a backend built with NewPipe Extractor [2]. The server should not receive Google cookies in the MVP. If authenticated extraction is ever added, isolate credentials, encrypt them, support immediate revocation, and make the feature opt-in.

Use a circuit breaker per adapter. Record response class, extractor version, client profile, video type, region, and failure reason. On failure, retry only safe idempotent metadata calls, rotate to a supported fallback source, and show a truthful capability error. Never conceal a policy or availability limitation behind an indefinite spinner.

**Decision:** build the product around a stable internal protocol and not around a particular extractor. This converts upstream breakage from a mobile release emergency into a server adapter release, while retaining the option to remove an adapter without rewriting the app.

## iOS Landscape-Native Player Without Forced Device Rotation

The desired behavior is a portrait browsing scene and a player scene whose content is natively laid out in landscape. The critical distinction is between changing the window scene's geometry and pretending that the device rotated. On iOS 16 and later, `UIWindowScene.requestGeometryUpdate` requests a scene geometry change and accepts `UIWindowScene.GeometryPreferences.iOS(interfaceOrientations:)`, including landscape orientations [8][253.78-84]. Do not set `UIDevice.orientation` as the primary mechanism.

Use a UIKit `PlayerViewController` hosted from SwiftUI with `UIViewControllerRepresentable`, or use a UIKit navigation boundary around the player route. On player entry, set a scene-level orientation policy to landscape, request the landscape geometry, and wait for the transition before laying out controls. On exit, restore the portrait policy and request portrait geometry. `supportedInterfaceOrientations(for:)` returns the orientations supported by a window scene, and its result replaces the Info.plist value for that scene [3].

To remain in landscape between consecutive landscape videos, do not dismiss and recreate the player controller when the item changes. Keep the same player scene, replace the current `AVPlayerItem`, preserve the orientation policy, and transition metadata and controls in place. If the next item is portrait, either retain the landscape player by product policy or provide an explicit exit/fullscreen choice; do not oscillate the scene orientation based solely on each item's aspect ratio.

Start with `AVPlayerViewController`. Apple documents native controls, PiP, subtitles, alternate audio, fullscreen behavior, and automatic AirPlay support when configured [9]. It reduces risk around remote commands, PiP lifecycle, media routes, and accessibility. Its costs are less control over the UI, more care around custom SponsorBlock seeking, and potential friction when the product needs a bespoke persistent landscape shell.

Move to a custom `AVPlayer` plus `AVPlayerLayer` only after the MVP proves that AVPlayerViewController cannot express the desired controls. Custom PiP uses `AVPictureInPictureController`, requires a strong controller reference, an appropriate audio session and background mode, a supported player layer or sample-buffer layer, and delegate-based restoration [15]. Apple requires PiP to begin from user interaction, not an unsolicited programmatic launch [15]. Configure safe areas at the container level, keep the video layer edge-to-edge, and place controls in `viewSafeAreaInsetsDidChange`-aware overlays rather than hard-coded portrait coordinates.

**Implementation pattern:** SwiftUI owns browsing and state; UIKit owns the player scene; AVKit owns standard playback; a single coordinator owns the player and orientation policy; scene geometry is requested only on route transitions; item replacement never resets orientation.

## Technical, Legal, and Distribution Risk Are Separate Decisions

### Technical facts

YouTube is actively changing delivery protocols. NewPipe's latest visible release included a SABR workaround and playlist, live-stream, rotation, and download fixes [23]. LibreTube states that YouTube progressively removed support for traditional streaming protocols and that SABR support was added to improve reliability [4]. yt-dlp documents that PO Tokens are increasingly required and cannot be generated by yt-dlp itself [29]. These are engineering facts that justify adapters, monitoring, and rollback.

Authentication is especially dangerous operationally. yt-dlp documents browser-cookie import and warns that exporting cookies can expose cookies for all sites [34]. Therefore, a public service should not ask users to upload browser cookie files in the MVP. A local-only extraction mode is safer operationally than a centralized cookie-handling service, but it does not remove terms or distribution questions.

### Legal and policy assessment

The official Developer Policies prohibit downloading, importing, backing up, caching, or storing copies of audiovisual content without prior written approval, offline playback, separating audio or video, background playback, player modification, and blocking or modifying advertisements [21][249.95-99]. The policy also limits API Data permissions and requires a clear process for user-data deletion [21][249.9-11]. This makes an ad-free, downloadable, background-playing client incompatible with the official API path unless the relevant permissions and rights exist.

The Terms of Service separately restrict downloading, reproducing, automated access, and circumvention, while allowing personal non-commercial viewing/listening and embeddable-player use [13]. These clauses create material legal risk for scraping or extraction, but this report does not determine legal liability. Obtain jurisdiction-specific legal advice before public distribution.

### App Store and distribution assessment

Apple's guideline 2.5.1 says apps may use only public APIs and must run on the currently shipping OS [18]. App Store review covers apps, updates, bundles, in-app purchases, and in-app events. A product that depends on undocumented InnerTube behavior, disables YouTube ads, or presents third-party content without clear rights has a materially higher review and takedown risk than a native app using the official player.

| Distribution model | Technical capability | Policy/platform risk | Recommendation |
|---|---|---|---|
| App Store official-player edition | Moderate; embedded playback and app-managed metadata | Lowest among options, though review and third-party rights remain | MVP and primary public product |
| App Store direct-extraction edition | High | High: private APIs, ad modification, downloads/background behavior, third-party content | Do not make this the first public build |
| TestFlight experimental adapter | High but temporary | Still subject to platform and terms constraints | Use only for controlled technical validation |
| Sideloaded local client | High | Lower App Store exposure, but ToS and rights remain | Practical for an opt-in research build |
| Self-hosted server plus native client | High and controllable | Transfers operations and compliance burden to operator/user | Phase 2 for technically sophisticated users |
| Desktop Electron client | High; FreeTube is a relevant reference | Less iOS review exposure, but AGPL/ToS/maintenance remain | Useful companion, not the iOS base |
| Android F-Droid-style distribution | High; NewPipe and LibreTube prove the model | Different distribution environment; GPL obligations remain | Strong Android alternative |

The table is a risk classification, not legal advice. The practical recommendation is to keep the App Store binary conservative and publish experimental extraction code separately with clear terms, documentation, and an explicit legal review.

## Threat Model for Upstream Breakage

| Threat | Observable symptom | Likelihood | Impact | Mitigation and test |
|---|---|---:|---:|---|
| SABR or manifest protocol change | No streams, audio-only playback, repeated retries | High | High | Daily canary videos, adapter version pinning, fallback clients, rollback |
| PO-token enforcement | Some videos fail while others work | Increasing; documented by yt-dlp [29] | High | Capability detection, no promise of universal downloads, server-side token strategy only after legal review |
| Signature/player JavaScript change | HTTP 403 or unusable URLs | High | High | Golden-video suite, extractor health endpoint, rapid server releases |
| Client-profile experiment | Different results by device or region | Medium | High | Record client profile and region; test age-restricted, live, Shorts, kids, and geo cases |
| Public instance outage | Feed/search/playback timeout | High | Medium to high | Self-host option, instance health checks, bounded timeout, source failover |
| Account/cookie compromise | Unauthorized access or account lock | Medium | Critical | No cookies in MVP, local-only credentials, encryption, deletion and revocation |
| Caption/track schema change | Missing captions or wrong language | Medium | Medium | Track parser fixtures and language fallback tests |
| SponsorBlock API outage or bad segment | Wrong skips or no skips | Medium | Low to medium | Feature degradation to disabled SponsorBlock; never alter source media |
| Apple orientation/PiP regression | Stuck rotation, black PiP, unsafe controls | Low to medium | Medium | Physical-device matrix, scene transition tests, PiP restoration tests |
| License incompatibility | Distribution or source disclosure dispute | Medium | High | SPDX inventory, legal review, isolate GPL/AGPL services and modifications |

The threat model suggests an operational SLO: metadata may degrade gracefully, but playback failures must be observable within minutes and recoverable by swapping an adapter. Do not ship an extractor update directly to every client when the server can absorb the change.

## Concrete MVP and Phased Plan

### MVP: App Store-safe native shell

1. SwiftUI portrait browse, search, channel pages, local favorites, local history, queue, settings, and accessibility.
2. Official IFrame Player API route with clear attribution and no ad blocking, download, or background-video controls.
3. UIKit player boundary with landscape scene geometry request, persistent player coordinator, explicit fullscreen entry/exit, and portrait restoration.
4. AVPlayerViewController only for local product-owned test media in the first native AVKit harness; use the official embed route for YouTube content until the source model is approved.
5. Instrumented feature flags for PiP, captions, AirPlay, and casting, each independently testable.
6. Privacy policy, data minimization, account deletion, source attribution, and an App Review demo account or reviewer instructions where needed.

### Phase 2: Controlled self-hosted extraction

Add a separate server adapter using yt-dlp or NewPipe Extractor, not both in the same request path initially. Normalize metadata and media manifests, add canary monitoring, and support local subscriptions/history independently of upstream accounts. Start with public videos and captions; explicitly classify live, Shorts, age-restricted, made-for-kids, and geo-restricted behavior as best effort.

### Phase 3: Reliability and advanced features

Add adapter fallback, source health scoring, resumable downloads only where the product has confirmed rights and distribution terms, SponsorBlock as a separate metadata service, robust caption conversion, and a self-host deployment package. Add authenticated sources only after a threat-model and legal review. Use Yattee's queue/history/SponsorBlock/PiP architecture as a test reference, not as an automatic license shortcut.

### Phase 4: Android and cross-platform

For Android, evaluate NewPipe Extractor and LibreTube/Piped patterns directly. NewPipe already documents background audio, local subscriptions, history, 4K playback, captions, and video/audio/subtitle downloads [19]. LibreTube adds subscription groups, user playlists, bookmarks, history, downloads, background playback, and SponsorBlock [1]. These make Android a materially stronger fit for an extraction-oriented distribution model.

Do not choose FreeTube as the cross-platform mobile base. Its Electron architecture and current SABR work are useful desktop references, but its built-in downloader was removed because SABR made it unusable [16]. A shared protocol and test suite is more valuable than sharing the UI framework.

## Testing Strategy and Release Gates

Create a corpus of stable, public test videos covering short and long VOD, live, Shorts, age-restricted, made-for-kids, geo-restricted, captions, multiple audio tracks, chapters, premieres, removed videos, and videos with SponsorBlock segments. Run it against every adapter nightly and on every extractor update. Store only identifiers and diagnostic metadata unless rights permit media storage.

For iOS, test iPhone portrait browsing, both landscape directions, rotation locked and unlocked, consecutive landscape items, transition to a portrait item, multitasking and iPad, external display, AirPlay, PiP start/stop/restoration, audio interruptions, Bluetooth route changes, lock screen commands, memory pressure, network handoff, and safe-area changes. Verify that the player scene remains landscape between items without recreating the scene and that browsing returns to portrait.

Add contract tests for normalized metadata and manifests, property tests for timestamp and chapter conversion, snapshot tests for safe-area layouts, and fault injection for 403, 429, malformed manifests, missing captions, expired URLs, and instance timeouts. Release gates should require: no credential logging; adapter health above a defined threshold on the golden corpus; successful PiP restoration; no orientation deadlock; graceful feature disablement; license inventory review; and a written policy/legal decision for every distribution profile.

## Synthesis: The Right Tradeoff Is a Two-Profile Product

The candidates differ along four decisive dimensions: native UI, extraction depth, legal/platform exposure, and operational ownership. Yattee leads on iOS-native product learning; NewPipe leads on mature Android behavior; NewPipe Extractor and yt-dlp lead on reusable extraction; Piped and Invidious lead on server/API separation; official APIs lead on distribution defensibility. None leads on all dimensions simultaneously.

The main non-obvious tension is that the most maintained technical projects are maintained precisely because they continually adapt to an unstable upstream. NewPipe's SABR work, LibreTube's playback fixes, FreeTube's downloader removal, yt-dlp's PO-token warning, and Yattee's beta fixes are evidence of healthy maintenance, but also evidence that the source layer is not a stable contract [23][238.48-54][242.62-65][363.7]. Maintenance quality reduces mean time to recovery; it does not eliminate breakage.

The second tension is between feature value and distribution value. Background audio, downloads, ad removal, SponsorBlock, and direct media playback are attractive product features, but official YouTube policy explicitly disallows key parts of that combination for API clients [21][249.95-99]. The recommendation is therefore not to pretend one implementation satisfies every goal. It is to ship a conservative App Store product, keep the source layer replaceable, and offer a separately governed self-hosted or sideloaded technical profile only after legal and security review.

**Final recommendation:** use Yattee as the iOS UX and lifecycle reference; use SwiftUI plus UIKit and AVPlayerViewController for the first player; use `requestGeometryUpdate` and scene-specific orientation policy for landscape persistence; define an adapter protocol before integrating yt-dlp, NewPipe Extractor, Piped, Invidious, or YouTube.js; launch the App Store profile with the official player; and treat direct extraction as a separately distributed research or self-hosted capability rather than the foundation of the public iOS product.

## References

1. *GitHub - libre-tube/LibreTube: An alternative frontend for YouTube, for Android. · GitHub*. https://github.com/libre-tube/LibreTube
2. *GitHub - TeamPiped/Piped-Backend: The core component behind Piped, and other alternative frontends! · GitHub*. https://github.com/TeamPiped/Piped-Backend
3. *supportedInterfaceOrientations(for:) | Apple Developer Documentation*. https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/supportedinterfaceorientations(for:)
4. *Releases · libre-tube/LibreTube · GitHub*. https://github.com/libre-tube/LibreTube/releases
5. *GitHub - TeamPiped/documentation · GitHub*. https://github.com/TeamPiped/Documentation
6. *Releases · yattee/yattee · GitHub*. https://github.com/yattee/yattee/releases
7. *GitHub - iv-org/invidious: Invidious is an alternative front-end to YouTube · GitHub*. https://github.com/iv-org/invidious
8. *requestGeometryUpdate(_:errorHandler:) | Apple Developer Documentation*. https://developer.apple.com/documentation/uikit/uiwindowscene/requestgeometryupdate(_:errorhandler:)
9. *AVPlayerViewController | Apple Developer Documentation*. https://developer.apple.com/documentation/avkit/avplayerviewcontroller
10. *GitHub - TeamNewPipe/NewPipeExtractor: NewPipe's core library for extracting data from streaming sites · GitHub*. https://github.com/TeamNewPipe/NewPipeExtractor
11. *GitHub - TeamPiped/Piped: An alternative privacy-friendly YouTube frontend which is efficient by design. · GitHub*. https://github.com/TeamPiped/Piped
12. *GitHub - yattee/yattee: Privacy oriented video player for iOS, tvOS and macOS · GitHub*. https://github.com/yattee/yattee
13. *Terms of Service*. https://www.youtube.com/static?template=terms
14. *YouTube Player API Reference for iframe Embeds  |  YouTube IFrame Player API  |  Google for Developers*. https://developers.google.com/youtube/iframe_api_reference
15. *Adopting Picture in Picture in a Custom Player | Apple Developer Documentation*. https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player
16. *Releases · FreeTubeApp/FreeTube · GitHub*. https://github.com/FreeTubeApp/FreeTube/releases
17. *GitHub - TeamPiped/Piped: An alternative privacy-friendly YouTube frontend which is efficient by design.*. https://github.com/TeamPiped/Piped-Frontend
18. *App Review Guidelines - Apple Developer*. https://developer.apple.com/app-store/review/guidelines/
19. *GitHub - TeamNewPipe/NewPipe: A libre lightweight streaming front-end for Android. · GitHub*. https://github.com/TeamNewPipe/NewPipe
20. *GitHub - yt-dlp/yt-dlp: A feature-rich command-line audio/video downloader · GitHub*. https://github.com/yt-dlp/yt-dlp
21. *YouTube API Services - Developer Policies  |  Google for Developers*. https://developers.google.com/youtube/terms/developer-policies
22. *GitHub - FreeTubeApp/FreeTube: An Open Source YouTube app for privacy · GitHub*. https://github.com/FreeTubeApp/FreeTube
23. *Releases · TeamNewPipe/NewPipe · GitHub*. https://github.com/TeamNewPipe/NewPipe/releases
24. *Complying with YouTube's Developer Policies  |  Google for Developers*. https://developers.google.com/youtube/terms/developer-policies-guide
25. *YouTube API Services Terms of Service  |  Google for Developers*. https://developers.google.com/youtube/terms/api-services-terms-of-service
26. *prefersInterfaceOrientationLocked | Apple Developer Documentation*. https://developer.apple.com/documentation/uikit/uiviewcontroller/prefersinterfaceorientationlocked
27. *Invidious Instances - Invidious Documentation*. https://docs.invidious.io/instances/
28. *Selecting subtitles and alternative audio tracks | Apple Developer Documentation*. https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks
29. *Extractors · yt-dlp/yt-dlp Wiki · GitHub*. https://github.com/yt-dlp/yt-dlp/wiki/extractors
30. *Releases · yt-dlp/yt-dlp · GitHub*. https://github.com/yt-dlp/yt-dlp/releases
31. *Releases · iv-org/invidious · GitHub*. https://github.com/iv-org/invidious/releases
32. *API - Authenticated endpoints - Invidious Documentation*. https://docs.invidious.io/api/authenticated-endpoints/
33. *GitHub - TeamPiped/documentation*. https://github.com/TeamPiped/documentation
34. *FAQ · yt-dlp/yt-dlp Wiki · GitHub*. https://github.com/yt-dlp/yt-dlp/wiki/FAQ
35. *API - Invidious Documentation*. https://docs.invidious.io/api/
36. *GitHub - LuanRT/YouTube.js: A JavaScript client for YouTube's internal API, known as InnerTube. · GitHub*. https://github.com/LuanRT/YouTube.js
37. *Self-Hosting - Piped*. https://docs.piped.video/docs/self-hosting/
38. *Configuring your app for media playback | Apple Developer Documentation*. https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback
