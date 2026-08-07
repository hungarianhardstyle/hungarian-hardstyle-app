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

WordPress is the source of truth for editorial/content data (news, events, DJs, organizers and future catalog items). Firebase is the source for community authentication and community data such as profiles, roles, Chat and reactions.

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
- The WordPress API plugin source is present locally as deployable ZIPs in `build/`, currently through `build/huhs-mobile-api-2.4.37.zip`; the latest package has been extracted and reviewed locally.
- The latest package version is 2.4.37. It is the existing HUHS Mobile API with the native controller editor fixes, and it retains the live `huhs_release` records and public releases endpoint. It generates only a maximum 60-second preview from a temporary MP3/WAV source, then deletes the source; full audio is never exposed.
- Backend package `2.3.0` is deployed and confirmed working. It includes organizer list/detail REST endpoints, organizer search, logo/social data, and organizer upcoming-event relations.
- Backend package `2.4.0` is deployed and live-verified. It adds moderated DJ and organizer submissions, a one-click admin approval flow that creates non-public draft profiles, and DJ booking fields including the optional Hungarian Hardstyle-managed booking route.
- Backend package `2.4.1` is deployed. It adds multipart image upload for event flyers and DJ profile images. Files are limited to 5 MB and JPG/PNG/WebP, stored in the WordPress Media Library, attached to the pending submission, and never auto-published.
- Backend package `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow.
- Backend package `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend package `2.4.7` is deployed. It fixes the invalid nested admin approval form that prevented DJ and organizer draft creation, removes the misleading native publish box from submissions, and adds the same one-click draft creation flow for event submissions. The approval flow still requires a live WordPress admin test.
- Backend package `2.4.8` is historical. Its multipart image path remains documented for compatibility; the active app upload path is Cloudinary and direct multipart uploads are not a current WAF/deployment status.
- Backend package `2.4.12` is deployed and live-verified. It exposes published IRP related-post records and a public post-detail endpoint; a real "Kapcsolódó cikk" target was verified. Flutter opens returned related articles plus normal WordPress "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links in the native news detail screen and falls back to the in-app browser when IDs are unavailable.
- Backend package 2.4.31, 2.4.33 and 2.4.36 are historical; the current uploaded package is 2.4.37.
- Backend package `2.4.16` also contains the FCM HTTP v1 sender: mobile token registration, news/event/link targets, automatic HUHS URL resolution, foreground display support, per-device notification preferences, publish-time news/event pushes, scheduled event reminders, and an admin custom-push form. Custom push and news/event publishing pushes are live-tested; the first natural event-day reminder did not arrive and the cron/timezone/filter path needs investigation.
- Event-day reminder delivery is now live-verified; it is not an open v0.99.8 or v1.0 investigation.
- The custom-push admin form lists recent published news and events by title and validates the selected post type, so editors do not need to look up event IDs manually.
- Backend package `2.4.15` adds the server-side Mailchimp newsletter subscription endpoint and protected admin settings page; the endpoint is live and both invalid-email validation and a real personal e-mail double-opt-in test succeeded. Flutter includes a native signup screen with consent and double opt-in messaging.
- Backend package `2.4.9` is prepared for deployment. It adds organizer genre/style metadata, WordPress editor controls, API output, and genre validation/storage for organizer submissions. Flutter now displays organizer genres and includes them in organizer submissions.
- Cloudinary is the only active app image-upload path.
- DJ logos are rendered in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- DJ/organizer list providers now use auto-dispose so newly published or edited profiles refresh after navigation.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/posts`.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/events`.
- Backend package `2.2.0` is deployed. Its artist list/category endpoints, shared submission genre options, validation response, and public DJ/event archive templates were verified live. A successful real submission still needs an intentional end-to-end app test because it creates a pending WordPress item.
- The v0.99.89 Label release catalog is complete; only the later paid store extension remains future work.
- Dynamic events and the event detail screen are connected to the WordPress events API.
- Event detail artists and organizer are clickable. Artist links open complete API-backed DJ profiles. Organizer links are now connected to the organizer detail provider and require backend `2.3.0` in production.
- News excerpts are converted to plain text and HTML tags are removed for both custom and standard WordPress responses.
- News search uses the custom `huhs/v1/posts` endpoint so search results retain the same processed content, featured images, galleries, and embeds as the normal news flow.
- News detail renders deduplicated YouTube, Spotify, SoundCloud, Instagram, and TikTok embeds in-app. Supported interactive WordPress shortcodes (`ays_poll`, `irp`, and legacy Final Tiles Gallery) are detected; their raw shortcode text is removed and the rendered WordPress content can be opened inside the app.
- Plain-text web URLs in news and event HTML are automatically converted into tappable links. Normal article, event, ticket, and shortcode links use the shared in-app browser; native media and Maps handoff remain intentional exceptions.
- WordPress API work exists and should continue to be the backend source for new dynamic features.
- Flutter-side WordPress integration is complete for the current news, events, DJs, organizers, submissions and the closed v0.99.89 Label release catalog. The native HUHS Vezérlőközpont remains the admin source.

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
- the Label release catalog is complete in v0.99.89; paid purchase/store is a later extension in the same area

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
Community authorization is now separated: `djdeeroy@gmail.com` is an Admin with the account role Szervező; normal users cannot change account roles after onboarding; admins manage account/access roles and Chat messages; moderators cannot edit or delete Chat messages.

The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Superseded by v0.99.3: free profile-image zoom and movement are required.
v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds admin-only Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys the Firestore rules to the named database used by the app. Google sign-in remains a release-device/Firebase SHA verification check; Superseded by v0.99.3: free profile-image zoom and movement are required.

The next Flutter test build is v0.99.2. The Google AdMob test banner is enabled for the test build with `HUHS_ENABLE_TEST_ADS=true`; do not switch to production AdMob identifiers yet. Consent/privacy and production monetization remain release work.

The v0.99.3 scope also includes making the About screen contact e-mail open the device mail app and keeping the Real Hardstyle FM stream playing when the user switches between apps.

Record for v0.99.2 bugfix work: diagnose the e-mail/password sign-in failure without assuming the password is wrong; restore profile-image rendering; fix the `deleteCommunityUser` Cloud Function `INTERNAL` failure from admin user deletion; persist `djdeeroy@gmail.com` as account role `organizer`/`Szervező` while retaining `admin` access; enforce final account roles server-side so only admins can change them after registration; and show the persisted account role on profiles and Chat with separate Admin/Moderátor access badges.

Tag- and genre-filtered discovery lists must use API pagination/infinite scroll so all matching news and DJ results can be reached, not only the initially loaded page.

Separate Facebook, Instagram, TikTok, YouTube, and Spotify fields during registration and in the community profile are complete.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
- v0.99.2 follow-up: allow gallery images to be saved to the device with platform permission handling.
- v0.99.2 follow-up: add a Data protection / GDPR information section covering privacy, retention, and user rights.
- v0.99.2 follow-up: review personal-data access rules and keep sensitive operations server-side.
- v1.0: complete security hardening, obfuscation, restricted backend secrets, abuse/rate-limit checks, and production release signing; absolute protection against reverse engineering is not possible.
- v0.99.2.1 radio scope: completed the Real Hardstyle FM integration at `https://stream.realhardstyle.nl` as the Home radio stream, including a custom compact bar player matching the app's red-black design (Play, Stop, and Mute), current-track metadata when available, safe placement above bottom navigation, and a More-section provider page with the supplied logo, website, and attribution text.
- v0.99.2.1 follow-up: completed the readable modern/cyber-style font fallback with Hungarian accented-character support.

### v0.99.3 - HUHS Vezérlőközpont

- [x] Implement the WordPress Mobile API administration natively in the Admin-only HUHS Vezérlőközpont, including readable content/custom metadata editing, submissions, trash, Mobile API settings/status, push, newsletter status, shortcodes, About and persistent `Indítási kép` management. Exclude the radio provider and generic WordPress news/page/media/comment/taxonomy/user menus.
- [x] Add a separate admin-only `Felhasználók` menu inside the admin panel with user search and user-management actions.
- [x] Restrict event submission to authenticated registered users; the Flutter form is hidden/guarded for guests, and WordPress-side unauthenticated rejection is verified.
- [x] Complete the approved red-black TypeUI visual layout across Home and every menu/screen: Rajdhani typography with Hungarian accents, consistent cards and controls, compact sections and radio bar, the unchanged original `assets/logos/huhs_logo.png` HUHS logo, and the Home slogan.
- [x] Keep the Home logo area free of navigation shortcuts that duplicate the persistent bottom navigation; use the compact two-line TypeUI radio bar above the bottom navigation.
- [x] Refresh the native admin after startup-image saving without returning the asynchronous reload request from `setState`.
- [x] Allow admins to disable and clear the configured startup image from the app.
- [x] Keep the Chat emoji helper on one line and the send action in its own full-width row.
- [x] Make the About screen contact e-mail open the device mail app.
- [x] Keep the Real Hardstyle FM stream playing when the user switches between apps.
- [x] Show the saved profile image on the user's own profile screen, falling back to the Firebase user photo URL and then a name/e-mail monogram.
- [x] Refresh profile/avatar state after authentication and profile-image changes.
- [x] Keep the editor preview identical to the saved circular avatar crop and persist true horizontal and vertical positioning together with pinch zoom.
- [x] Open the community profile in a read-only view and place editing behind a separate `Profil szerkesztése` action and screen.
- [x] Refresh the Real Hardstyle FM current-track metadata automatically while playback is active.
- [x] Reconnect the Real Hardstyle FM player automatically after an unexpected stream interruption.
- [x] Fix the push-settings screen lifecycle assertion (`_dependents.isEmpty`); push delivery itself remains unchanged.
- [x] Resolve Chat avatars from the author's current community profile so earlier messages update after a profile-image change.
- [x] Add a profile deletion option with an explicit confirmation step.
- [x] Require confirmation before deleting Chat messages.
- [x] Require confirmation before an admin deletes a user account.
- [x] Keep the Chat camera action, emoji helper (`Emoji a billentyűzetről is használható`) and signed-in status on one compact line above the Send button.

- [x] Fix the phone-verified Hungarian character-encoding/mojibake errors on the community profile screen.
- [x] Remove the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries from the native HUHS Vezérlőközpont.

v0.99.3 is complete, phone-verified by the project owner in Flutter build `0.99.3+27`, and closed. Do not reopen or rework this release unless a new regression is explicitly reported.

### v0.99.4 - Small Improvements (implemented)

Implemented in Flutter `0.99.4+3`:

- categorize the existing `Több` entries without renaming the menu:
  - `Felfedezés`: DJ-k, Szervezők, Spotify Playlistek
  - `Közösség`: Kedvencek, Hírlevél; the v1.0 registered-user search will also belong here
  - `Beküldés`: role-gated event, DJ and organizer submissions
  - `Kapcsolat és támogatás`: Social és kapcsolat, Támogatás / Donate, Hibajelzés, GYIK / FAQ
  - `Alkalmazás`: Beállítások, Adatvédelem és GDPR, Az appról, Rádió szolgáltató
  - keep the HUHS Vezérlőközpont in the Admin profile; do not duplicate it in `Több`
- [x] add the PayPal `Támogatás / Donate` card
- [x] add a pre-addressed feedback e-mail action with the runtime app version
- [x] add the WordPress-managed FAQ under More with categories, ordering, search, expandable answers, and loading/empty/error states; the initial 10 Hungarian FAQ entries are populated in production (API package 2.4.33)
- [x] persist favorites in the signed-in user's Firestore profile (with local cache and bulk deletion)
- [x] replace full social-media URLs on community profiles with compact, clickable Facebook, Instagram, TikTok, YouTube, and Spotify buttons
- [x] move the existing Home AdMob banner below both the latest-news and upcoming-events sections
- [x] add one clearly separated inline adaptive AdMob banner to the native news list
- [x] fix Instagram post embeds in news so `instagram://` URLs are converted to supported web links before opening
- compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions
- [x] show a registered-user/role requirement in `Beküldés` when no submission action is available
- [x] update the in-app GDPR text for the current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob data flows
- [x] add a second separated adaptive test AdMob placement after the first five news cards

- [x] compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions

The event-tag fast-scroll regression is fixed. WordPress Mobile API `2.4.33` is deployed and live-verified with the FAQ endpoint. The ARM64 test APK is `build/HUHS-v0.99.4+3-arm64-debug.apk`. Production AdMob identifiers and consent/privacy handling remain release work. v0.99.4 is closed.

### v0.99.5 - complete

Implemented in Flutter `0.99.5+1`:

- [x] password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- [x] clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- [x] Chat profanity masking and automatic message/avatar refresh
- [x] native admin panel scope and readable content with concise save/cancel errors
- [x] final loading/card/control polish and test-AdMob placement

v0.99.5 is complete, phone-verified by the project owner, and closed. The ARM64 debug APK is `build/HUHS-v0.99.5+1-arm64-debug.apk`.

### v0.99.6 - complete

- [x] save gallery images to the device, including the pre-Android 10 permission fallback
- [x] make widget tests Firebase-safe and restore a green test run
- [x] update Gradle, Android Gradle Plugin and Kotlin compatibility
- [x] finalize the full HUHS-logo startup animation
- [x] polish profile and Chat avatar refresh/cache behavior
- [x] audit Hungarian text and character encoding
- [x] resolve remaining accessibility and layout-overflow issues
- [x] verify AdMob test placement and display
- [x] build and verify the final ARM64 debug test APK

v0.99.6 is complete after passing `flutter analyze` and the full `flutter test` suite. The final ARM64-only debug artifact is `build/HUHS-v0.99.6+1-arm64-debug.apk`; Graphify was refreshed after the final source and documentation changes.

### v0.99.7 - Community follow-up (complete)

- [x] allow verified-email users to claim a DJ profile after matching the private or artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address never qualifies as proof
- [x] add registered-user search/listing under `Több`; the list filters from the first typed character
- [x] add admin-triggered personalized event and organizer notifications for favorited records
- [x] add community moderation follow-up with reporting, blocking, blocked-post filtering, and admin report visibility

Firebase rules and the `claimArtistProfile`/`sendPersonalizedPush`/`getArtistClaimStatus`/`getMyClaimedArtists` Cloud Functions are deployed. Analyzer, Flutter tests, and Cloud Function syntax checks pass. The final ARM64 debug test APK is `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 follow-up (complete)

- [x] Show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

Keep security hardening, obfuscation, release signing and purchase/store work in v1.0+. The Label release catalog is closed in v0.99.89.

### v0.99.8 closure (2026-08-06)

v0.99.8 is complete and closed. Final ARM64 debug test APK: `build/HUHS-v0.99.8+16-arm64-debug.apk`. Completed: friend requests, push delivery and push-to-requester profile navigation; accept/reject/unfriend; live Chat role/access badges; public profiles and friends; favorite DJs/organizers on profiles with favorite news excluded; planned events and attendance; registered Chat writes; Chat author profile navigation; report management; biometric session handling; and admin role/access management. Firebase rules and the connection-request FCM trigger are deployed. Analyzer, full Flutter tests, Cloud Function syntax checks and Graphify refresh pass. v1.0 retains security hardening, obfuscation, release signing, purchase/store work and final release preparation.

### v0.99.89 - Label release catalog (complete; 2026-08-06)

v0.99.89 is complete. The Label tab is between Chat and Több and includes WordPress release records, clickable multiple artists, cover, genre, external links and preview playback. MP3/WAV uploads are temporary sources only: FFmpeg creates a maximum 60-second preview from the 30th second and the source is deleted. Full-track downloads, buying and a separate store are excluded. Future paid music sales will extend this same Label catalog.

### v0.99.90 - HUHS Vezérlőközpont bugfixek (complete; 2026-08-07)

All previous builds remain complete and closed. Newly discovered issues recorded for v0.99.90:

- [x] In native Mobile API editors for Events, DJs, Organizers and related submissions, `Mégse` safely cancels without a false error or invalid form state.
- [x] Improve editor field spacing and grouping.
- [x] Let admins select DJs by display name instead of only numeric IDs.
- [x] Remove the unrequested `Személyre szabott push` controller; general and custom push remain.
- [x] Guard the controller lifecycle and dialogs against the `_dependents.isEmpty` assertion path.
- [x] Complete the targeted UX, accessibility and layout polish pass.

The owner phone-verified the fixes. v0.99.90 is closed. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. The updated existing HUHS Mobile API package is `build/huhs-mobile-api-2.4.37.zip`.

### v0.99.8 - User profile navigation and community details (closed)

Authoritative status: WordPress Mobile API `2.4.37` is the updated package for v0.99.90; the current app build is the ARM64 debug phone-test artifact. Completed v0.99.3 TypeUI/native admin, profile crop, radio, tag/genre pagination, general push, social fields, FAQ and Label catalog remain complete.

- [x] Make each profile card in `Több -> Felhasználók` tappable and open that user's native in-app profile.
- [x] Show only favorite DJs, organizers, and events on the user profile; favorite news is excluded from this profile section.
- [ ] Stabilize planned events and attendance (`Ott leszek` / `Nem leszek ott`), persistence, participant counts and friend visibility.
- [ ] Stabilize friend request/accept/reject persistence and remove false success/error states.
- [x] Keep separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links (already implemented).
- [x] Show planned events and favorites on the user profile.
- [ ] Fix biometric enablement, false unlock errors, and once-per-open-app session behaviour.
- [ ] Complete registered/guest public-profile visibility, clickable friends, blocked-user list and report-status visibility.
- [x] Restrict Chat message editing and deletion to admins; normal users cannot edit or delete their own messages.

### v0.99.8 open fixes (including the former +3 follow-up)

- [ ] Show request display names/avatars instead of UIDs and retain connections consistently.
- [ ] Send connection-request push notifications reliably and remove false-success/false-failure errors.
- [x] Make profile favorites and planned events open their native detail screens.
- [ ] Complete admin report management with full details, resolve/close removal, delete/block actions, and no duplicate/mojibake UI.
- [ ] Provide unfriend/remove actions and context-sensitive public-profile friend controls.
- [ ] Allow registered non-admin Chat writes and open native profiles from Chat author name/avatar.
- [ ] Fix admin account-role changes.

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
- imported content must always be created as a draft for human review; never auto-publish AI output
- support two explicit modes: faithful translation for owned/licensed/partner content, and an original Hungarian summary/adaptation with source attribution for third-party reporting
- import images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image and do not hotlink or copy third-party assets automatically
- store the original source URL and attribution with the draft, keep the AI provider key server-side, and protect the fetcher against private/internal URLs, oversized responses, unsafe HTML, and timeouts

### v0.9 - Community (implemented)

Focus:

- local favorites
- allow the featured news card on Home to be marked as a favorite
- show the opened news article's title in its app-bar instead of the generic `HĂ­r` label
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
- Use Firebase Authentication and Firestore for community data, and Cloudinary for community images.
- Keep security hardening and release signing in v1.0; v0.99.8 owns friendships, attendance, public community profiles, friend-request notifications, and completed moderation/reporting. v0.99.3 owns the completed app-admin tooling and Chat moderation.
- Add a `Több`-menu user directory/search that lists registered users only and is unavailable to guests (v0.99.7).

### v1.0 - First Public Release (later)

Focus:

- stable news
- stable events
- event details
- DJ directory
- organizer directory
- clickable genre chips with a grouped discovery screen for events, DJs, and news
- paid Hardstyle Revolution music sales (later, inside the completed Label catalog)
- Hardstyle.com is an external destination only; do not scrape or import its catalog
- show configured Hardstyle.com, Beatport, Spotify and Apple Music links at the bottom of each release detail screen
- the own shop catalog may contain both Radio Edit/Radio Version and Extended/full versions when they are intentionally uploaded as separate products
- basic community features
- a purposeful Hungarian Hardstyle-branded loading animation that does not delay startup and respects reduced-motion accessibility settings
- the full HUHS-logo startup animation with a transparent/no-white background is complete
- polished Android release
- iOS preparation if ready

Confirmed community direction (v0.99.8 scope; only security/privacy remains v1.0):

- The dedicated Live Feed bottom-navigation tab is complete.
- Registered users can chat in the live feed and publish image posts.
- Live Feed/chat image posts use the direct Cloudinary upload path.
- Add Google account sign-in and user registration/onboarding.
- Users can create and manage their own community profile. Once registration exists, make the profile reachable from the top-left of Home through a circular avatar; show the profile image or a monogram fallback.
- During onboarding, users can choose an account role: DJ, organizer, or attendee/partygoer. Role changes and privileged actions require server-side authorization.
- DJ submission is visible to DJ accounts, organizer submission to organizer accounts, and both submission flows to admins; Flutter visibility is not sufficient without matching API enforcement.
- v0.99.3 provides the admin-only HUHS Vezérlőközpont with full review, approval, editing, user, trash, settings, and management access for the WordPress Mobile API, excluding only the radio provider menu. The owner admin e-mail is configured privately during deployment and must not be hardcoded into public app content.
- Registered users can claim a DJ profile only after proving control of the private or artist-owned booking e-mail stored on that profile; this is complete in v0.99.7. The Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) is never valid claim proof.
- Users can add social-media links to their profile, see the events they plan to attend, and access favorites from the profile area.
- Users can send, accept, and manage friend connections; each profile should include an `Ismerősök` list.
- Events must include `Ott leszek` and `Nem leszek ott` attendance actions.
- Event details should include an embedded map preview where platform/API constraints allow it. The fallback should open the Google Maps app when installed and otherwise open Google Maps in the browser.
- When viewing an event, show which friends are attending it.
- User profiles and friend lists should indicate whether that person plans to attend an upcoming event.
- News, events, DJs, organizers, and the Live Feed should remain readable without registration where possible. Anonymous Live Feed text posts are allowed under a generated `Unknown User ####` name, but anonymous users cannot upload images; profiles, friendships, and attendance state require authentication.
- Before implementation, define moderation, reporting, blocking, privacy, image upload/storage, retention, and account deletion rules.
- Registration and community accounts are app-only; do not add account registration or community UI to the public WordPress website.
- WordPress remains the source of truth for editorial content (news, events, DJs, organizers, and releases), while the app community backend may be a deliberately separate service optimized for authentication, real-time chat/feed data, friendships, attendance, and user uploads.
- Once app registration is available, DJ, organizer, and event submission actions and forms must be visible only to authenticated users. The submission API must also enforce authentication server-side; hiding the forms in Flutter is not sufficient.

### v0.99.99 - Annual HUHS Voting (planned before v1.0)

Confirmed annual voting direction for v0.99.99:

- Replace or complement the current WordPress voting extension with a dedicated Hungarian Hardstyle voting module and REST API.
- WordPress admin must manage each annual voting season, its opening/closing dates, status, rules, and candidates.
- Required annual categories are:
  - `Legjobb magyar hardstyle DJ – <év>`
  - `Legjobb magyar hardcore DJ – <év>`
  - `Legjobb magyar hardstyle zene – <év>`
  - `Legjobb magyar szervező – <év>`
  - `Legjobb külföldi DJ – <év>`
- Derive the displayed year from the voting season instead of requiring it to be typed into every category name.
- Admins must be able to add unlimited DJ, organizer, and track candidates per category, including the display data needed by the app (name/title, artist, image/cover/logo, and external links for tracks).
- Flutter must list active voting categories and candidates and allow votes to be submitted in-app.
- Flutter Home must show a prominent button for the active voting season; WordPress/admin configuration must be able to turn it on or off, and it must be hidden when no season is active.
- Voting should use authenticated app users when Google sign-in is available, with server-side one-user/one-vote enforcement per category unless a season explicitly defines different rules.
- Voting must require a registered, signed-in app account; guests cannot open or submit a vote. Category selection limits are 5 Hungarian hardstyle DJs, 3 Hungarian hardcore DJs, 2 Hungarian hardstyle tracks, 1 Hungarian organizer, and 3 international DJs.
- Before submitting a vote, ask separately whether the user wants the HUHS newsletter. Only an explicit yes may call the existing Mailchimp subscription flow; voting must remain independent from newsletter consent.
- The API must enforce voting windows and duplicate-vote protection server-side; Flutter validation alone is not sufficient.
- Define result visibility (`live`, `hidden until close`, or `admin only`), vote correction rules, audit data, abuse protection, and privacy before launch.
- Provide a complete private admin summary/dashboard with totals and per-category results. It must never be exposed by a public REST endpoint or displayed to normal app users.
- After a voting season closes, admins must be able to publish a separate public results summary for the app.
- Publishing results must be an explicit admin action; closing voting must not automatically expose results.
- The public summary should contain the season/year, category names, final ranking, candidate display data, and optionally vote totals or percentages according to the season settings.
- Never include voter identities, audit logs, moderation flags, suspicious-vote indicators, or other private admin data in the public results response.

The current implementation is ready for phone verification in `build/HUHS-v0.99.99+5-arm64-debug.apk`. It includes one WordPress season editor with category-level `+ Jelölt hozzáadása` fields, unlimited candidates per category, DJ and organizer candidates without Spotify/YouTube fields, Spotify/YouTube support for the Hungarian hardstyle track category, category selection limits of 5/3/2/1/3, a Home entry point with a 5-second API timeout, registered-user voting with Firestore duplicate protection, separate Mailchimp consent, and a private native admin summary. The updated existing HUHS Mobile API package is `build/huhs-mobile-api-2.4.42.zip`; Firebase Firestore rules are deployed. Final closure waits for owner phone verification.

### v1.5 - Hardstyle Revolution Store (later)

Focus:

- rewarded-ad full MP3 download at 128 kbps only
- paid 320 kbps MP3 and WAV/lossless products must use Google Play Billing; Google Pay is not the correct in-app product API
- purchase/download history if needed

## Release And Store Business Model (later, not in v0.99.89)

The later store may offer a 128 kbps full MP3 after a rewarded advertisement,
plus paid 320 kbps MP3 and WAV/lossless products. It must not offer
unadvertised or anonymous full-MP3 downloads.

Payment requirement:

- paid digital releases are purchased through Google Play Billing (not a direct Google Pay checkout) so the Android app remains Play policy compliant

Release processing:

- upload one WAV master per release
- generate only the preview derivative server-side with FFmpeg for the catalog; store derivatives remain private until a later paid-store design exists
- run conversion as a background job, never inside the upload/API request
- keep the WAV master private and expose each derivative only after its entitlement is satisfied

Paid options:

- 128 kbps MP3 after a rewarded advertisement
- 320 kbps MP3, example price `1.99 EUR`
- WAV/lossless, example price `2.99 EUR`

Example later paid-store UI structure:

- release title
- artist name
- preview player
- `Buy MP3` option for `320 kbps`, paid
- `Buy WAV` option for lossless, paid

Future release/store API fields should likely include:

- `id`
- `title`
- `artist_name`
- `cover_image`
- `preview_url`
- `release_type` (`paid`)
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

- The old empty Tickets bottom-navigation slot is now used by the completed Live Feed/Chat destination.
- Keep Home and News as the first two bottom-navigation items. Before finalizing the remaining items, define a clear importance order for primary navigation, Home content, and the More section.
- Evaluate the main user hook around immediate utility (for example, what is happening now and which event is next). Events are a strong primary-tab candidate; the DJ directory may initially live under More unless usage testing supports promoting it.
- Event data continues to come from the WordPress events API.
- Artist/DJ names and the organizer on event detail must be clickable.
- Artist and organizer event relations open dedicated API-backed profile screens and are confirmed against live data.
- Live Feed chat and image posting are already implemented and are not v1.0 future work.
- v1.0 should focus on security hardening, release signing/obfuscation, purchase/store work, and remaining public-release quality. Google sign-in, user profiles, friendships, event attendance and the release catalog preview are covered before v1.0.
- v0.99.99 should include an annual WordPress-managed Top DJ and Top Track voting API with in-app voting and an admin-controlled Home entry point.
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
Documentation note: backend package entries older than 2.4.33 are historical deployment notes; the current active package is 2.4.33.
- v0.99.3 source fix: the radio Stop action now synchronizes against the native playback service before deciding Play/Stop.
- v0.99.3 completed fix: profile images use the persisted raw Cloudinary URL and fall back to a name/e-mail monogram; persisted X/Y positioning and zoom are implemented and phone-verified.
- v0.99.3 source fix: the startup announcement is stored in WordPress and served by a public endpoint so it remains visible on every app launch until an admin disables or removes it.
- Phone verification of the v0.99.3 fixes is complete in Flutter build `0.99.3+27`.
- WordPress Mobile API `2.4.33` is active at `build/huhs-mobile-api-2.4.33.zip`; it adds the managed FAQ post type/category editor and paginated public FAQ endpoint. It is deployed and live-verified and must not be repeatedly rechecked.
- v0.99.8+2 bugfix pass (historical, superseded by the active v0.99.8+7 build): attendance records now include the validated event ID; attendance errors are surfaced; connection-request status refreshes after send; the named `hungarian-hardstyle` database push trigger `notifyConnectionRequest` is deployed; biometric enablement checks real device support; `MainActivity` uses `FlutterFragmentActivity` for `local_auth`. Current v0.99.8 friend/profile/notification and moderation fixes are closed.
