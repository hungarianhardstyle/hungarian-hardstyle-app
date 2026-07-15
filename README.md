# Hungarian Hardstyle App

The official cross-platform application of **Hungarian Hardstyle**, built as a central hub for the Hungarian harder styles scene.

WordPress is the source of truth for editorial content. Flutter consumes the public REST API for news, events, DJs, organizers and future releases.

## Current status

The current delivery target is **v0.97**. The last released Flutter build is **0.95.0** (ARM test build `+25`); the version number will change when the v0.97 work is implemented.

The current WordPress backend package is **2.4.17**. It is deployed and tested; it includes the v0.9 push, newsletter, and event-label updates.

Backend **2.4.7** is deployed and awaiting live approval-flow testing. It fixes DJ/organizer approval redirects and adds one-click event draft creation from pending submissions; generated drafts remain non-visible until reviewed and published manually.

Backend **2.4.8** is deployed. It adds a separate optional DJ-logo upload, an editable DJ website field across WordPress, REST API, public profiles, and Flutter, and complete event details when an event is opened from a DJ or organizer profile. The profile-event navigation fix is live-verified; image-upload verification remains blocked by the upstream WAF.

Current external blocker: Websupport's upstream WAF returns HTTP 466 for multipart image uploads before WordPress/Wordfence receives them. Event flyer, DJ profile image and organizer logo submissions can be verified after the three REST endpoints are allowlisted. The dedicated Facebook Event URL field is deployed in backend 2.4.3; the app submission field remains a general event link.

Implemented:

- dark Material 3 Flutter UI with Riverpod and Dio
- API-backed news list, search and detail views
- rich news content, galleries, embeds and in-app link handling
- dynamic events with flyers, tickets, Maps and related profiles
- searchable DJ and organizer directories with full profile pages
- related upcoming events on DJ and organizer profiles
- moderated event, DJ and organizer submissions
- gallery/camera uploads for event flyers, DJ profile images and organizer logos
- WordPress admin approval into non-public draft profiles
- local favorites for news, events, DJs and organizers
- native Mailchimp newsletter signup
- Firebase/FCM push notifications for news and events, including foreground display

## Roadmap

### Current bug-fix backlog

- [x] make AdMob initialization failure-safe and platform-aware so it can never block app startup
- [x] add the iOS AdMob test application identifier; replace it with the production App ID before release
- [x] remove the remaining event-card overflow at 2.0x accessibility text scaling and add a small-screen regression test
- [x] prevent the favorites startup load from overwriting a newly saved favorite
- [x] make saved news, events and DJs openable from the Favorites screen
- [x] dispose late AdMob banner callbacks safely; consent/privacy handling remains required before production ads
- [x] replace the three deprecated `withOpacity()` calls
- [ ] restore artist/DJ logo rendering on both the Flutter app and public WordPress pages
- [ ] make newly published or edited DJ profiles refresh reliably in the app without forced refresh
- [ ] upgrade Gradle, Android Gradle Plugin and Kotlin before current Flutter support is dropped

### v0.4 — Foundation

- [x] Flutter application structure and dark brand UI
- [x] WordPress REST API foundation
- [x] API-backed news, search and detail screens
- [x] pull-to-refresh and basic loading/error handling
- [x] update the default widget test for `HungarianHardstyleApp`
- [ ] finish asset cleanup and launcher icon setup
- [ ] set the final Android application ID and release signing

### v0.5 — Dynamic events

- [x] API-backed event list and detail screen
- [x] flyer, ticket and Google Maps actions
- [x] clickable DJ and organizer relationships
- [x] public event submission form with server-managed genres
- [x] gallery/camera flyer upload
- [ ] complete an intentional live submission and approval test
- [ ] finish the public WordPress event detail experience

### v0.6 — DJ database

- [x] searchable DJ list
- [x] Hardstyle and Hardcore category filters
- [x] API-backed DJ profiles
- [x] profile image, biography, genres, location and social links
- [x] TikTok and upcoming events
- [x] moderated DJ submission with optional profile image
- [x] Hungarian Hardstyle-managed booking option
- [x] standardize every DJ list image to one card frame and aspect ratio with upper-center face-focused cover cropping
- [ ] complete an intentional live image submission and approval test

### v0.7 — Organizers

- [x] searchable organizer list
- [x] API-backed organizer profiles
- [x] logo, description, location, website and social links
- [x] related upcoming events
- [x] moderated organizer submission
- [x] gallery/camera logo upload in backend 2.4.2
- [x] standardize every organizer list image to the same fixed card frame; logos retain contain rendering inside the frame
- [ ] live-verify organizer logo upload and draft-profile approval
- [x] add optional multi-select music genres/styles (backend 2.4.9 prepared)

### v0.8 — Rich content

- [x] YouTube, Spotify, SoundCloud, Instagram and TikTok embeds
- [x] WordPress galleries and supported shortcode detection
- [x] shared in-app browser for normal content links
- [x] automatic linkification of plain-text web URLs
- [ ] add a private AI-assisted WordPress article importer
- [ ] add an AI-assisted English translation action to the standard WordPress blog post editor, producing a separately editable draft for human review
- [ ] extend the mobile APIs for news, events, DJs and organizers to serve stored English content by locale, with Hungarian fallback and no AI generation during public requests
- [ ] enforce draft-only import, attribution, safe URL fetching and media rights checks

### v0.9 — Community utilities (implemented)

- [x] local favorites for news, events, DJs and organizers
- [x] allow the featured news card on Home to be marked as a favorite
- [x] show the opened news title in the app-bar instead of the generic `Hír` label
- [x] show the opened event title in the app-bar instead of a generic event label
- [x] Mailchimp newsletter signup via hosted landing page
- [x] native Mailchimp newsletter signup screen with a WordPress server-side proxy (backend 2.4.15 live; personal e-mail double-opt-in test successful)
- [x] organizer favorites in profile screens and the local favorites list
- [x] notification and cache settings
- [x] social, contact and About sections
- [x] show runtime app version and build number from package metadata
- [x] prepare local push notification preferences
- [x] integrate the Firebase/FCM client and store the device token locally
- [x] open related WordPress articles (including “Kapcsolódó cikk”, “Kapcsolódó”, and “Ez is érdekelhet” links) in the native app news screen; backend 2.4.12 is live and the detail endpoint was verified with a real related article
- [x] rename the artist website label to `Website`
- [x] rename the artist booking action to `Booking` or `Fellépés lekötése`
- [x] add organizer genre/style selection in WordPress, API, and submission flow (backend 2.4.9 prepared)
- [x] configure and live-test WordPress-created custom push delivery; news and event publishing pushes plus foreground display are live-verified
- [x] implement one-week and event-day reminder scheduling in the backend
- [ ] monitor the first natural one-week and event-day reminder occurrences

Push setup: in Firebase Console open Project settings → Service accounts → Generate new private key, then upload the downloaded JSON under WordPress `HUHS Mobile → Push értesítések`. The JSON stays on the server; never commit or embed it in Flutter.

Push verification after uploading the WordPress package:

- choose a published news item or event by title in the custom-push form and send it; the app should open the native detail screen;
- paste a HUHS news/event URL as an individual link; the server resolves it to the native detail screen, while unrelated external URLs open in the in-app browser;
- [x] publish a new news item and a new visible event, then verify the automatic notifications;
- [ ] create a future event and monitor the one-week and event-day reminder jobs at their first natural occurrences.

### v0.95 — Media

- [x] Spotify playlist section with five curated Hungarian Hardstyle playlists (Spotify app first, browser fallback)
- [x] compress submission images on-device before upload (target: up to 1600 px, quality 82; native picker output)

### v0.97 — Polish build

Small, low-risk finishing work that can be released independently before the larger v1.0 modules:

- [ ] show uploaded/approved DJ logos in the Flutter DJ list and profile with a consistent fallback order (live upload verification remains WAF-blocked)
- [ ] standardize DJ and organizer list thumbnails with a fixed frame, cover crop and upper-center face focus
- [x] keep DJ names readable in the two-column cards; keep them on one line and scale long names down instead of truncating them
- [ ] rename the event ticket action in the app to `Jegyvásárlás`
- [ ] add the event map preview/fallback: Google Maps app when installed, otherwise Google Maps in the browser
- [ ] investigate the missed event-day reminder: WP-Cron, timezone/date parsing, preference filtering and the FCM send path

### v1.0 — First public release

Core release quality:

- [ ] stabilize news, events, DJs and organizers for public release
- [ ] complete a final UX and visual polish pass: navigation, spacing, labels, buttons, loading/error states, accessibility and tasteful motion/effects
- [ ] add the Hardstyle Revolution release catalog
- [ ] add release preview playback
- [ ] add Spotify, YouTube and Hardstyle.com links to releases
- [ ] add WordPress-managed release records with cover art, preview audio, downloadable file, and free/paid status
- [ ] add a dedicated `Kiadások` destination between Events and More in the app
- [ ] show configured Hardstyle.com, Beatport, Spotify and Apple Music links at the bottom of each release detail screen
- [ ] allow the own shop catalog to sell separately uploaded Radio Edit/Radio Version and Extended/full versions
- [ ] prepare the online-radio backend
- [ ] add background playback and audio-focus handling
- [ ] ship Hungarian/English Flutter UI localization
- [ ] ship reviewed English WordPress content and locale-aware mobile APIs for news, events, DJs and organizers, with Hungarian fallback
- [ ] add a compact online-radio player below the Home logo with explicit play/pause/stop, server-side AutoDJ rotation, Now Playing data and clear loading/offline/error states
- [x] add a purposeful Hungarian Hardstyle-branded loading animation without artificial startup delay, with reduced-motion support
- [ ] refine the Android startup animation to use the full HUHS logo on a transparent/no-white background
- [x] introduce a persistent navigation shell with per-tab history
- [ ] finalize the bottom-navigation priority and add the Live Feed tab
- [ ] polish the Android release and prepare iOS support
- [ ] add the WordPress-managed FAQ under More with search, expandable answers, loading, empty and error states

Authentication and community:

- [ ] Google sign-in and app-only community accounts
- [ ] let users choose an account role during onboarding: DJ, organizer, or attendee/partygoer
- [ ] show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce the same rules server-side
- [ ] bootstrap a separate app-admin account and role with full submission approval and editing permissions
- [ ] top-left Home avatar profile entry with profile image or monogram fallback
- [ ] user profiles with social links, planned events, and favorites
- [ ] allow a registered user to claim a DJ profile only after verifying the private or artist-owned booking e-mail stored on that profile; the Hungarian Hardstyle-managed booking address must never qualify as proof of ownership
- [ ] friend requests and an `Ismerősök` profile section
- [ ] Live Feed chat and image posts
- [ ] event attendance: `Ott leszek` / `Nem leszek ott`
- [ ] show which friends are attending on event details
- [ ] friend attendance visibility
- [ ] moderation, reporting, blocking, privacy and account deletion

App administration:

- [ ] provide an authenticated admin backend for the app so admins can review, approve, edit and manage event, DJ and organizer submissions without using the WordPress dashboard
- [ ] keep WordPress as the editorial source of truth and enforce admin permissions server-side

News, events, DJs and organizers should remain readable without registration. Event, DJ and organizer submission forms remain public until authentication launches. After that, only signed-in users may see and use them, and the backend must reject unauthenticated submissions.

Annual voting:

- [ ] WordPress-managed voting seasons and candidates
- [ ] best Hungarian hardstyle DJ
- [ ] best Hungarian hardcore DJ
- [ ] best Hungarian event series
- [ ] best Hungarian track
- [ ] best international DJ
- [ ] authenticated one-user/one-vote enforcement
- [ ] private admin dashboard and explicitly published public results

FAQ:

- [ ] WordPress-managed questions, categories and display order
- [ ] public read-only REST endpoint
- [ ] searchable, expandable Flutter FAQ under More
- [ ] loading, empty and error states

Online radio:

- [ ] configure a server-side AutoDJ for a managed library of X uploaded tracks
- [ ] prefer AzuraCast for Liquidsoap AutoDJ, Icecast-compatible streaming, playlist management and Now Playing data
- [ ] choose the provider during radio implementation
- [ ] support bulk media upload through SFTP; do not use unencrypted FTP
- [ ] use an officially supported S3-compatible provider or Dropbox for cloud storage instead of a custom Google Drive sync
- [ ] require an explicit user action before audible playback and always allow stopping it
- [ ] decide licensing, hosting, bandwidth, codec/bitrate, background playback, interruptions and notification controls

### v1.5 — Hardstyle Revolution Store

- [ ] free MP3 releases without payment or advertising
- [ ] rewarded-ad 128 kbps MP3 downloads for premium releases
- [ ] paid 320 kbps MP3 downloads
- [ ] paid WAV/lossless downloads
- [ ] process paid digital downloads through Google Play Billing (not direct Google Pay checkout)
- [ ] preview player
- [ ] upload one WAV master and generate 128 kbps MP3, 320 kbps MP3 and preview derivatives server-side with FFmpeg
- [ ] process conversions in a background job and keep the WAV master private
- [x] verify Websupport FFmpeg support (`/usr/bin/ffmpeg` 4.4.2 with `libmp3lame`); background-job execution still needs an end-to-end test
- [ ] optional purchase and download history

Releases and Store use one WordPress-managed catalog rather than separate content systems.

## Navigation direction

- Home and News remain the first two primary destinations.
- The unused Tickets tab will be removed; its future primary-tab slot is reserved for the v1.0 Live Feed/chat user hook.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action, gated by authentication once registration is available.
- Events are a strong primary-tab candidate because they provide immediate utility.
- DJs and organizers may initially remain under More.
- v1.0 adds a dedicated Live Feed tab.
- Detail screens should open inside one persistent navigation shell instead of duplicating the bottom bar.

## Language direction

- The Flutter interface may support Hungarian and English using generated ARB localization files.
- AI-assisted English article versions are created and reviewed in the standard WordPress post editor.
- The mobile REST APIs for news, events, DJs and organizers should serve the stored language requested by Flutter, with Hungarian fallback, rather than translating content on demand.

## Brands

- **Hungarian Hardstyle** — main community platform
- **Hardstyle Revolution** — record label and event series
- **Rave Revolution** — multi-genre hard dance event series
- **Hard Lake** — free summer event concept around Lake Velence

## Long-term vision

One connected platform for Android, iOS and the web, combining news, events, artists, organizers, community, radio, releases and digital music distribution.
