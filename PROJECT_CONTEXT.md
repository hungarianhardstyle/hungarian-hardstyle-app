# PROJECT_CONTEXT.md

# Hungarian Hardstyle App

> AI Project Context
> Read this document before making any code changes.

---

# Project Goal

The Hungarian Hardstyle App is the official mobile application of the Hungarian Hardstyle community.

This is **NOT** just a news application.

The application should become the central platform of the Hungarian harder styles scene.

Everything should originate from WordPress and be available on:

- Android
- iOS
- Website

The WordPress installation is the single source of truth.

---

# Main Brand

## Hungarian Hardstyle

Main platform.

Contains:

- News
- Events
- Artists
- Organizers
- Releases
- Store
- Newsletter

---

# Related Brands

## Hardstyle Revolution

Functions:

- Record Label
- Event Series

Has its own:

- Facebook
- Instagram

Future:

- Releases
- Store
- Radio

---

## Rave Revolution

New event series.

Supports every harder electronic music style.

Examples:

- Hardstyle
- Rawstyle
- Hardcore
- Uptempo
- Hard Techno
- Reverse Bass

---

## Hard Lake

Free summer flashmob-style events.

Usually located at Lake Velence.

---

# Architecture

WordPress

↓

REST API

↓

Flutter

↓

Android

↓

iOS

Website uses the same WordPress backend.

Never duplicate data.

---

# Technology

Backend

- WordPress Plugin
- Custom Post Types
- REST API

Frontend

- Flutter
- Riverpod
- Dio
- Go Router

---

# Data Source

Everything must come from WordPress.

Never hardcode data unless temporary.

---

# Current WordPress Modules

## News

WordPress Posts.

Future:

Support all embedded content:

- YouTube
- Spotify
- TikTok
- Instagram

Links must open correctly.

---

## Artists

Contains:

- Name
- Image
- Biography
- Genres
- Country
- City
- Facebook
- Instagram
- TikTok
- Spotify
- SoundCloud
- YouTube

Future:

Upcoming Events list.

Clickable.

---

## Organizers

Contains:

- Logo
- Description
- Website
- Facebook
- Instagram
- TikTok

- Music genres/styles (multi-select)

Future:

Upcoming Events list.

Clickable.

Organizer genres are editable in WordPress, returned by the organizer REST API, and displayed on both app and public web profiles.

DJ and organizer listing cards must show images in one consistent frame size and aspect ratio. Use cover cropping with an upper-center focus so faces remain visible in portrait images while organizer logos and artwork keep the same card dimensions.

---

## Events

Contains:

- Title
- Description
- Flyer
- Start date
- End date
- Venue
- ZIP
- Address
- Country
- Google Maps
- Organizer
- Artists
- Ticket URL
- Featured
- Visible
- Status

Future:

Own frontend page.

---

# Releases

Future module.

Contains:

- Cover
- Artist
- Label
- Catalog Number
- Release Date
- Preview
- Spotify
- Hardstyle.com
- YouTube

Release = Product

Do NOT separate Releases and Store.

---

# Store

Future.

Runs from WordPress.

Uses Releases.

Release types:

## Free Release

Free download.

No advertisement.

---

## Premium Release

Reward Download

- 128 kbps MP3
- Requires rewarded advertisement

Paid

- 320 kbps MP3

Paid

- WAV

---

# Radio

The radio is a v0.99.2.1 scope item, not a deferred post-v1.0 feature. Use the Real Hardstyle FM stream and its current-track metadata; the feature is complete when a custom compact bar player matching the app's red-black design with Play/Stop/Mute, safe bottom-navigation placement, and the provider page are delivered. The former AutoDJ/AzuraCast concept is superseded.

Online streaming.

Background playback.

Place a compact, user-controllable player directly below the Hungarian Hardstyle logo on Home. A server-side AutoDJ should continuously rotate a configurable library of X uploaded tracks; Flutter consumes one live stream and does not bundle or sequence the production library. Audible playback starts only after a user action and can always be paused or stopped.

Preferred simple architecture: AzuraCast for media and playlist administration, Liquidsoap AutoDJ, Icecast-compatible streaming, and Now Playing data. Upload media in bulk through AzuraCast's built-in SFTP server, not unencrypted FTP. For cloud storage, use an officially supported S3-compatible provider or Dropbox. Google Drive is not a supported production storage location and would require a fragile custom synchronization layer.

Defer the hosting-provider decision until radio implementation. Start with a managed AzuraCast hosting plan for the simplest launch, then move to a suitably sized self-managed VPS only when listener usage, storage, or control requirements justify the extra operational responsibility.

Before implementation, decide music licensing, hosting, bandwidth, codec/bitrate, background playback, audio focus, interruptions, notification controls, and the initial X-sized music library.

---

# Newsletter

Mailchimp. The app now has a native signup screen backed by the live WordPress `newsletter/subscribe` endpoint (backend 2.4.15); invalid-email validation and a real personal e-mail double-opt-in test both succeeded. The Mailchimp API key stays on the server, and the hosted signup landing page remains available as a fallback.

No registration.

---

# Favorites

Stored locally.

No login.

Contains:

- Favorite News
- Favorite Events
- Favorite DJs

---

# Authentication

Current versions do not require registration and do not yet have user accounts.

For v1.0, add Google account sign-in and community user accounts.

Confirmed scope: registration and community accounts exist only in the mobile app. The public WordPress website does not need registration, user profiles, friendships, live feed, or chat UI.

Architecture exception: WordPress remains the single source of truth for editorial content, but app-only community data may use a separate real-time backend. This exception is limited to authentication, community profiles, friendships, chat/feed posts, image uploads, moderation state, and event attendance responses.

Public content such as news, events, DJs, and organizers should remain available anonymously where possible.

Authentication will be required for:

- live feed posting
- live chat
- image uploads
- creating and editing a personal profile
- adding and managing friends
- event attendance responses
- submitting DJs, organizers, and events once registration has been introduced

Until registration exists, the current public submission forms may remain available with rate limiting, file validation, and mandatory editorial approval. When authentication launches, Flutter must hide these forms from signed-out users and the backend must reject unauthenticated submissions.

The authentication and community backend must support privacy controls, moderation, reporting, blocking, account deletion, and safe image storage.

---

# REST API

Current

/events

/artists (backend 2.2.0 deployed and verified; returns only visible DJs)

/artists/{id} (deployed and verified with live DJ data)

/event-submission-options (backend 2.2.0 deployed and verified; shared genre options)

/event-submissions (POST, backend 2.2.0 deployed; validation verified, successful creation awaits intentional app test)

/organizers (backend 2.3.0 deployed and live-verified)

/organizers/{id} (backend 2.3.0 deployed and live-verified with upcoming events)

/profile-submission-options (backend 2.4.0 deployed and live-verified)

/artist-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

/organizer-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

Future

/releases

/store

---

# Mobile Navigation

Bottom Navigation

- News
- Events
- DJs
- Organizers
- More

Confirmed navigation change:

- The currently empty Tickets tab after Events is unnecessary and will be removed; its future primary-tab slot is reserved for the v1.0 Live Feed/chat user hook.
- Its replacement is not decided yet; do not automatically replace it with the DJ directory.
- Home and News should remain the first two bottom-navigation items.
- Define a deliberate importance order for what belongs on Home, in primary navigation, and under More. The leading user-hook hypothesis is immediate utility (what is happening now / what event is next), making Events a stronger primary-tab candidate while DJs may initially live under More.
- Revisit this choice using real testing and usage feedback before locking the final navigation.
- By v1.0, add a dedicated Live Feed tab for community chat and image posts; the final bottom-navigation layout must be revisited when this is implemented.
- Detail screens should eventually open inside a persistent navigation shell so the bottom tabs remain visible and the active tab/history is preserved. Implement this centrally rather than copying the bottom bar into each detail screen.

Confirmed event relationship behavior:

- Event content remains managed through the WordPress API.
- Every related DJ/artist name and the organizer shown on event detail must be clickable.
- They must navigate to complete dedicated DJ and organizer profiles populated from WordPress REST APIs.
- DJ and organizer profile screens are API-backed and connected to their event relationships.

---

# More Menu

Favorites

Newsletter

Settings

Social

Contact

About

The future About/App information screen should include:

- app name
- runtime app version and build number (read from package metadata, not hardcoded)
- developer/maintainer credit
- Hungarian Hardstyle website
- contact link
- privacy policy
- terms/community guidelines
- optional open-source licenses

---

# Settings

Contains

Push Notifications

News Notifications

Event Notifications

Version

Cache

Future

Theme

Language

---

# UI

Dark theme.

Modern.

Minimal.

Fast.

Use rounded corners.

Consistent spacing.

Avoid clutter.

---

# Flutter Rules

Always use:

Riverpod

Go Router

Dio

Models

Providers

Repositories

Avoid duplicated code.

---

# WordPress Rules

Everything should be editable from WordPress.

Never hardcode content.

Always expose new modules through REST API.

## AI-assisted editorial importer

Add a private WordPress admin workflow where an editor enters a public article URL and receives a Hungarian draft with supported media placement. Publishing that WordPress post should make it available to both the website and the existing Flutter posts API.

Requirements:

- always create a draft and require human editorial approval
- provide a faithful translation mode only for content the publisher owns or is permitted to translate
- provide an original Hungarian summary/adaptation mode with a visible source link for third-party reporting
- store the source URL and attribution metadata
- import featured and inline images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image
- never expose the AI provider key to Flutter or public REST responses
- validate remote URLs and block internal/private network targets, unsafe HTML, oversized downloads, and slow requests
- retain the existing WordPress post format so galleries, embeds, website rendering, and the Flutter app continue to use one source of truth

## AI-assisted English post translation

Add the article translation workflow directly to the standard WordPress blog post editor. An administrator should be able to generate or refresh a separately editable English draft/version from the Hungarian post. Keep the AI provider key server-side, preserve names, links, embeds and shortcodes, require human review, and never auto-publish or translate content dynamically in Flutter.

English localization must also cover the mobile REST APIs for posts, events, DJs/artists, and organizers. Their WordPress editing screens should eventually support stored, reviewable English fields or versions. Each endpoint should return the requested stored language according to the Flutter locale and fall back field-by-field to Hungarian when English is unavailable. Public API requests must never trigger AI generation. The Flutter interface itself may separately support Hungarian and English through normal app localization.

---

# Future Features

- Purposeful Hungarian Hardstyle-branded loading animation for v1.0, without artificial startup delay and with reduced-motion support
- Refine the Android startup animation to show the full HUHS logo without a white background

- Online Radio is a v1.0 goal, with a Home mini-player and server-side AutoDJ

- Five curated Spotify playlists should be available from a dedicated app section; open Spotify first and fall back to the browser.

- Before external/cloud image uploads, compress submission images on-device to roughly 1200–1600 px width in JPEG/WebP format to reduce storage and bandwidth use.

- Hardstyle Revolution Releases are a v1.0 goal; the catalog remains WordPress-managed and should be exposed through the mobile API.

- Music Store

- Hungarian Hardstyle Top DJ Voting

- Top Track Voting

- Calendar integration

- Better search

- Recommendations

- Live Feed with chat and image posts
- Push notifications should cover new published news, new published events, event reminders one week before and on the event day, plus admin-created custom notifications from WordPress.
- Current push status: Flutter initializes Firebase/FCM, stores the token locally, registers it with the WordPress API, shows foreground notifications, opens news/event targets in native screens, and syncs per-device notification preferences. Backend 2.4.16 includes Firebase HTTP v1 sending, news/event/link targets, automatic HUHS URL resolution, publish hooks, event reminder scheduling, preference filtering, and a protected service-account settings page. Custom push, news/event publishing pushes, and foreground display are live-tested successfully; the first natural event-day reminder did not arrive, so WP-Cron execution, timezone/date parsing, preference filtering, and the FCM send path must be investigated. Credentials must never be embedded in Flutter or committed to the plugin.
- The WordPress custom-push form lists the latest published news and events by title, so editors do not need to know WordPress post IDs. It validates that the selected content matches the chosen target type.
- Backend 2.4.12 is live with published IRP related-post records and a public post-detail endpoint. The live endpoint and a real “Kapcsolódó cikk” target were verified. Flutter opens IRP records and normal WordPress “Kapcsolódó cikk”, “Kapcsolódó”, and “Ez is érdekelhet” links in the native news detail screen and falls back to the in-app browser when no post ID is available.

- Google account registration and sign-in

- Community user profiles

- Friend connections

- Event attendance (`Ott leszek` / `Nem leszek ott`)

- Friend attendance visibility on profiles and events

- WordPress-managed FAQ / GYIK section is a v1.0 goal, initially accessible under More, with categories, ordering, search, and expandable answers in Flutter

## Annual Top DJ And Track Voting

Target: implement by v1.0.

The existing annual WordPress-extension voting workflow should be replaced or complemented by a dedicated Hungarian Hardstyle voting module and REST API.

WordPress remains the administration surface and source of truth for:

- voting seasons and year
- start and end timestamps
- voting status and rules
- `Legjobb magyar hardstyle DJ – <év>` candidates
- `Legjobb magyar hardcore DJ – <év>` candidates
- `Legjobb magyar bulisorozat – <év>` candidates
- `Legjobb magyar zene – <év>` candidates
- `Legjobb külföldi DJ – <év>` candidates
- candidate names, artist/title data, images/covers, optional previews, and external links
- result publication settings

The displayed year should come from the voting season configuration. Candidate types must support DJs, event series, and tracks.

Flutter must:

- fetch the active annual voting season and categories
- display DJ and track candidates
- allow authenticated users to vote in-app
- clearly show whether the user has already voted
- show results only according to the server-defined visibility policy

The backend must enforce voting windows, authentication, duplicate-vote prevention, and category limits. Prefer one authenticated user vote per category by default. Before implementation, decide whether votes can be changed, when results become public, what audit data is retained, and how suspicious voting is moderated.

WordPress admin must include a private overall results dashboard with:

- total submitted votes
- unique voter count where privacy rules allow it
- per-category totals and ranking
- candidate vote totals and percentages
- optional suspicious-vote/moderation indicators
- export capability if needed later

This summary is admin-only. Do not expose it through public REST routes and do not make it visible to ordinary app users unless a season explicitly publishes a separate sanitized result response after voting closes.

### Published Results After Voting

When voting is closed, WordPress admins must be able to explicitly publish a separate results summary that the Flutter app can display. Closing a season and publishing its results are separate actions.

The public results API/page should support:

- season title and year
- voting closed timestamp
- all published categories
- final candidate ranking per category
- candidate name/title and image/cover/logo
- optional vote count and percentage controlled by season settings
- winner highlighting

The public result must never expose voter identities, authentication identifiers, raw vote records, IP/device data, audit logs, moderation notes, or suspicious-vote indicators. Admins should also be able to keep results private or unpublish the public summary if correction is required.

---

# iOS

Application must fully support:

- Android

- iPhone

Future:

iPad

---

# Current Version

v0.99.1+12 (current Flutter package version; community authorization build)

Planned next package: v0.99.2. Its first release check is the AdMob test banner, enabled for the test build with `HUHS_ENABLE_TEST_ADS=true`. Production AdMob IDs and consent/privacy handling remain deferred until the public release.

The v0.99.3 scope also includes making the About screen contact e-mail open the device mail app and keeping the Real Hardstyle FM stream playing when the user switches between apps.

v0.99.2 bugfixes to investigate: e-mail/password sign-in fails despite valid credentials; saved profile images do not render on the profile/avatar; admin user deletion returns a Firebase Functions `INTERNAL` error; and the owner account intermittently falls back from `Szervező` to `Bulizó` while admin access must remain intact. Account roles are final after registration; only admins may change another user's role, enforced server-side. Profiles and Chat must render the persisted account role, with separate `Admin` or `Moderátor` access badges.

Tag- and genre-filtered discovery lists must use API pagination/infinite scroll so all matching news and DJ results can be reached, not only the initially loaded page.

Next build follow-up: collect separate Facebook, Instagram, TikTok, YouTube, and Spotify fields during registration and in the community profile.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
- v0.99.2 follow-up: allow gallery images to be saved to the device with platform permission handling.
- v0.99.2 follow-up: add a Data protection / GDPR information section covering privacy, retention, and user rights.
- v0.99.2 follow-up: review personal-data access rules and keep sensitive operations server-side.
- v0.99.2 follow-up: add practical release hardening (release signing, obfuscation, restricted backend secrets, and abuse/rate-limit checks); absolute protection against reverse engineering is not possible.
- v0.99.2.1 radio scope: completed the Real Hardstyle FM integration at `https://stream.realhardstyle.nl` as the Home radio stream, with a custom compact bar player (Play, Stop, and Mute), current-track metadata when available, safe placement above bottom navigation, and a More-section provider page with the supplied logo, website, and attribution text.
- v0.99.2.1 follow-up: completed the readable modern/cyber-style font fallback with Hungarian accented-character support.

### v0.99.3 - HUHS Vezérlőközpont

- Integrate the WordPress Mobile API administration into the authenticated app admin panel as a separate, red-black branded `HUHS Vezérlőközpont` menu; show and authorize it exclusively for Admin access roles.
- Add a separate admin-only `Felhasználók` menu inside the admin panel with user search and user-management actions.
- Restrict event submission to authenticated registered users; hide it from guests in Flutter and reject unauthenticated API requests.
- Refresh the full app visual layout toward the approved red-black mockup across Home and every menu/screen: Rajdhani typography, consistent cards and controls, compact news/event sections, section shortcuts, and the compact radio bar, using the real HUHS logo rather than generated placeholder artwork.
- Make the About screen contact e-mail open the device mail app.
- Keep the Real Hardstyle FM stream playing when the user switches between apps.
- Show the saved profile image on the user's own profile screen.
- Investigate and fix stale automatic refresh/cache issues, including newly uploaded profile images.

Required for v1.0: Hungarian/English Flutter interface localization, AI-assisted and human-reviewed English WordPress content for blog posts, events, DJs/artists, and organizers, and locale-aware mobile REST APIs with Hungarian fallback.

Required before public release: a final UX and visual polish pass covering navigation, spacing, labels, buttons, loading/error states, accessibility, and tasteful motion/effects.

The Websupport upstream WAF still blocks direct multipart image uploads with HTTP 466, but v0.99 bypasses it with direct Cloudinary uploads. Websupport allowlisting is intentionally deferred until after v1.0 and is not a current release blocker. The dedicated Facebook Event URL field is deployed in backend 2.4.3 and tested.

Backend 2.4.9 organizer genre/style metadata and synchronized Flutter display/submission support are implemented; the Flutter changes pass analysis and all tests. Live organizer genre verification remains an editorial content check.

v0.9 implementation status:

- completed: local favorites for news, events, DJs, organizers, and the featured news card
- completed: native news/event titles, related-article navigation, artist Website/Booking labels, organizer genres, social/contact, settings, FCM registration, and custom push targets
- completed: native Mailchimp signup screen and WordPress proxy (backend 2.4.15 live; personal double-opt-in test successful)
- remaining operational investigation: the first natural event-day reminder did not arrive; verify WP-Cron, timezone/date parsing, preference filtering, and the FCM send path

v0.95 implementation status:

- completed: on-device submission-image resizing and quality reduction before multipart upload (up to 1600 px, quality 82)

v0.97 polish build status: complete

- fix DJ logo rendering in Flutter while retaining the profile-image fallback order
- standardize DJ and organizer list thumbnails with a fixed cover frame and upper-center portrait focus
- deploy backend 2.4.20 with `Happy Hardcore` in the shared DJ, event, and organizer genre options
- keep DJ names readable in two-column cards on one line by scaling long names down instead of truncating them beside action icons (implemented in Flutter)
- [x] rename the event ticket action to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- one-week, one-day and six-hour reminders are live-verified

v0.99 submission polish:

- Event submission must require date, venue name, city, and address in both Flutter and WordPress/API validation.
- Add the required address field below the venue name.
- Add event end date and end time fields; reject an end datetime earlier than the start datetime.
- Populate the organizer dropdown from WordPress in Flutter and keep it aligned with the existing WordPress selector.
- Require at least one genre; missing required values must show inline messages and red invalid-field styling.
- Replace blocked multipart image submission with direct Cloudinary upload using the unsigned `Hun_hs_Mobile` preset, then send the returned URL to WordPress for DJ, organizer, and event submissions.
- Flutter implementation is complete in release `0.99.1+4`; WordPress Mobile API `2.4.29` is prepared locally and still needs deployment/live verification. It includes the 2.4.28 features plus push-title/body HTML-entity decoding and UTF-8 JSON output.
- v0.97 polish complete: event postal-code input accepts digits only in Flutter and WordPress/API validation; new-event publication pushes remain global to FCM-token devices.
- Planned v1.0 notification personalization: normal event pushes target users who favorited or marked attendance; featured-event publication and reminder pushes remain global to every app-installed device with an FCM token, regardless of account registration; users who favorite an organizer receive that organizer's new-event notifications. Explicit notification opt-outs remain respected. A separate admin/editor push for newly received submissions is an optional follow-up.

Planned v1.0 community profile details:

- expose the authenticated profile from a circular top-left Home avatar, using the profile image or a monogram fallback
- let users select an onboarding role: DJ, organizer, or attendee/partygoer
- show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce this in the backend as well as Flutter
- bootstrap a private app-admin account for the project owner with full submission approval and editing permissions; do not publish the owner e-mail in app content
- store profile social links, planned events, and favorites together in the profile area
- allow a registered user to claim a DJ profile only after verifying the private or artist-owned booking e-mail stored on that profile; exclude the Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) from ownership proof
- add friend requests and an `Ismerősök` list
- show attending friends on event details
- Reuse the Cloudinary direct-upload path for authenticated Live Feed/chat image posts; do not send those images through the Websupport multipart endpoint.

Current v0.99.1 implementation status:

- The user-facing community destination is named `Chat`; the Firestore collection remains `live_feed_posts` for compatibility. The composer is responsive, Firebase initializes before the app shell, missing WordPress tag names are hydrated from the core posts REST endpoint, and Firestore rules are deployed. Google sign-in provider and Android SHA configuration are present; release-device verification remains a final external check.

- Flutter includes Firebase Auth registration/sign-in with mandatory DJ, organizer, and partygoer roles.
- The public Firestore Live Feed supports anonymous text-only posts, registered Cloudinary image posts, Unicode emoji, and fixed reactions.
- Home exposes a profile entry, a five-item news slider with 10-second rotation, and news detail exposes tappable tags with a native filtered article list.
- Firestore deployment files are `firestore.rules`, `firebase.json`, and `.firebaserc`; physical ARM verification and rules deployment remain external release checks.
- v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds moderator Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys Firestore rules to the named `hungarian-hardstyle` database used by the app. Profile uploads use Cloudinary face-aware cropping; manual focal-point editing remains a later UX enhancement.
- Chat message deletion and the in-app role-management panel are implemented; actual Firebase Auth account deletion for another user is handled by the deployed server-side Cloud Function/Admin SDK task.
- The Cloud Function source is in `functions/` (`deleteCommunityUser`) and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
- Also record for the next fix pass: push notification text has an encoding bug and may show Hungarian punctuation/accents as HTML entities (for example `&#8211;`) instead of decoded characters.
- Additional community authorization requirements are implemented: the `djdeeroy@gmail.com` admin role is restored on profile load, normal users cannot change roles after onboarding, and admins can remove users and delete Chat messages.
- The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Manual focal-point editing remains optional UX polish.
- v0.99.1 remaining external check: verify Google sign-in on the release device with the current Firebase Android SHA configuration; manual profile focal-point editing remains optional polish.

Planned v0.99.1 Community MVP decisions:

- The Live Feed is publicly readable without registration.
- Signed-out users may publish text only under a generated `Unknown User ####` display name; they cannot upload images or create profiles.
- Registration requires an account role: DJ, organizer, or partygoer.
- Registered users get an app-only profile with avatar/monogram, name, bio, social links, favorites, and planned events.
- Registered users may publish compressed snapshot images to the Live Feed.
- Live Feed messages support Unicode emoji and a small fixed reaction set without introducing a heavy emoji dependency.
- Firebase Authentication/Firestore is the minimal community backend; Cloudinary is the temporary image store. WordPress remains the editorial source of truth.
- Full moderation, friendships, attendance visibility, profile claims, and app-admin tooling remain v1.0 work.
- Add a `Több`-menu user directory/search that lists registered users only and is unavailable to guests.
- Organize `Több`-menu entries into clear categories while keeping `Több` as the visible menu name.

Additional v1.0 product requirements:

- Make displayed genres selectable. A genre detail/discovery screen should show separate API-backed `Események`, `DJ-k`, and `Hírek` sections for the selected genre and clearly retain the active genre label.
- Add a More-section `Támogatás / Donate` card backed by a configurable PayPal donation URL. Open the PayPal app when available and fall back to the browser; do not build a custom payment flow for the first release.

Completed

✔ News

✔ Search

✔ Events Backend

✔ Artists Backend

✔ Organizers Backend

✔ Event REST API

✔ Flyer

✔ Ticket URL

✔ Google Maps

✔ Event Shortcode

Flutter Completed

- Dynamic Events in Flutter

- Event Detail with flyer, ticket and Google Maps actions

- HTML tag cleanup for news excerpts

- Clickable event artists and organizer open their API-backed profile screens and are verified with live data

- API-backed DJ directory under More with search, Hardstyle/Hardcore filters, portrait-focused profile cards, full DJ details, social links, biography, and upcoming events

- Event artist and organizer taps open their real API detail screens

In Progress

- Artists API and the Flutter DJ module are deployed and confirmed working with live data.

- Responsive WordPress collection shortcodes: `[huhs_djs]` groups linked DJ cards by category, while `[huhs_events]` lists all upcoming visible events with flyer, date, venue, details, and ticket actions

- Public WordPress archive URLs `/djs/` and `/events/` automatically use the plugin's matching polished collection templates; manual shortcode pages remain optional

- WordPress admin includes `HUHS Mobile > Shortcode-ok`, a copyable reference page for all supported shortcode variants and parameters

- Flutter Events includes an `Esemény beküldése` form. Genres come from WordPress, multiple genres can be selected, and successful submissions are stored as pending items for editorial review rather than being auto-published

- Organizer list/detail API and Flutter UI are implemented and live-verified, including search, logo, description, social links, and upcoming events

- Rich content: YouTube, Spotify, SoundCloud, Instagram and TikTok embeds now render in article detail; interactive WordPress shortcodes open in an in-app web view
- Backend package `2.2.0` includes the earlier rich-content fixes and DJ API/category work, plus the upgraded `[huhs_events]` collection, shared event/DJ genre options, and moderated public event submissions

- Backend `2.2.1` is deployed and confirmed working. It renames the DJ `hero_image` concept to `Profilkép` in the admin, uses that profile image before logo/featured-image fallbacks in DJ directories, and exposes `profile_image` in the artist API while retaining `hero_image` for compatibility

- Backend `2.2.2` is deployed and confirmed working. It and the Flutter DJ UI use consistent cover cropping with an upper-center portrait focal point so faces remain visible when source profile images have different dimensions
- Backend `2.3.0` is deployed and live-verified with organizer list/detail REST endpoints and related upcoming events; the Flutter organizer module and event-detail organizer navigation use these responses
- Backend `2.4.0` is deployed and live-verified. It adds moderated DJ/organizer submissions, admin approval into non-public draft profiles, public DJ booking e-mail support, and a `booking_via_huhs` option that routes booking requests to `info@hungarianhardstyle.hu`
- Backend `2.4.1` is deployed. It accepts optional multipart event flyers and DJ profile images, restricted to JPG/PNG/WebP and 5 MB, stores them as Media Library attachments on pending submissions, previews them for admins, and applies an approved DJ image to the generated draft profile
- Flutter event and DJ submission forms use the device gallery/camera with local preview instead of requiring users to paste image URLs
- Backend `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow; an approved organizer submission receives the uploaded Media Library image as its logo and featured image
- Backend `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend `2.4.7` is deployed and awaiting live approval-flow verification. It replaces the invalid nested approval form with a nonce-protected admin action, removes the misleading native publish box from submissions, restores DJ/organizer draft creation, and adds event-submission conversion into a non-visible event draft.
- Backend `2.4.8` is deployed. It adds separate DJ profile-image and DJ-logo multipart fields, applies both images to approved DJ drafts, exposes an editable DJ website through WordPress, the artist REST API, public profiles, and Flutter, and returns full event objects in DJ/organizer `upcoming_events` so tapping those cards opens complete event details. The latter was verified live; image-upload verification remains blocked by the upstream WAF.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action; after app registration is available, the action must require an authenticated user.
- Flutter includes DJ and organizer submission forms under More. DJ submitters can choose Hungarian Hardstyle-managed performance booking; submitted profiles still require WordPress editorial approval and explicit publication/app visibility
- Submitted profile and organizer images are reviewable URLs. They are not automatically copied into the WordPress Media Library; the editor selects/imports the approved image before publication
- DJ logos now render in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- Profile list refresh now uses auto-dispose providers; continue monitoring live WordPress/API cache behavior after publishing.
- Link handling implemented: normal news, event, ticket, and shortcode links open in one shared in-app browser view, and plain-text URLs in WordPress news/event HTML become tappable automatically. Native media and Maps handoff remain explicit exceptions.

- Web Event Detail

---

# Development Philosophy

WordPress is the CMS.

Flutter is the client.

Never duplicate content.

One backend.

Multiple platforms.

Keep architecture clean.

Keep code modular.

Think long-term.

---

# Vision

The Hungarian Hardstyle App should become the central hub of the Hungarian harder styles scene.

One platform.

One backend.

Multiple brands.

Multiple clients.

Android.

iOS.

Website.

Community.

Music.

Events.

News.

Everything connected.
