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
- The WordPress plugin exposes `GET /wp-json/huhs/v1/posts`.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/events`.
- Events, tickets, and more may still contain placeholder or early-stage UI.
- Dynamic events and the event detail screen are connected to the WordPress events API.
- Event detail artists and organizer are clickable and open internal profile placeholders.
- News excerpts are converted to plain text and HTML tags are removed for both custom and standard WordPress responses.
- News search uses the custom `huhs/v1/posts` endpoint so search results retain the same processed content, featured images, galleries, and embeds as the normal news flow.
- News detail renders deduplicated YouTube, Spotify, Instagram, and TikTok embeds in-app. Supported interactive WordPress shortcodes (`ays_poll`, `irp`, and legacy Final Tiles Gallery) are detected; their raw shortcode text is removed and the rendered WordPress content can be opened inside the app.
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
- `organizer`
- `artists`
- `flyer`
- `featured`
- `visible`
- `status`

The events API currently returns only published `huhs_event` posts where `visible` is truthy. It sorts featured events first, then by `start_date`.

Artist and organizer custom post types exist in WordPress, but the reviewed ZIP does not yet expose dedicated mobile REST list/detail endpoints for them. Add those endpoints before building the Flutter DJ/Organizer modules.

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
- artists list, endpoint still needed
- artist detail
- organizers list, endpoint still needed
- organizer detail
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

Flutter status: dynamic list, detail, flyer, ticket, Google Maps, and clickable artist/organizer relations are implemented. The linked profiles remain placeholders until the dedicated APIs are connected.

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

### v0.7 - Organizers

Focus:

- organizers menu
- organizer list
- organizer profile
- social links
- description
- upcoming events

### v0.8 - Rich Content

Focus:

- WordPress shortcode/rich content support
- YouTube embeds
- Spotify embeds
- TikTok embeds
- Instagram embeds
- galleries
- external link handling

### v0.9 - Community

Focus:

- local favorites
- newsletter integration
- settings
- social links
- contact/about pages
- push notification preparation

### v0.95 - Media

Focus:

- online radio
- background playback
- Hardstyle Revolution releases
- preview player
- Spotify/Hardstyle.com/YouTube links

### v1.0 - First Public Release

Focus:

- stable news
- stable events
- event details
- DJ directory
- organizer directory
- basic community features
- polished Android release
- iOS preparation if ready

### v1.5 - Hardstyle Revolution Store

Focus:

- free releases
- premium releases
- rewarded-ad download option
- paid downloads
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

English support is a future internationalization goal. Do not introduce full i18n unless the user asks for it or the roadmap reaches that step.

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

## Important Current Implementation Priorities

Likely next useful tasks:

1. Fix the default Flutter widget test so it matches `HungarianHardstyleApp`.
2. Clean up asset folder references or create the missing asset folders.
3. Set Android app label and application id before release.
4. Keep the working News API/list/detail flow intact when refactoring.
5. Improve News loading, empty, and error states if needed.
6. Improve WordPress rich content/HTML rendering for news if needed.
7. Add and connect dedicated artist list/detail REST endpoints.
8. Add and connect dedicated organizer list/detail REST endpoints.
9. Replace the event relation profile placeholders with complete API-backed DJ/organizer profiles.
10. Implement upcoming events on DJ and organizer profiles.
11. Do not bump the app version unless the user explicitly asks; the version has not intentionally changed yet.

## Agent Reminder

Before making code changes:

- inspect the relevant files
- preserve existing working behavior
- do not treat placeholders as bugs unless they block the requested task
- keep changes scoped to the requested feature
- summarize what changed and what could not be verified
