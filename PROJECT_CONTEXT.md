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

Future:

Upcoming Events list.

Clickable.

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

Future.

Online streaming.

Background playback.

---

# Newsletter

Mailchimp.

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

The authentication and community backend must support privacy controls, moderation, reporting, blocking, account deletion, and safe image storage.

---

# REST API

Current

/events

Future

/artists

/organizers

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

- The current Tickets tab will be removed.
- The DJ directory tab will take its place in the bottom navigation.
- By v1.0, add a dedicated Live Feed tab for community chat and image posts; the final bottom-navigation layout must be revisited when this is implemented.

Confirmed event relationship behavior:

- Event content remains managed through the WordPress API.
- Every related DJ/artist name and the organizer shown on event detail must be clickable.
- They must navigate to complete dedicated DJ and organizer profiles populated from WordPress REST APIs.
- The current name-only internal profile screens are temporary placeholders until those APIs and full profiles are implemented.

---

# More Menu

Favorites

Newsletter

Settings

Social

Contact

About

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

---

# Future Features

- Online Radio

- Hardstyle Revolution Releases

- Music Store

- Hungarian Hardstyle Top DJ Voting

- Top Track Voting

- Calendar integration

- Better search

- Recommendations

- Live Feed with chat and image posts

- Google account registration and sign-in

- Community user profiles

- Friend connections

- Event attendance (`Ott leszek` / `Nem leszek ott`)

- Friend attendance visibility on profiles and events

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

v0.4

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

- Clickable event artists and organizer with internal profile placeholders

In Progress

- Artists API

- Organizers API

- Full DJ and organizer profiles populated from their REST APIs

- Rich content: YouTube, Spotify, Instagram and TikTok embeds now render in article detail; interactive WordPress shortcodes open in an in-app web view

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
