# Hungarian Hardstyle App - Project Context for AI Agents

This file is the project memory for Codex and other AI coding agents working on the Hungarian Hardstyle app. Keep it up to date when architectural decisions, roadmap priorities, API contracts, or brand rules change.

## Project Summary

Hungarian Hardstyle is a cross-platform mobile app and web-connected platform for the Hungarian harder styles community.

The long-term goal is to create a central hub for:

- news
- events
- DJs and artists
- organizers
- releases
- online radio
- community features
- digital music distribution

The mobile app is built with Flutter. WordPress is the backend and the single source of truth.

## Main Brands

### Hungarian Hardstyle

The main brand, community platform, website, and app identity. Hungarian Hardstyle is the umbrella brand that contains the news, app, community, and related sub-brands.

### Hardstyle Revolution

An important sub-brand under Hungarian Hardstyle.

Hardstyle Revolution can represent:

- a record label
- an event series
- its own Facebook page
- its own Instagram page
- releases inside the app
- future store/catalog features

### Rave Revolution

A newer multi-genre hard dance event series. It can include hardstyle, rawstyle, hardcore, hard techno, and other harder electronic styles.

### Hard Lake

A summer/free/flashmob-style event concept, usually connected to Lake Velence.

In the app, these sub-brands can later appear in a "Brands" or "Our Brands" area under the More section, each with logo, short description, and social links.

## Core Product Direction

This is not intended to become a generic music app. It should feel like a platform built specifically around the Hungarian hard dance scene.

The app should prioritize:

- a strong dark visual identity
- fast access to fresh news
- dynamic events
- clear artist and organizer discovery
- future media and release features
- a community feeling without requiring registration at first

## Data Source Rule

WordPress is the only source of truth.

Do not create separate hardcoded databases in Flutter for real app content. Temporary placeholder content is allowed only while a feature is being built.

Expected data flow:

1. WordPress admin creates or edits content.
2. WordPress exposes that content through REST API endpoints.
3. Flutter fetches and renders the API data.
4. Later, public web detail pages can use the same WordPress content.

## Current State

As of the current project state:

- Flutter app structure exists.
- Dark UI exists.
- Home screen and bottom navigation exist.
- News API integration works in the Flutter app.
- News list works with API-backed content.
- News search UI exists.
- News item tap/click opens the news detail view.
- News cards display remote images, title, date, and featured state.
- The WordPress API plugin ZIP has been reviewed locally from `huhs-mobile-api.zip`.
- The WordPress plugin version in that ZIP is `2.1.0`.
- Backend package `2.3.0` is deployed and confirmed working. It includes organizer list/detail REST endpoints, organizer search, logo/social data, and organizer upcoming-event relations.
- Backend package `2.4.0` is deployed and live-verified. It adds moderated DJ and organizer submissions, a one-click admin approval flow that creates non-public draft profiles, and DJ booking fields including the optional Hungarian Hardstyle-managed booking route.
- Backend package `2.4.1` is deployed. It adds multipart image upload for event flyers and DJ profile images. Files are limited to 5 MB and JPG/PNG/WebP, stored in the WordPress Media Library, attached to the pending submission, and never auto-published.
- Backend package `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow.
- Backend package `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend package `2.4.7` is deployed. It fixes the invalid nested admin approval form that prevented DJ and organizer draft creation, removes the misleading native publish box from submissions, and adds the same one-click draft creation flow for event submissions. The approval flow still requires a live WordPress admin test.
- Backend package `2.4.8` is deployed. It adds an optional separate DJ-logo multipart upload, transfers the approved logo to the DJ draft, adds an artist website field to the WordPress editor, artist API, public profile, Flutter DJ submission, and Flutter DJ profile links, and returns complete event records from DJ/organizer profiles so their event cards open the full event detail. The latter was verified live; direct multipart uploads are bypassed by Cloudinary in v0.99.
- Backend package `2.4.12` is deployed and live-verified. It exposes published IRP related-post records and a public post-detail endpoint; a real “Kapcsolódó cikk” target was verified. Flutter opens returned related articles plus normal WordPress “Kapcsolódó cikk”, “Kapcsolódó”, and “Ez is érdekelhet” links in the native news detail screen and falls back to the in-app browser when IDs are unavailable.
- Backend package `2.4.29` is prepared locally. It includes the `2.4.28` features plus push-title/body HTML-entity decoding and UTF-8 JSON output; deployment and live verification are still pending.
- Backend package `2.4.16` also contains the FCM HTTP v1 sender: mobile token registration, news/event/link targets, automatic HUHS URL resolution, foreground display support, per-device notification preferences, publish-time news/event pushes, scheduled event reminders, and an admin custom-push form. Custom push and news/event publishing pushes are live-tested; the first natural event-day reminder did not arrive and the cron/timezone/filter path needs investigation.
- The custom-push admin form lists recent published news and events by title and validates the selected post type, so editors do not need to look up event IDs manually.
- Backend package `2.4.15` adds the server-side Mailchimp newsletter subscription endpoint and protected admin settings page; the endpoint is live and both invalid-email validation and a real personal e-mail double-opt-in test succeeded. Flutter includes a native signup screen with consent and double opt-in messaging.
- Backend package `2.4.9` is prepared for deployment. It adds organizer genre/style metadata, WordPress editor controls, API output, and genre validation/storage for organizer submissions. Flutter now displays organizer genres and includes them in organizer submissions.
- Websupport's upstream WAF still returns HTTP 466 for direct multipart image uploads, but Cloudinary is the active v0.99 upload path. Websupport allowlisting is deferred until after v1.0 and is not a current release blocker.
- DJ logos are rendered in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- DJ/organizer list providers now use auto-dispose so newly published or edited profiles refresh after navigation.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/posts`.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/events`.
- Backend package `2.2.0` is deployed. Its artist list/category endpoints, shared submission genre options, validation response, and public DJ/event archive templates were verified live. A successful real submission still needs an intentional end-to-end app test because it creates a pending WordPress item.
- Events, tickets, and more may still contain placeholder or early-stage UI.
- Dynamic events and the event detail screen are connected to the WordPress events API.
- Event detail artists and organizer are clickable. Artist links open complete API-backed DJ profiles. Organizer links are now connected to the organizer detail provider and require backend `2.3.0` in production.
- News excerpts are converted to plain text and HTML tags are removed for both custom and standard WordPress responses.
- News search uses the custom `huhs/v1/posts` endpoint so search results retain the same processed content, featured images, galleries, and embeds as the normal news flow.
- News detail renders deduplicated YouTube, Spotify, SoundCloud, Instagram, and TikTok embeds in-app. Supported interactive WordPress shortcodes (`ays_poll`, `irp`, and legacy Final Tiles Gallery) are detected; their raw shortcode text is removed and the rendered WordPress content can be opened inside the app.
- Plain-text web URLs in news and event HTML are automatically converted into tappable links. Normal article, event, ticket, and shortcode links use the shared in-app browser; native media and Maps handoff remain intentional exceptions.
- WordPress API work exists and should continue to be the backend source for new dynamic features.
- Flutter-side WordPress integration is complete for news, but not yet complete for every content type.

Do not assume that an empty or partial integration file is a bug by itself. Treat it as an implementation placeholder unless it blocks the requested feature or conflicts with a known working module.

## Flutter Stack

The Flutter app uses or is expected to use:

- Flutter
- Material 3
- dark theme
- Riverpod for state management
- Dio for HTTP requests
- cached_network_image for remote images
- intl for date formatting
- go_router when route-based navigation becomes necessary

Prefer existing dependencies before adding new ones.

## Flutter Conventions

Use the existing folder structure:

- `lib/main.dart`
- `lib/core/theme/`
- `lib/models/`
- `lib/providers/`
- `lib/services/`
- `lib/screens/`

Preferred feature pattern:

- model in `lib/models/`
- API/service code in `lib/services/`
- Riverpod provider in `lib/providers/`
- screen UI in `lib/screens/<feature>/`

For API-backed screens, include:

- loading state
- empty state
- error state
- pull-to-refresh when useful

Keep UI dark and brand-forward. Use red accents carefully and consistently.

## WordPress Conventions

WordPress should manage the content. Flutter should consume REST API responses.

Expected WordPress content areas:

- news/posts
- events
- artists/DJs
- organizers
- releases
- future store items

Expected event metadata:

- title
- date
- location
- Google Maps URL
- ticket URL
- flyer image
- related artists
- related organizer
- featured flag
- visible-in-app flag

When implementing WordPress save logic, always verify nonce, permissions, autosave behavior, and sanitize fields before saving metadata.

## API Direction

Known current custom API endpoints:

- `GET /wp-json/huhs/v1/posts`
- `GET /wp-json/huhs/v1/events`
- `GET /wp-json/huhs/v1/artists` (deployed and verified in backend `2.2.0`)
- `GET /wp-json/huhs/v1/artists/{id}` (deployed and verified with live DJ data)
- `GET /wp-json/huhs/v1/event-submission-options` (deployed and verified; returns the shared DJ/event genre list)
- `POST /wp-json/huhs/v1/event-submissions` (deployed; required-field validation verified, successful pending-item creation awaits intentional app testing)
- `GET /wp-json/huhs/v1/organizers` (deployed and live-verified in backend `2.3.0`)
- `GET /wp-json/huhs/v1/organizers/{id}` (deployed and live-verified with upcoming events in backend `2.3.0`)
- `GET /wp-json/huhs/v1/profile-submission-options` (deployed and live-verified in backend `2.4.0`; shared genres and DJ categories)
- `POST /wp-json/huhs/v1/artist-submissions` (route live-verified in backend `2.4.0`; creates a pending submission only)
- `POST /wp-json/huhs/v1/organizer-submissions` (route live-verified in backend `2.4.0`; creates a pending submission only)

Current posts response fields:

- `id`
- `title`
- `date`
- `excerpt`
- `content`
- `featured_image`
- `link`
- `gallery_id`
- `gallery_images`
- `embeds`

Current events response fields:

- `id`
- `title`
- `description`
- `start_date`
- `start_time`
- `end_date`
- `end_time`
- `venue_name`
- `venue_city`
- `venue_zip`
- `venue_address`
- `venue_country`
- `google_maps`
- `ticket_type`
- `ticket_url`
- `facebook_event_url` (separate Facebook Event link on event records and mobile API; backend 2.4.3)
- `organizer`
- `artists`
- `flyer`
- `featured`
- `visible`
- `status`

The events API currently returns only published `huhs_event` posts where `visible` is truthy. It sorts featured events first, then by `start_date`.

Artist and organizer custom post types and their list/detail mobile APIs are deployed and verified. Only profiles with `Publikálás az alkalmazásban` (`visible`) enabled appear in their mobile APIs, although published artists may still appear on the public WordPress `/djs/` archive.

The artist list endpoint supports `page`, `per_page`, `search`, and `category` parameters. Artist responses include biography, excerpt, images, genres, Hardstyle/Hardcore category objects, location, social links including TikTok, flags, public link, and detail-only `upcoming_events`.

WordPress artist management includes the hierarchical `huhs_artist_category` taxonomy. The default categories are `Hardstyle` and `Hardcore`, and an artist may belong to either or both. The `[huhs_djs]` shortcode renders a responsive, category-grouped DJ directory linking to public profiles. `[huhs_djs category="hardstyle"]` and `[huhs_djs category="hardcore"]` render a single category.

The `[huhs_events]` shortcode renders the complete responsive upcoming-event directory with flyer, date/time, venue, description, detail link, ticket link, and featured state. Use `[huhs_events include_past="true"]` only when a page intentionally needs past events too.

Backend `2.2.0` also overrides the public `huhs_artist` and `huhs_event` archive templates so `/djs/` and `/events/` automatically render the same polished collection views without requiring manually created WordPress pages.

For artists, `hero_image` is the stored legacy meta key but its product/admin name is `Profilkép`. Use the API `profile_image` field for new Flutter code. `hero_image` remains in responses temporarily for backward compatibility. DJ list cards must prefer `profile_image`; the logo is only a fallback.

DJ profile images use `cover` cropping with an upper-center portrait focus (approximately 50% horizontal / 25% vertical on web, matching upper-center alignment in Flutter) so faces remain visible across mixed source image dimensions.

DJ and organizer list cards must use a consistent image frame size and aspect ratio across every item. Use `cover` cropping with an upper-center focal alignment so portrait faces remain visible; organizer logos or non-portrait artwork should still fill the same standardized frame without changing card dimensions.

The WordPress `HUHS Mobile > Shortcode-ok` admin page is the canonical in-dashboard shortcode reference. It lists every supported DJ/event shortcode, parameters, descriptions, and copy buttons; keep it updated whenever a shortcode is added or changed.

Event submissions from Flutter require title, date, venue, at least one server-approved genre, and contact e-mail. Optional fields are start time, city, organizer name, event URL, and description. Submissions must remain `pending`; they must never become published events automatically.

With backend `2.4.1`, event submissions may include an uploaded flyer selected from the device gallery or camera. The admin submission screen previews the uploaded image and links to its Media Library attachment. Backend `2.4.8` also accepts a separate optional `logo` image alongside the DJ profile `image`, with the same 5 MB and JPG/PNG/WebP validation.

DJ, organizer, and event submissions from Flutter remain pending until editorial review. Backend `2.4.7` adds a nonce-protected WordPress approval action that creates the matching draft DJ/organizer/event with `visible` disabled; publishing and app visibility remain separate manual decisions. Submitted profile/logo images are supplied as reviewable URLs and are not automatically imported into the Media Library.

DJ profiles support a public booking e-mail and a `booking_via_huhs` option. When enabled, both the public website and Flutter must show `info@hungarianhardstyle.hu` as the booking address and explain that the performance can be arranged through Hungarian Hardstyle. The private submission contact e-mail must never be exposed on the public profile.

Artist/DJ and organizer profile APIs should include related events:

- Artist/DJ profiles should show events where the artist performs.
- Organizer profiles should show events organized by that organizer.
- These can be derived from event relationships: `artists` contains artist IDs and `organizer_id` contains the organizer ID.
- Prefer returning an `upcoming_events` array in artist and organizer detail responses.

Artist/DJ profiles should include a TikTok field when the DJ API is implemented. Organizer already has a `tiktok` meta field in the reviewed plugin ZIP.

The API should support:

- news list, currently working in Flutter
- news detail, currently working in Flutter
- event list, endpoint exists in WordPress
- event detail, can initially use the event object from the list or a future detail endpoint
- artists list, deployed and verified with live data
- artist detail, deployed and verified with live data
- organizers list, deployed and live-verified in backend `2.3.0`
- organizer detail with upcoming events, deployed and live-verified in backend `2.3.0`
- future release catalog

Flutter should not rely on WordPress admin-only fields or HTML that is hard to render on mobile unless rich content support is explicitly being implemented.

Prefer API responses that are easy for Flutter to parse:

- plain strings for titles
- ISO dates or clear date strings
- direct image URLs
- arrays for related artists/organizers
- booleans for flags
- explicit nullable fields

## Roadmap

### v0.99.1 implementation note

The current Flutter branch contains the Community MVP implementation: Firebase Auth registration/sign-in with mandatory DJ/organizer/partygoer roles, public Firestore Chat, anonymous text-only posts, registered Cloudinary image posts, profile entry/editing with monogram fallback, fixed reactions, a five-item Home news slider rotating every 10 seconds, and native article-tag filtering. Firestore deployment files are `firestore.rules`, `firebase.json`, and `.firebaserc`; rules are deployed to the named `hungarian-hardstyle` database and physical ARM verification is complete for `v0.99.1+10`. The authorization follow-up is now `v0.99.1+12`. The composer uses a responsive layout. Google sign-in provider and Android SHA configuration are present in the checked-in Firebase Android configuration; release-device verification remains a final external check. The HUHS posts endpoint does not currently expose tag names, so Flutter hydrates them from the WordPress core posts endpoint when necessary.

Historical v0.99.1 follow-up reports are addressed in the current bugfix build. Registration offers both e-mail/password and Google-account sign-in, with the account role selected during onboarding.
Chat message deletion and the in-app role-management panel are implemented; actual Firebase Auth account deletion for another user is handled by the deployed server-side Cloud Function/Admin SDK task.
The Cloud Function source is in `functions/` (`deleteCommunityUser`) and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
Also record for the next fix pass: push notification text has an encoding bug and may show Hungarian punctuation/accents as HTML entities (for example `&#8211;`) instead of decoded characters.
Community authorization is now separated: `djdeeroy@gmail.com` is an Admin with the account role Szervező; normal users cannot change account roles after onboarding; admins manage account/access roles; moderators can delete Chat messages only.

The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Manual focal-point editing remains optional later UX polish.
v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds moderator Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys the Firestore rules to the named database used by the app. Google sign-in remains a release-device/Firebase SHA verification check; manual focal-point editing is optional later UX polish.
Next build follow-up: collect separate Facebook, Instagram, TikTok, YouTube, and Spotify fields during registration and in the community profile.

### v0.4 - Foundation

Focus:

- base Flutter app
- dark UI
- WordPress backend foundations
- REST API foundation
- temporary/static screens where needed

### v0.5 - Dynamic Events

Focus:

- dynamic events in Flutter
- event detail screen
- flyer support
- ticket button
- Google Maps button
- WordPress event detail frontend

Flutter status: dynamic list, detail, flyer, ticket, Google Maps, and clickable artist/organizer relations are implemented. Both relations open real API-backed profile screens.

The Events screen includes an `Esemény beküldése` action and a validated submission form with multi-select genres loaded from WordPress. It requires backend `2.2.0` or newer to work against production.

### v0.6 - DJ Database

Focus:

- DJs menu
- DJ list
- DJ profile
- genres
- biography
- social links
- TikTok link
- upcoming events
- separate Hardstyle and Hardcore DJ categories, assignable in WordPress and filterable through the REST API
- reusable WordPress DJ directory with linked profile cards, using the `[huhs_djs]` shortcode

Flutter status: the DJ list and detail module is implemented under More and confirmed working with live data, including API search, Hardstyle/Hardcore filters, portrait-focused profile images, biography HTML, genres/categories, location, social links, and upcoming events. Event-detail artist taps use the real DJ detail provider.

The app includes a moderated `DJ beküldése` form, device image selection for the profile picture, and a `Fellépésszervezés a Hungarian Hardstyle-on keresztül` switch. Backend `2.4.1` is required for uploaded images. On approval, the submitted DJ image becomes the draft profile's `hero_image` and featured image.

### v0.7 - Organizers

Focus:

- organizers menu
- organizer list
- organizer profile
- social links
- description
- upcoming events
- organizer music genres/styles, editable in WordPress and exposed through the REST API

Flutter status: organizer search/list and full detail screens are implemented under More and confirmed against live API data, including logo, description HTML, location, genres, website/social links, and upcoming events. Event-detail organizer taps use the real organizer detail provider.

The app includes a moderated `Szervező beküldése` form. Its backend `2.4.0` route is deployed and live-verified; a successful real submission still requires an intentional app test because it creates a pending WordPress item.

### v0.8 - Rich Content

Focus:

- WordPress shortcode/rich content support
- YouTube embeds
- Spotify embeds
- TikTok embeds
- Instagram embeds
- galleries
- external link handling
- admin-only AI-assisted article importer in WordPress: accept a public source URL, extract usable article content, create Hungarian copy, and preserve supported inline media
- add an AI-assisted English translation action directly to the standard WordPress blog post editor; it should create or update a separately editable English draft/version for human review, never translate on demand in Flutter or auto-publish
- extend the mobile REST APIs for posts, events, DJs/artists, and organizers to return stored, reviewed English content when requested by the Flutter locale, with Hungarian fallback when an English field or version is unavailable; do not invoke AI during a public API request
- imported content must always be created as a draft for human review; never auto-publish AI output
- support two explicit modes: faithful translation for owned/licensed/partner content, and an original Hungarian summary/adaptation with source attribution for third-party reporting
- import images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image and do not hotlink or copy third-party assets automatically
- store the original source URL and attribution with the draft, keep the AI provider key server-side, and protect the fetcher against private/internal URLs, oversized responses, unsafe HTML, and timeouts

### v0.9 - Community (implemented)

Focus:

- local favorites
- allow the featured news card on Home to be marked as a favorite
- show the opened news article's title in its app-bar instead of the generic `Hír` label
- show the opened event's title in its app-bar instead of a generic event label
- newsletter integration
- settings
- social links
- contact/about pages
- open related articles inside the app instead of sending users to the public website browser page
- capitalize the artist social-link label as `Website`
- rename the artist booking action from `Fellépés kérése` to `Booking` or `Fellépés lekötése`
- add the same server-managed genre/style selector to organizer profiles and organizer submissions
- push notification preparation
- Push notification requirements: notify for newly published news and events, send event reminders one week before and on the event day, and later allow admins to create/send custom push notifications from the WordPress Mobile API admin area.
- About/app information screen with runtime version and build number, developer/maintainer credit, website, contact, privacy policy, and terms links

### v0.95 - Media

Focus:

- five curated Spotify playlists in a dedicated app section, opened through the shared in-app browser
- client-side image compression before cloud upload (target 1200–1600 px width, JPEG/WebP) to reduce storage and bandwidth use

### v0.97 - Polish build (complete)

Keep this release intentionally small and low-risk:

- fix rendering of uploaded/approved DJ logos in the Flutter DJ list and profile, preserving the profile-image fallback order
- standardize DJ and organizer list thumbnails with a fixed frame, cover crop, and upper-center portrait focus
- deploy backend 2.4.20 with `Happy Hardcore` in the shared DJ, event, and organizer genre options
- keep DJ names readable in two-column cards; keep them on one line and scale long names down instead of truncating them (implemented in Flutter)
- [x] rename the event ticket action to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- verify the one-week and six-hour reminders; the one-day reminder is live-verified with a five-minute WP-Cron delay

### v0.99 - Submission polish

- make event submission date, venue name, city, and address required in Flutter and WordPress validation
- add the required event address field directly below the venue name
- add event end date and end time fields and reject an end before the start
- load organizers from WordPress for an app dropdown and keep the WordPress organizer selector aligned
- require at least one genre and show inline validation text and red invalid-field styling for every missing required value
- replace blocked multipart image submission with direct Cloudinary upload (`fjxo93em` / unsigned `Hun_hs_Mobile`) and send the returned URL to WordPress for DJ, organizer, and event submissions

### v0.99.1 - Community MVP (implemented; Firebase deployment live)

- App-only registration/sign-in with e-mail/password and Google; account role is mandatory (`DJ`, `organizer`, or `partygoer`).
- Home top-left avatar opens the user's profile, showing profile image or monogram, name, bio, social links, favorites, and planned events.
- Live Feed is readable without registration. Anonymous users may publish text only under a generated `Unknown User ####` name and cannot upload images.
- Registered users may publish text and compressed snapshot images in the Live Feed.
- Live Feed messages support normal Unicode emoji and a small fixed reaction set; do not add a heavy emoji package unless the native keyboard proves insufficient.
- Use Firebase Authentication and Firestore for community data, and Cloudinary for community images; do not route these uploads through the blocked Websupport multipart endpoint.
- Keep full moderation, friendships, attendance visibility, profile claims, and app-admin tooling in v1.0.

### v1.0 - First Public Release (later)

Focus:

- stable news
- stable events
- event details
- DJ directory
- organizer directory
- clickable genre chips with a grouped discovery screen for events, DJs, and news
- a More-section `Támogatás / Donate` card using a configurable PayPal donation link, with native-app-first and browser fallback opening
- Hardstyle Revolution release catalog
- release preview player
- Spotify/Hardstyle.com/YouTube links for releases
- WordPress-managed release records with cover art, preview audio, downloadable file, and free/paid status
- a dedicated `Kiadások` app destination between Events and More
- Hardstyle.com is an external destination only; do not scrape or import its catalog
- show configured Hardstyle.com, Beatport, Spotify and Apple Music links at the bottom of each release detail screen
- the own shop catalog may contain both Radio Edit/Radio Version and Extended/full versions when they are intentionally uploaded as separate products
- online-radio backend
- background playback and audio-focus handling
- final UX and visual polish pass across navigation, spacing, labels, buttons, loading/error states, accessibility, and tasteful motion/effects before release
- basic community features
- Hungarian/English Flutter UI localization plus reviewed English WordPress content for posts, events, DJs/artists, and organizers, served through locale-aware mobile APIs with Hungarian fallback
- an online radio mini-player directly below the logo on Home, backed by a server-side AutoDJ that rotates a configurable library of X uploaded tracks and can always be stopped by the user
- a purposeful Hungarian Hardstyle-branded loading animation that does not delay startup and respects reduced-motion accessibility settings
- refine the Android startup animation with the full HUHS logo on a transparent/no-white background
- polished Android release
- iOS preparation if ready
- WordPress-managed FAQ section in the app, initially under More

FAQ requirements for v1.0:

- questions and answers are editable in WordPress and exposed through a public read-only REST endpoint
- support categories and an explicit display order
- Flutter shows a searchable, expandable FAQ list with loading, empty, and error states
- do not hardcode production FAQ content in Flutter

Online radio requirements for v1.0:

- place a compact player directly below the Hungarian Hardstyle logo on Home
- use a server-side AutoDJ to rotate a configurable library of X tracks; do not bundle or sequence the production music library in Flutter
- require an explicit user action before audible playback and always provide play/pause/stop
- include loading, offline, and stream-error states, plus current-track metadata when available
- prefer AzuraCast as the simplest operations layer: Liquidsoap AutoDJ, Icecast-compatible streaming, playlist/media management, and Now Playing API
- defer the hosting-provider decision until radio implementation; prefer a managed AzuraCast plan for launch and move to a suitably sized self-managed VPS only when real usage or control requirements justify the operational work
- allow bulk upload through AzuraCast's built-in SFTP server; do not use unencrypted FTP
- for cloud media storage, prefer an officially supported S3-compatible provider or Dropbox; do not depend on an unofficial Google Drive mount/sync for production playback
- define music licensing, hosting, bandwidth, stream codec/bitrate, background playback, audio focus, interruptions, and media-notification controls before implementation

Confirmed v1.0 community direction:

- Add a dedicated Live Feed bottom-navigation tab.
- Registered users can chat in the live feed and publish image posts.
- Live Feed/chat image posts should reuse the direct Cloudinary upload path instead of Websupport multipart uploads.
- Add Google account sign-in and user registration/onboarding.
- Users can create and manage their own community profile. Once registration exists, make the profile reachable from the top-left of Home through a circular avatar; show the profile image or a monogram fallback.
- During onboarding, users can choose an account role: DJ, organizer, or attendee/partygoer. Role changes and privileged actions require server-side authorization.
- DJ submission is visible to DJ accounts, organizer submission to organizer accounts, and both submission flows to admins; Flutter visibility is not sufficient without matching API enforcement.
- v1.0 requires a separate app-admin role/account with full review, approval, and editing access for submissions. The owner admin e-mail is configured privately during deployment and must not be hardcoded into public app content.
- Registered users can claim a DJ profile only after proving control of the private or artist-owned booking e-mail stored on that profile. The Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) is never valid claim proof.
- Users can add social-media links to their profile, see the events they plan to attend, and access favorites from the profile area.
- Users can send, accept, and manage friend connections; each profile should include an `Ismerősök` list.
- Events must include `Ott leszek` and `Nem leszek ott` attendance actions.
- Event details should include an embedded map preview where platform/API constraints allow it. The fallback should open the Google Maps app when installed and otherwise open Google Maps in the browser.
- When viewing an event, show which friends are attending it.
- User profiles and friend lists should indicate whether that person plans to attend an upcoming event.
- News, events, DJs, organizers, and the Live Feed should remain readable without registration where possible. Anonymous Live Feed text posts are allowed under a generated `Unknown User ####` name, but anonymous users cannot upload images; profiles, friendships, and attendance state require authentication.
- Before implementation, define moderation, reporting, blocking, privacy, image upload/storage, retention, and account deletion rules.
- Registration and community accounts are app-only; do not add account registration or community UI to the public WordPress website.
- Provide an authenticated app-admin backend for reviewing, approving, editing, and managing event, DJ, and organizer submissions. Keep WordPress as the editorial source of truth and enforce admin permissions server-side.
- WordPress remains the source of truth for editorial content (news, events, DJs, organizers, and releases), while the app community backend may be a deliberately separate service optimized for authentication, real-time chat/feed data, friendships, attendance, and user uploads.
- Once app registration is available, DJ, organizer, and event submission actions and forms must be visible only to authenticated users. The submission API must also enforce authentication server-side; hiding the forms in Flutter is not sufficient.

Confirmed annual voting direction for v1.0:

- Replace or complement the current WordPress voting extension with a dedicated Hungarian Hardstyle voting module and REST API.
- WordPress admin must manage each annual voting season, its opening/closing dates, status, rules, and candidates.
- Required annual categories are:
  - `Legjobb magyar hardstyle DJ – <év>`
  - `Legjobb magyar hardcore DJ – <év>`
  - `Legjobb magyar bulisorozat – <év>`
  - `Legjobb magyar zene – <év>`
  - `Legjobb külföldi DJ – <év>`
- Derive the displayed year from the voting season instead of requiring it to be typed into every category name.
- Admins must be able to add DJ, event-series, and track candidates, including the display data needed by the app (name/title, artist, image/cover/logo, optional preview and external links).
- Flutter must list active voting categories and candidates and allow votes to be submitted in-app.
- Voting should use authenticated app users when Google sign-in is available, with server-side one-user/one-vote enforcement per category unless a season explicitly defines different rules.
- The API must enforce voting windows and duplicate-vote protection server-side; Flutter validation alone is not sufficient.
- Define result visibility (`live`, `hidden until close`, or `admin only`), vote correction rules, audit data, abuse protection, and privacy before launch.
- Provide a complete private admin summary/dashboard with totals and per-category results. It must never be exposed by a public REST endpoint or displayed to normal app users.
- After a voting season closes, admins must be able to publish a separate public results summary for the app.
- Publishing results must be an explicit admin action; closing voting must not automatically expose results.
- The public summary should contain the season/year, category names, final ranking, candidate display data, and optionally vote totals or percentages according to the season settings.
- Never include voter identities, audit logs, moderation flags, suspicious-vote indicators, or other private admin data in the public results response.

### v1.5 - Hardstyle Revolution Store

Focus:

- free releases
- premium releases
- rewarded-ad download option
- paid downloads
- Android digital purchases must use Google Play Billing; Google Pay is not the correct in-app product API
- purchase/download history if needed

## Release And Store Business Model

Hardstyle Revolution releases should support two main release types.

### Free Release

Free releases are completely free:

- no payment
- no ad requirement
- MP3 download

The UI can label this as `FREE DOWNLOAD`.

### Premium Release

Premium releases should offer two paths:

- Watch a rewarded ad to unlock a free 128 kbps MP3 download.
- Buy a higher-quality version.

Payment requirement:

- paid digital releases are purchased through Google Play Billing (not a direct Google Pay checkout) so the Android app remains Play policy compliant

Release processing:

- upload one WAV master per release
- generate the 128 kbps MP3, 320 kbps MP3 and preview derivative server-side with FFmpeg
- run conversion as a background job, never inside the upload/API request
- keep the WAV master private and expose each derivative only after its entitlement is satisfied
- Websupport currently provides `/usr/bin/ffmpeg` 4.4.2 with `libmp3lame`; background-job execution and upload-path permissions still need an end-to-end test

Paid options:

- 320 kbps MP3, example price `1.99 EUR`
- WAV/lossless, example price `2.99 EUR`

The intended user value:

- casual listeners can watch an ad and get a lower-quality phone-friendly MP3
- DJs or quality-focused users can buy the 320 kbps MP3 or WAV
- the free ad-supported option should not remove the value of the paid versions

Example premium release UI structure:

- release title
- artist name
- preview player
- `Watch Ad` option for `MP3 128 kbps`, free
- `Buy MP3` option for `320 kbps`, paid
- `Buy WAV` option for lossless, paid

Future release/store API fields should likely include:

- `id`
- `title`
- `artist_name`
- `cover_image`
- `preview_url`
- `release_type` (`free` or `premium`)
- `free_download_url`
- `ad_reward_download_url`
- `mp3_320_price`
- `mp3_320_url`
- `wav_price`
- `wav_url`
- `wav_master_url` (private/admin-only; never expose before purchase)
- `processing_status`
- `spotify_url`
- `youtube_url`
- `hardstyle_com_url`

## UX Direction

The app should feel:

- dark
- direct
- energetic
- music/event focused
- mobile-first
- easy to scan

Avoid turning the app into a generic landing page. The first screen should feel like the actual app experience.

Useful mobile sections:

- latest news
- upcoming events
- featured event
- quick access to tickets
- DJs
- organizers
- more/settings/social/contact

## Android Notes

Before a public Android release:

- replace `com.example...` package/application id
- set the visible app label to `Hungarian Hardstyle`
- configure release signing
- verify launcher icons
- verify permissions
- use Gradle 8.14+, Android Gradle Plugin 8.11.1+, and Kotlin 2.2.20+
- test on a physical Android device

## iOS Notes

iOS is planned later. Do not optimize for iOS first unless the user explicitly asks.

When iOS preparation starts:

- test iPhone layouts
- test iPad layouts if desired
- prepare App Store metadata
- prepare icons/screenshots
- verify web links and external intents

## Content Language

Hungarian is the primary app language.

English support is a future internationalization goal. The Flutter interface may support Hungarian and English through Flutter's generated localization/ARB workflow. Dynamic content translation is separate: reviewed English content for posts, events, DJs/artists, and organizers should be stored in WordPress and delivered through their mobile REST APIs according to the selected locale, not translated on demand by Flutter. Do not introduce full i18n unless the user asks for it or the roadmap reaches that step.

## Coding Style

Follow existing Flutter and Dart conventions.

Prefer:

- small readable widgets
- clear model parsing
- Riverpod providers for async app data
- Dio for network calls
- explicit error handling
- simple, direct naming

Avoid:

- hardcoding real production content in Flutter
- adding unnecessary abstractions too early
- changing unrelated platform files
- large rewrites when a focused feature is requested

## Testing Expectations

At minimum:

- keep Flutter widget tests compiling
- update the default Flutter counter test if it still exists
- add focused tests for parsing models when API structures become stable

If a command cannot be run in the current environment, say so clearly.

## User Collaboration Preferences

The user prefers practical, directly usable code.

When providing code manually, prefer complete replacement file contents instead of tiny snippets or vague patch instructions.

When working inside the repo, make the actual file changes when possible and summarize what changed.

Keep explanations clear and in Hungarian unless the user asks otherwise.

When the user says "mehet", continue with the next clearly scoped implementation step without pausing for confirmation on minor sub-decisions.

When a WordPress backend change is required, never leave out the deployable WordPress files. Always identify the exact plugin files that must be uploaded, include them in the handoff (or package them when possible), and keep the Flutter/API contract changes synchronized. A Flutter-only change is incomplete when the backend contract also changed.

Do not change the Flutter app version in `pubspec.yaml` automatically. Only bump the app version when the user explicitly requests it or after confirming an objectively justified release milestone.

For major product or architecture decisions with meaningful alternatives, use the installed `grill-me` skill to clarify requirements before implementation. Do not invoke it for small, obvious, or narrowly scoped fixes.

Use the installed Ponytail plugin/rules for implementation work: prefer deleting or skipping unnecessary work, reuse existing project code, then standard/native platform features, then installed dependencies, and only write the minimum custom code that safely solves the task. Never trade away validation, security, accessibility, or data-loss protection merely to reduce code or token usage.

## Important Current Implementation Priorities

Likely next useful tasks:

Product decisions confirmed by the user:

- The current empty Tickets bottom-navigation tab after Events is not needed and should be removed; reserve its future primary-tab slot for the v1.0 Live Feed/chat user hook, and do not assume the DJ directory belongs there.
- Keep Home and News as the first two bottom-navigation items. Before finalizing the remaining items, define a clear importance order for primary navigation, Home content, and the More section.
- Evaluate the main user hook around immediate utility (for example, what is happening now and which event is next). Events are a strong primary-tab candidate; the DJ directory may initially live under More unless usage testing supports promoting it.
- Event data continues to come from the WordPress events API.
- Artist/DJ names and the organizer on event detail must be clickable.
- Artist and organizer event relations open dedicated API-backed profile screens and are confirmed against live data.
- v1.0 should introduce a Live Feed tab with chat and image posting.
- v1.0 should introduce Google sign-in, user profiles, friendships, and event attendance status (`Ott leszek` / `Nem leszek ott`).
- v1.0 should include an annual WordPress-managed Top DJ and Top Track voting API with in-app voting.
- Organizer profiles and submissions now support server-managed selectable music genres/styles (backend 2.4.9 prepared; deploy and live-test still pending).
- Add an About/App information area under More. Read the app version and build number from package metadata instead of hardcoding them, and include developer credit plus relevant website, contact, privacy, and terms links.
- Refactor navigation into a persistent shell so the bottom tabs remain visible on news, event, DJ, and organizer detail screens. Do not duplicate the NavigationBar inside each detail screen; preserve the active tab and each tab's navigation history.
- Keep using the shared in-app browser for ordinary article, event, profile, ticket, shortcode, and About-page links. Media and Maps may remain intentional native-app exceptions.
- Keep plain-text `http://` and `https://` URL linkification enabled for WordPress news and event HTML. A URL styled as a link must always be tappable even when the source did not wrap it in an HTML `<a>` tag.
- Event submission retains its general event/Facebook link field, while published event records now expose the dedicated `facebook_event_url` field through backend 2.4.3.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action that leads to the submission flow; once app registration exists, the action must require authentication.

1. Fix the default Flutter widget test so it matches `HungarianHardstyleApp`.
2. Clean up asset folder references or create the missing asset folders.
3. Set Android app label and application id before release.
4. Keep the working News API/list/detail flow intact when refactoring.
5. Improve News loading, empty, and error states if needed.
6. Improve WordPress rich content/HTML rendering for news if needed.
7. Add and connect dedicated artist list/detail REST endpoints.
8. Keep the deployed organizer list/detail REST endpoints compatible with the Flutter organizer module.
9. Keep organizer genres/styles from backend 2.4.9 compatible with the working organizer API.
10. Keep upcoming events working on DJ and organizer profiles.
11. Do not bump the app version unless the user explicitly asks; the version has not intentionally changed yet.

## Agent Reminder

Before making code changes:

- inspect the relevant files
- preserve existing working behavior
- do not treat placeholders as bugs unless they block the requested task
- keep changes scoped to the requested feature
- summarize what changed and what could not be verified
