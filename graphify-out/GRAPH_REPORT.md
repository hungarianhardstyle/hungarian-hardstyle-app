# Graph Report - .  (2026-08-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1887 nodes · 2610 edges · 97 communities (90 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0cb1356d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- genre_discovery_screen.dart
- event.dart
- home_screen.dart
- community_users_screen.dart
- wordpress_admin_screen.dart
- artist.dart
- event_submission_screen.dart
- radio_player_bar.dart
- release.dart
- more_screen.dart
- widget_test.dart
- event_card.dart
- favorites_provider.dart
- about_screen.dart
- organizer.dart
- news_provider.dart
- artist_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- favorites_screen.dart
- organizer_submission_screen.dart
- artist_detail_screen.dart
- event_detail_screen.dart
- RadioPlaybackService
- settings_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- ConsumerState
- MaterialPageRoute
- voting.dart
- post_embed_card.dart
- profile_submission.dart
- html_linkifier.dart
- event_submission.dart
- tagged_news_screen.dart
- GeneratedPluginRegistrant.swift
- index.js
- releases_screen.dart
- in_app_browser.dart
- news_screen.dart
- release_detail_screen.dart
- push_notification_service.dart
- mobile_ad_banner.dart
- community_post.dart
- label_purchase_service.dart
- voting_screen.dart
- startup_gate.dart
- organizer_detail_screen.dart
- package:flutter/material.dart
- faq_screen.dart
- package.json
- static const
- package:flutter_riverpod/flutter_riverpod.dart
- List
- main.dart
- wWinMain
- artists_provider.dart
- submission_image_picker.dart
- voting_service.dart
- ios/RunnerTests/RunnerTests.swift
- voting_provider.dart
- State
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- spotify_player.dart
- brand_loading_indicator.dart
- AppDelegate
- faq.dart
- FlutterMacOS
- dart:async
- profile_submission_provider.dart
- community_provider.dart
- submission_image.dart
- AppDelegate
- RegisterGeneratedPlugins
- _EventSubmissionScreenState
- OpenAPITests
- hungarian-hardstyle-newsroom/app/__init__.py
- newsroom/app/__init__.py
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- hungarian-hardstyle-newsroom
- String?

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `RadioPlaybackService` - 15 edges
3. `communityServiceProvider` - 12 edges
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
- `_editCustomResource` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/wordpress_admin_screen.dart → lib/providers/community_provider.dart
- `_editStartup` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/wordpress_admin_screen.dart → lib/providers/community_provider.dart
- `_load` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/wordpress_admin_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (97 total, 7 thin omitted)

### Community 0 - "community_screen.dart"
Cohesion: 0.02
Nodes (85): CommunityPost, CommunityService, CommunityService get, dart:math, _anonymous, _authSubscription, _avatarFocusX, _avatarFocusY (+77 more)

### Community 1 - "community_service.dart"
Cohesion: 0.02
Nodes (85): accessAdmin, accessModerator, accessNone, accountRole, adminBlockUser, adminEmail, _anonymousNumber, _attendance (+77 more)

### Community 2 - "Win32Window"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 3 - "wordpress_service.dart"
Cohesion: 0.04
Nodes (50): Dio, _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback (+42 more)

### Community 4 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 5 - "genre_discovery_screen.dart"
Cohesion: 0.04
Nodes (45): FormState, _artistHasMore, _artistPage, _artists, build, child, createState, dispose (+37 more)

### Community 6 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 7 - "home_screen.dart"
Cohesion: 0.05
Nodes (41): community/community_screen.dart, events/events_screen.dart, eventsProvider, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, _openPlannedEvent, build (+33 more)

### Community 8 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (42): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _ArtistLinks, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen (+34 more)

### Community 9 - "wordpress_admin_screen.dart"
Cohesion: 0.05
Nodes (42): communityServiceProvider, _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState (+34 more)

### Community 10 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 11 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 12 - "radio_player_bar.dart"
Cohesion: 0.06
Nodes (34): dart:io, organizersProvider, build, createState, dispose, onRetry, _onSearchChanged, organizer (+26 more)

### Community 13 - "release.dart"
Cohesion: 0.06
Nodes (33): AudioPlayer, Duration, artists, coverUrl, fromJson, genre, HuhsRelease, id (+25 more)

### Community 14 - "more_screen.dart"
Cohesion: 0.06
Nodes (32): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, _callback, createState (+24 more)

### Community 15 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 16 - "event_card.dart"
Cohesion: 0.08
Nodes (27): ../core/content/date_formatters.dart, double?, favorite_button.dart, genre_chip.dart, HuhsEvent, PostShortcode, build, event (+19 more)

### Community 17 - "favorites_provider.dart"
Cohesion: 0.07
Nodes (29): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+21 more)

### Community 18 - "about_screen.dart"
Cohesion: 0.08
Nodes (26): ../core/navigation/in_app_browser.dart, IconData, AboutScreen, build, icon, _InfoTile, label, onTap (+18 more)

### Community 19 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 20 - "news_provider.dart"
Cohesion: 0.07
Nodes (28): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+20 more)

### Community 21 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 22 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 23 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "favorites_screen.dart"
Cohesion: 0.10
Nodes (24): ../artists/artist_detail_screen.dart, ConsumerWidget, ../events/event_detail_screen.dart, communityAuthProvider, eventsProvider, FavoriteKind, favoritesProvider, _PostAuthorAvatar (+16 more)

### Community 25 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 26 - "artist_detail_screen.dart"
Cohesion: 0.09
Nodes (24): event_submission_screen.dart, Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId (+16 more)

### Community 27 - "event_detail_screen.dart"
Cohesion: 0.08
Nodes (24): Future, HuhsEvent get, formatEventDate, formatHungarianDate, artists, _attendanceBusy, _attendanceFuture, _attendanceState (+16 more)

### Community 28 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 29 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 30 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 31 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 32 - "ConsumerState"
Cohesion: 0.15
Nodes (22): communityAuthProvider, communityPostsProvider, communityServiceProvider, ConsumerState, ConsumerStatefulWidget, build, CommunityAdminScreen, _CommunityAdminScreenState (+14 more)

### Community 33 - "MaterialPageRoute"
Cohesion: 0.10
Nodes (21): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent (+13 more)

### Community 34 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 35 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 36 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 37 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 38 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 39 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 40 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.11
Nodes (17): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+9 more)

### Community 41 - "index.js"
Cohesion: 0.11
Nodes (13): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { google }, GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (+5 more)

### Community 42 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): HuhsRelease, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 43 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 44 - "news_screen.dart"
Cohesion: 0.14
Nodes (17): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+9 more)

### Community 45 - "release_detail_screen.dart"
Cohesion: 0.12
Nodes (17): createState, dispose, initState, _label, _loadProducts, _message, _productLabel, _products (+9 more)

### Community 46 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 47 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 48 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 49 - "label_purchase_service.dart"
Cohesion: 0.12
Nodes (15): InAppPurchase, buy, dispose, LabelPurchaseService, listen, loadProducts, purchaseUpdates, restore (+7 more)

### Community 50 - "voting_screen.dart"
Cohesion: 0.15
Nodes (15): wordpressServiceProvider, votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent (+7 more)

### Community 51 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 52 - "organizer_detail_screen.dart"
Cohesion: 0.14
Nodes (14): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+6 more)

### Community 53 - "package:flutter/material.dart"
Cohesion: 0.14
Nodes (11): build, DonateScreen, _donateUri, build, PrivacyScreen, build, genre, GenreChip (+3 more)

### Community 54 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 55 - "package.json"
Cohesion: 0.15
Nodes (12): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, googleapis, engines, node (+4 more)

### Community 56 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 57 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.15
Nodes (10): enableTestAds, productionAdMobAppId, productionBannerAdUnitId, getOrganizer, getOrganizers, service, VotingService, ../models/organizer.dart (+2 more)

### Community 58 - "List"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 59 - "main.dart"
Cohesion: 0.17
Nodes (11): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+3 more)

### Community 60 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 61 - "artists_provider.dart"
Cohesion: 0.18
Nodes (10): ArtistListQuery, getArtist, getArtists, service, ReleaseQuery, releasesProvider, ../models/artist.dart, ../models/release.dart (+2 more)

### Community 62 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 63 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, package:cloud_firestore/cloud_firestore.dart (+2 more)

### Community 64 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.22
Nodes (7): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTest, XCTestCase

### Community 65 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 66 - "State"
Cohesion: 0.25
Nodes (11): CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, PostEmbedCard, _PostEmbedCardState, StartupGate, _StartupGateState (+3 more)

### Community 67 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 68 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 69 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 70 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 71 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 72 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 73 - "FlutterMacOS"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 74 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 75 - "profile_submission_provider.dart"
Cohesion: 0.29
Nodes (6): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart

### Community 76 - "community_provider.dart"
Cohesion: 0.29
Nodes (6): communityPostsProvider, watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 77 - "submission_image.dart"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 78 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 79 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 80 - "_EventSubmissionScreenState"
Cohesion: 0.50
Nodes (4): eventSubmissionGenresProvider, build, EventSubmissionScreen, _EventSubmissionScreenState

## Knowledge Gaps
- **1118 isolated node(s):** `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate`, `output`, `blockedTags` (+1113 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_LiveFeedScreenState` connect `ConsumerState` to `community_screen.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `build` connect `ConsumerState` to `community_screen.dart`, `MaterialPageRoute`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `HuhsEvent` connect `event_card.dart` to `event_detail_screen.dart`, `event.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate` to the rest of the system?**
  _1118 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._