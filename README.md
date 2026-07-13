# Hungarian Hardstyle App

The official cross-platform application of **Hungarian Hardstyle**, built as a central hub for the Hungarian harder styles scene.

WordPress is the source of truth for editorial content. Flutter consumes the public REST API for news, events, DJs, organizers and future releases.

## Current status

The app version remains **v0.4** while the first public release scope is being completed. Several later roadmap modules are already functional.

The current WordPress backend package is **2.4.3**. It is deployed and tested; it adds the dedicated Facebook Event URL field to WordPress events and the mobile API.

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

## Roadmap

### Current bug-fix backlog

- [x] make AdMob initialization failure-safe and platform-aware so it can never block app startup
- [x] add the iOS AdMob test application identifier; replace it with the production App ID before release
- [x] remove the remaining event-card overflow at 2.0x accessibility text scaling and add a small-screen regression test
- [x] prevent the favorites startup load from overwriting a newly saved favorite
- [x] make saved news, events and DJs openable from the Favorites screen
- [x] dispose late AdMob banner callbacks safely; consent/privacy handling remains required before production ads
- [x] replace the three deprecated `withOpacity()` calls
- [ ] upgrade Gradle, Android Gradle Plugin and Kotlin before current Flutter support is dropped

### v0.4 — Foundation

- [x] Flutter application structure and dark brand UI
- [x] WordPress REST API foundation
- [x] API-backed news, search and detail screens
- [x] pull-to-refresh and basic loading/error handling
- [ ] update the default widget test for `HungarianHardstyleApp`
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
- [ ] standardize every DJ list image to one card frame and aspect ratio with upper-center face-focused cover cropping
- [ ] complete an intentional live image submission and approval test

### v0.7 — Organizers

- [x] searchable organizer list
- [x] API-backed organizer profiles
- [x] logo, description, location, website and social links
- [x] related upcoming events
- [x] moderated organizer submission
- [x] gallery/camera logo upload in backend 2.4.2
- [ ] standardize every organizer list image to the same card frame and aspect ratio with upper-center portrait focus
- [ ] live-verify organizer logo upload and draft-profile approval
- [ ] add optional multi-select music genres/styles later

### v0.8 — Rich content

- [x] YouTube, Spotify, SoundCloud, Instagram and TikTok embeds
- [x] WordPress galleries and supported shortcode detection
- [x] shared in-app browser for normal content links
- [x] automatic linkification of plain-text web URLs
- [ ] add a private AI-assisted WordPress article importer
- [ ] add an AI-assisted English translation action to the standard WordPress blog post editor, producing a separately editable draft for human review
- [ ] extend the mobile APIs for news, events, DJs and organizers to serve stored English content by locale, with Hungarian fallback and no AI generation during public requests
- [ ] enforce draft-only import, attribution, safe URL fetching and media rights checks

### v0.9 — Community utilities

- [x] local favorites for news, events and DJs
- [ ] Mailchimp newsletter integration
- [x] notification and cache settings
- [x] social, contact and About sections
- [x] show runtime app version and build number from package metadata
- [ ] prepare push notifications
- [ ] notify on new news/events, event reminders at 7 days and on the event day, and support WordPress-created custom push messages

### v0.95 — Media

- [ ] prepare the online-radio backend and background playback
- [ ] Hardstyle Revolution release catalog
- [ ] preview player
- [ ] Spotify, YouTube and Hardstyle.com links
- [x] Spotify playlist section with five curated Hungarian Hardstyle playlists (Spotify app first, browser fallback)

### v1.0 — First public release

Core release quality:

- [ ] stabilize news, events, DJs and organizers for public release
- [ ] ship Hungarian/English Flutter UI localization
- [ ] ship reviewed English WordPress content and locale-aware mobile APIs for news, events, DJs and organizers, with Hungarian fallback
- [ ] add a compact online-radio player below the Home logo with explicit play/pause/stop, server-side AutoDJ rotation, Now Playing data and clear loading/offline/error states
- [x] add a purposeful Hungarian Hardstyle-branded loading animation without artificial startup delay, with reduced-motion support
- [ ] introduce a persistent navigation shell with per-tab history
- [ ] finalize the bottom-navigation priority and add the Live Feed tab
- [ ] polish the Android release and prepare iOS support

Authentication and community:

- [ ] Google sign-in and app-only community accounts
- [ ] user profiles and friend connections
- [ ] Live Feed chat and image posts
- [ ] event attendance: `Ott leszek` / `Nem leszek ott`
- [ ] friend attendance visibility
- [ ] moderation, reporting, blocking, privacy and account deletion

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
- [ ] choose the provider during radio implementation; start with a managed AzuraCast hosting plan for the simplest launch, then move to a suitably sized self-managed VPS only when usage or control requirements justify it
- [ ] support bulk media upload through SFTP; do not use unencrypted FTP
- [ ] use an officially supported S3-compatible provider or Dropbox for cloud storage instead of a custom Google Drive sync
- [ ] require an explicit user action before audible playback and always allow stopping it
- [ ] decide licensing, hosting, bandwidth, codec/bitrate, background playback, interruptions and notification controls

### v1.5 — Hardstyle Revolution Store

- [ ] free MP3 releases without payment or advertising
- [ ] rewarded-ad 128 kbps MP3 downloads for premium releases
- [ ] paid 320 kbps MP3 downloads
- [ ] paid WAV/lossless downloads
- [ ] preview player
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
