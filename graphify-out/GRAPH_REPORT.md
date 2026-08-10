# Graph Report - .  (2026-08-10)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1835 nodes · 2556 edges · 103 communities (96 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d459444d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- post.dart
- news_provider.dart
- event.dart
- community_users_screen.dart
- artist.dart
- event_submission_screen.dart
- home_screen.dart
- artist_submission_screen.dart
- wordpress_admin_screen.dart
- widget_test.dart
- genre_discovery_screen.dart
- favorites_provider.dart
- organizer.dart
- organizer_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- favorites_screen.dart
- more_screen.dart
- RadioPlaybackService
- main_navigation.dart
- settings_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- event_detail_screen.dart
- voting.dart
- post_embed_card.dart
- profile_submission.dart
- communityServiceProvider
- radio_player_bar.dart
- about_screen.dart
- html_linkifier.dart
- ConsumerState
- event_submission.dart
- releases_screen.dart
- artist_detail_screen.dart
- voting_screen.dart
- push_notification_service.dart
- GeneratedPluginRegistrant.swift
- package:flutter_riverpod/flutter_riverpod.dart
- organizers_screen.dart
- mobile_ad_banner.dart
- community_post.dart
- index.js
- in_app_browser.dart
- startup_gate.dart
- release_preview_player.dart
- news_detail_screen.dart
- organizer_detail_screen.dart
- release.dart
- newsletter_screen.dart
- package:cached_network_image/cached_network_image.dart
- State
- gallery_screen.dart
- package:flutter/material.dart
- faq_screen.dart
- main.dart
- wWinMain
- static const
- event_card.dart
- package.json
- voting_service.dart
- voting_provider.dart
- MaterialPageRoute
- submission_image_picker.dart
- manifest.json
- ios/RunnerTests/RunnerTests.swift
- hungarian-hardstyle-newsroom/app/graphics.py
- spotify_player.dart
- brand_loading_indicator.dart
- FlutterMacOS
- events_screen.dart
- AppDelegate
- faq.dart
- List
- release_detail_screen.dart
- image_saver.dart
- dart:async
- AppDelegate
- RegisterGeneratedPlugins
- submission_image.dart
- releases_provider.dart
- genre_chip.dart
- OpenAPITests
- hungarian-hardstyle-newsroom/app/__init__.py
- newsroom/app/__init__.py
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- hungarian-hardstyle-newsroom
- String?
- RunnerTests

## God Nodes (most connected - your core abstractions)
1. `communityServiceProvider` - 23 edges
2. `Win32Window` - 22 edges
3. `RadioPlaybackService` - 15 edges
4. `MessageHandler` - 12 edges
5. `update_metadata()` - 11 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `MessageHandler` - 9 edges
10. `create_draft()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `_CommunityAdminScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_CommunityProfileScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_delete` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (103 total, 7 thin omitted)

### Community 0 - "community_service.dart"
Cohesion: 0.02
Nodes (85): accessAdmin, accessModerator, accessNone, accountRole, adminBlockUser, adminEmail, _anonymousNumber, _attendance (+77 more)

### Community 1 - "community_screen.dart"
Cohesion: 0.02
Nodes (82): CommunityService get, dart:math, _anonymous, _authSubscription, _avatarFocusX, _avatarFocusY, _avatarLetter, _avatarPanX (+74 more)

### Community 2 - "Win32Window"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 3 - "wordpress_service.dart"
Cohesion: 0.04
Nodes (50): Dio, _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback (+42 more)

### Community 4 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 5 - "news_provider.dart"
Cohesion: 0.04
Nodes (46): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+38 more)

### Community 6 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 7 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (41): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+33 more)

### Community 8 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 9 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 10 - "home_screen.dart"
Cohesion: 0.07
Nodes (34): eventsProvider, paginatedNewsProvider, build, _controller, createState, dispose, HomeScreen, initState (+26 more)

### Community 11 - "artist_submission_screen.dart"
Cohesion: 0.06
Nodes (33): SubmissionImage, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, _background, _biography, _bookingEmail, _bookingViaHuhs (+25 more)

### Community 12 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (33): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+25 more)

### Community 13 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 14 - "genre_discovery_screen.dart"
Cohesion: 0.06
Nodes (31): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+23 more)

### Community 15 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (30): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+22 more)

### Community 16 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 17 - "organizer_submission_screen.dart"
Cohesion: 0.07
Nodes (30): class, FormState, build, _city, _contactEmail, _country, createState, _description (+22 more)

### Community 18 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 19 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 20 - "favorites_screen.dart"
Cohesion: 0.10
Nodes (24): ../artists/artist_detail_screen.dart, ConsumerWidget, ../events/event_detail_screen.dart, eventsProvider, FavoriteKind, favoritesProvider, _openPlannedEvent, _PostAuthorAvatar (+16 more)

### Community 21 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 22 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 23 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 24 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 25 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 26 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 27 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 28 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 29 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 30 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 31 - "communityServiceProvider"
Cohesion: 0.12
Nodes (20): communityAuthProvider, communityPostsProvider, communityServiceProvider, watch, build, CommunityAvatarButton, _delete, _moderateUser (+12 more)

### Community 32 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 33 - "about_screen.dart"
Cohesion: 0.11
Nodes (18): IconData, AboutScreen, build, icon, _InfoTile, label, onTap, value (+10 more)

### Community 34 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 35 - "ConsumerState"
Cohesion: 0.15
Nodes (19): ConsumerState, ConsumerStatefulWidget, eventSubmissionGenresProvider, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, LiveFeedScreen (+11 more)

### Community 36 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 37 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): HuhsRelease, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 38 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 39 - "voting_screen.dart"
Cohesion: 0.13
Nodes (16): wordpressServiceProvider, votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent (+8 more)

### Community 40 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 41 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 42 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.13
Nodes (13): ProfileSubmissionOptions, enableTestAds, ArtistListQuery, getArtist, getArtists, service, getOrganizer, getOrganizers (+5 more)

### Community 43 - "organizers_screen.dart"
Cohesion: 0.13
Nodes (16): organizersProvider, build, build, createState, dispose, onRetry, _onSearchChanged, organizer (+8 more)

### Community 44 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 45 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 46 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 47 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 48 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 49 - "release_preview_player.dart"
Cohesion: 0.14
Nodes (14): AudioPlayer, Duration, ReleaseTrack, build, createState, dispose, index, initState (+6 more)

### Community 50 - "news_detail_screen.dart"
Cohesion: 0.13
Nodes (13): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, build, _formatDate, NewsDetailScreen, post (+5 more)

### Community 51 - "organizer_detail_screen.dart"
Cohesion: 0.14
Nodes (14): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+6 more)

### Community 52 - "release.dart"
Cohesion: 0.14
Nodes (13): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+5 more)

### Community 53 - "newsletter_screen.dart"
Cohesion: 0.15
Nodes (13): build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl, NewsletterScreen (+5 more)

### Community 54 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (11): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+3 more)

### Community 55 - "State"
Cohesion: 0.22
Nodes (13): InAppBrowserScreen, _InAppBrowserScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, PostEmbedCard, _PostEmbedCardState (+5 more)

### Community 56 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 57 - "package:flutter/material.dart"
Cohesion: 0.17
Nodes (10): build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen, package:flutter/material.dart (+2 more)

### Community 58 - "faq_screen.dart"
Cohesion: 0.19
Nodes (12): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+4 more)

### Community 59 - "main.dart"
Cohesion: 0.17
Nodes (11): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+3 more)

### Community 60 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 61 - "static const"
Cohesion: 0.18
Nodes (9): ../core/navigation/in_app_browser.dart, AppTheme, backgroundDecoration, build, _openSpotify, _playlists, SpotifyPlaylistsScreen, package:google_fonts/google_fonts.dart (+1 more)

### Community 62 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 63 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 64 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, package:cloud_firestore/cloud_firestore.dart (+2 more)

### Community 65 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 66 - "MaterialPageRoute"
Cohesion: 0.18
Nodes (11): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _open (+3 more)

### Community 67 - "submission_image_picker.dart"
Cohesion: 0.18
Nodes (10): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+2 more)

### Community 68 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 69 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.38
Nodes (4): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit

### Community 70 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 71 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 72 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 73 - "FlutterMacOS"
Cohesion: 0.32
Nodes (5): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow, XCTest

### Community 74 - "events_screen.dart"
Cohesion: 0.25
Nodes (7): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, ../../widgets/event_card.dart

### Community 75 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 76 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 77 - "List"
Cohesion: 0.25
Nodes (7): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List

### Community 78 - "release_detail_screen.dart"
Cohesion: 0.25
Nodes (7): HuhsRelease, build, _label, release, ReleaseDetailScreen, releases_screen.dart, ../../widgets/release_preview_player.dart

### Community 79 - "image_saver.dart"
Cohesion: 0.25
Nodes (7): _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart, static final Dio

### Community 80 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 81 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 82 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

### Community 83 - "submission_image.dart"
Cohesion: 0.40
Nodes (4): dart:typed_data, bytes, name, Uint8List

### Community 84 - "releases_provider.dart"
Cohesion: 0.40
Nodes (4): ReleaseQuery, releasesProvider, ../models/release.dart, typedef

### Community 85 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

### Community 102 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

## Knowledge Gaps
- **1075 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1070 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CommunityService` connect `communityServiceProvider` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `SubmissionImage` connect `artist_submission_screen.dart` to `community_screen.dart`, `submission_image_picker.dart`, `event_submission_screen.dart`, `organizer_submission_screen.dart`, `submission_image.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artist.dart`, `artists_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1075 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._