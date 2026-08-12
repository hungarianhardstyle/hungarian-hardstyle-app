# Graph Report - .  (2026-08-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1914 nodes · 2647 edges · 106 communities (98 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `238b4a98`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- release_detail_screen.dart
- community_users_screen.dart
- event_submission_screen.dart
- event.dart
- wordpress_admin_screen.dart
- label_purchase_service.dart
- artist.dart
- artist_submission_screen.dart
- widget_test.dart
- more_screen.dart
- artist_detail_screen.dart
- about_screen.dart
- organizer.dart
- genre_discovery_screen.dart
- artists_screen.dart
- news_provider.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- favorites_provider.dart
- organizer_submission_screen.dart
- RadioPlaybackService
- post_embed_card.dart
- release.dart
- newsroom/app/main.py
- ConsumerState
- event_detail_screen.dart
- voting.dart
- profile_submission.dart
- settings_screen.dart
- events_screen.dart
- organizer_detail_screen.dart
- radio_player_bar.dart
- html_linkifier.dart
- index.js
- event_submission.dart
- tagged_news_screen.dart
- GeneratedPluginRegistrant.swift
- main_navigation.dart
- in_app_browser.dart
- news_screen.dart
- push_notification_service.dart
- community_post.dart
- MaterialPageRoute
- startup_gate.dart
- release_preview_player.dart
- home_screen.dart
- newsletter_screen.dart
- voting_screen.dart
- organizers_screen.dart
- faq_screen.dart
- main.dart
- package.json
- State
- kozponti-cegregiszter.php
- package:cached_network_image/cached_network_image.dart
- wWinMain
- submission_image_picker.dart
- event_card.dart
- voting_service.dart
- ios/RunnerTests/RunnerTests.swift
- voting_provider.dart
- gallery_screen.dart
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- spotify_player.dart
- brand_loading_indicator.dart
- List
- package:flutter/material.dart
- AppDelegate
- faq.dart
- image_saver.dart
- FlutterMacOS
- dart:async
- package:flutter_riverpod/flutter_riverpod.dart
- community_provider.dart
- organizers_provider.dart
- submission_image.dart
- AppDelegate
- RegisterGeneratedPlugins
- favorite_button.dart
- app_navigator.dart
- static const
- donate_screen.dart
- OpenAPITests
- wordpressServiceProvider
- FavoritesNotifier
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

## Communities (106 total, 8 thin omitted)

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

### Community 5 - "release_detail_screen.dart"
Cohesion: 0.05
Nodes (44): HuhsRelease, ReleaseQuery, releasesProvider, createState, dispose, _download, _downloadVariant, initState (+36 more)

### Community 6 - "community_users_screen.dart"
Cohesion: 0.05
Nodes (44): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _ArtistLinks, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen (+36 more)

### Community 7 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (43): formatEventDate, formatHungarianDate, eventSubmissionGenresProvider, _addressController, build, _cityController, createState, _descriptionController (+35 more)

### Community 8 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 9 - "wordpress_admin_screen.dart"
Cohesion: 0.05
Nodes (42): communityServiceProvider, _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState (+34 more)

### Community 10 - "label_purchase_service.dart"
Cohesion: 0.05
Nodes (38): BannerAd?, dart:convert, InAppPurchase, int?, adsEnabledProvider, enableTestAds, productionAdMobAppId, productionBannerAdUnitId (+30 more)

### Community 11 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 12 - "artist_submission_screen.dart"
Cohesion: 0.06
Nodes (32): profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, _background, _biography, _bookingEmail, _bookingViaHuhs, build (+24 more)

### Community 13 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 14 - "more_screen.dart"
Cohesion: 0.06
Nodes (30): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, _callback, createState (+22 more)

### Community 15 - "artist_detail_screen.dart"
Cohesion: 0.07
Nodes (28): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen (+20 more)

### Community 16 - "about_screen.dart"
Cohesion: 0.08
Nodes (26): ../core/navigation/in_app_browser.dart, IconData, AboutScreen, build, icon, _InfoTile, label, onTap (+18 more)

### Community 17 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 18 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (29): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+21 more)

### Community 19 - "artists_screen.dart"
Cohesion: 0.08
Nodes (27): artist_detail_screen.dart, ArtistListQuery get, ArtistListQuery, artistsProvider, getArtist, getArtists, service, artist (+19 more)

### Community 20 - "news_provider.dart"
Cohesion: 0.07
Nodes (28): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+20 more)

### Community 21 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 22 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 23 - "favorites_provider.dart"
Cohesion: 0.07
Nodes (26): _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId, dispose, entries (+18 more)

### Community 24 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 25 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 26 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (23): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+15 more)

### Community 27 - "release.dart"
Cohesion: 0.08
Nodes (23): artists, audioStatus, available, coverUrl, fromJson, genre, HuhsRelease, id (+15 more)

### Community 28 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 29 - "ConsumerState"
Cohesion: 0.15
Nodes (22): communityAuthProvider, communityPostsProvider, communityServiceProvider, ConsumerState, ConsumerStatefulWidget, build, CommunityAdminScreen, _CommunityAdminScreenState (+14 more)

### Community 30 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (21): Future, HuhsEvent get, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState, _descriptionHtml (+13 more)

### Community 31 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 32 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 33 - "settings_screen.dart"
Cohesion: 0.09
Nodes (21): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+13 more)

### Community 34 - "events_screen.dart"
Cohesion: 0.11
Nodes (19): ../artists/artist_detail_screen.dart, event_submission_screen.dart, ../events/event_detail_screen.dart, communityAuthProvider, eventsProvider, build, _EventsHeader, EventsScreen (+11 more)

### Community 35 - "organizer_detail_screen.dart"
Cohesion: 0.11
Nodes (20): ConsumerWidget, favoritesProvider, organizerDetailProvider, _PostAuthorAvatar, build, build, _descriptionHtml, _escapeHtml (+12 more)

### Community 36 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 37 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 38 - "index.js"
Cohesion: 0.11
Nodes (14): admin, callWindows, crypto, db, { defineSecret }, functions, { getFirestore }, { google } (+6 more)

### Community 39 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 40 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 41 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.11
Nodes (17): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+9 more)

### Community 42 - "main_navigation.dart"
Cohesion: 0.12
Nodes (17): events/events_screen.dart, home/home_screen.dart, build, createState, _currentIndex, MainNavigation, _MainNavigationState, _navigatorKeys (+9 more)

### Community 43 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 44 - "news_screen.dart"
Cohesion: 0.14
Nodes (17): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+9 more)

### Community 45 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 46 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 47 - "MaterialPageRoute"
Cohesion: 0.15
Nodes (16): eventsProvider, _openAuthorProfile, _openPlannedEvent, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent (+8 more)

### Community 48 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 49 - "release_preview_player.dart"
Cohesion: 0.14
Nodes (14): AudioPlayer, Duration, ReleaseTrack, build, createState, dispose, index, initState (+6 more)

### Community 50 - "home_screen.dart"
Cohesion: 0.14
Nodes (14): community/community_screen.dart, _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews (+6 more)

### Community 51 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 52 - "voting_screen.dart"
Cohesion: 0.15
Nodes (14): votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent, _selected (+6 more)

### Community 53 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError (+5 more)

### Community 54 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 55 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 56 - "package.json"
Cohesion: 0.15
Nodes (12): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, googleapis, engines, node (+4 more)

### Community 57 - "State"
Cohesion: 0.22
Nodes (13): GalleryScreen, _GalleryScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, SettingsScreen, _SettingsScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState (+5 more)

### Community 58 - "kozponti-cegregiszter.php"
Cohesion: 0.24
Nodes (6): kcr_fields(), kcr_item(), kcr_meta_box_html(), kcr_routes(), kcr_save(), kcr_schema()

### Community 59 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 60 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 61 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 62 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 63 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, VotingService (+2 more)

### Community 64 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.22
Nodes (7): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTest, XCTestCase

### Community 65 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 66 - "gallery_screen.dart"
Cohesion: 0.18
Nodes (10): build, _controller, createState, _current, dispose, images, initialIndex, initState (+2 more)

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

### Community 71 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../models/post.dart

### Community 72 - "package:flutter/material.dart"
Cohesion: 0.22
Nodes (7): build, PrivacyScreen, build, genre, GenreChip, package:flutter/material.dart, ../screens/genres/genre_discovery_screen.dart

### Community 73 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 74 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 75 - "image_saver.dart"
Cohesion: 0.25
Nodes (7): _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart, static final Dio

### Community 76 - "FlutterMacOS"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 77 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 78 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.29
Nodes (5): ProfileSubmissionOptions, ../models/profile_submission.dart, news_provider.dart, package:flutter_riverpod/flutter_riverpod.dart, ../services/voting_service.dart

### Community 79 - "community_provider.dart"
Cohesion: 0.29
Nodes (6): communityPostsProvider, watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 80 - "organizers_provider.dart"
Cohesion: 0.29
Nodes (6): getOrganizer, getOrganizers, organizersProvider, service, build, ../models/organizer.dart

### Community 81 - "submission_image.dart"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 82 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 83 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 84 - "favorite_button.dart"
Cohesion: 0.33
Nodes (5): FavoriteKind, id, kind, title, ../providers/favorites_provider.dart

### Community 85 - "app_navigator.dart"
Cohesion: 0.40
Nodes (4): appNavigatorKey, appScaffoldMessengerKey, NavigatorState, ScaffoldMessengerState

### Community 86 - "static const"
Cohesion: 0.40
Nodes (4): AppTheme, backgroundDecoration, package:google_fonts/google_fonts.dart, static const

### Community 87 - "donate_screen.dart"
Cohesion: 0.40
Nodes (4): build, DonateScreen, _donateUri, static final

### Community 89 - "wordpressServiceProvider"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

## Knowledge Gaps
- **1133 isolated node(s):** `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate`, `output`, `blockedTags` (+1128 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_LiveFeedScreenState` connect `ConsumerState` to `community_screen.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `build` connect `ConsumerState` to `community_screen.dart`, `MaterialPageRoute`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `HuhsEvent` connect `event_card.dart` to `event.dart`, `event_detail_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate` to the rest of the system?**
  _1133 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._