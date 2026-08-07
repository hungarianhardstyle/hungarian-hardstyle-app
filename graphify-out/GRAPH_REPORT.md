# Graph Report - .  (2026-08-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1770 nodes · 2460 edges · 109 communities (100 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f10ed5c2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- post.dart
- event.dart
- favorites_provider.dart
- community_users_screen.dart
- artist.dart
- wordpress_admin_screen.dart
- event_submission_screen.dart
- organizer.dart
- genre_discovery_screen.dart
- artist_submission_screen.dart
- news_provider.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- organizer_submission_screen.dart
- more_screen.dart
- RadioPlaybackService
- post_embed_card.dart
- settings_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- event_detail_screen.dart
- profile_submission.dart
- radio_player_bar.dart
- about_screen.dart
- html_linkifier.dart
- package:flutter/material.dart
- event_submission.dart
- tagged_news_screen.dart
- push_notification_service.dart
- main_navigation.dart
- in_app_browser.dart
- artist_detail_screen.dart
- news_screen.dart
- releases_screen.dart
- GeneratedPluginRegistrant.swift
- MaterialPageRoute
- mobile_ad_banner.dart
- communityServiceProvider
- news_detail_screen.dart
- community_post.dart
- index.js
- organizers_screen.dart
- startup_gate.dart
- release_preview_player.dart
- newsletter_screen.dart
- release.dart
- ConsumerState
- organizer_detail_screen.dart
- faq_screen.dart
- home_screen.dart
- main.dart
- gallery_screen.dart
- package:flutter_test/flutter_test.dart
- featured_news_card.dart
- wWinMain
- submission_image_picker.dart
- event_card.dart
- package.json
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- artists_provider.dart
- community_provider.dart
- spotify_player.dart
- brand_loading_indicator.dart
- package:cached_network_image/cached_network_image.dart
- package:flutter_riverpod/flutter_riverpod.dart
- State
- FlutterMacOS
- events_screen.dart
- AppDelegate
- faq.dart
- List
- profile_submission_provider.dart
- image_saver.dart
- favorites_screen.dart
- dart:async
- ios/RunnerTests/RunnerTests.swift
- SubmissionImage
- AppDelegate
- event_card_test.dart
- ../core/navigation/in_app_browser.dart
- app_navigator.dart
- static const
- organizers_provider.dart
- RegisterGeneratedPlugins
- _EventSubmissionScreenState
- OpenAPITests
- _GenreDiscoveryScreenState
- post_test.dart
- profile_submission_test.dart
- hungarian-hardstyle-newsroom/app/__init__.py
- newsroom/app/__init__.py
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- hungarian-hardstyle-newsroom
- String?

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `communityServiceProvider` - 21 edges
3. `RadioPlaybackService` - 15 edges
4. `MessageHandler` - 12 edges
5. `update_metadata()` - 11 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `eventsProvider` - 9 edges
10. `MessageHandler` - 9 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `build` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_CommunityAdminScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_CommunityProfileScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (109 total, 9 thin omitted)

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
Nodes (49): Dio, _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback (+41 more)

### Community 4 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 5 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 6 - "favorites_provider.dart"
Cohesion: 0.05
Nodes (42): ChangeNotifier, dart:convert, FirebaseAuth, FirebaseFirestore, _auth, _authSubscription, clearAll, _clearCloud (+34 more)

### Community 7 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (41): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+33 more)

### Community 8 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 9 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (36): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+28 more)

### Community 10 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 11 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 12 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (29): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+21 more)

### Community 13 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 14 - "news_provider.dart"
Cohesion: 0.07
Nodes (27): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+19 more)

### Community 15 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 16 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 17 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (24): class, build, _city, _contactEmail, _country, createState, _description, dispose (+16 more)

### Community 18 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 19 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 20 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (23): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+15 more)

### Community 21 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 22 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 23 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 24 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 25 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 26 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 27 - "about_screen.dart"
Cohesion: 0.11
Nodes (18): IconData, AboutScreen, build, icon, _InfoTile, label, onTap, value (+10 more)

### Community 28 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (14): build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen, build (+6 more)

### Community 30 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 31 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 32 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (18): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+10 more)

### Community 33 - "main_navigation.dart"
Cohesion: 0.12
Nodes (17): events/events_screen.dart, home/home_screen.dart, build, createState, _currentIndex, MainNavigation, _MainNavigationState, _navigatorKeys (+9 more)

### Community 34 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 35 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 36 - "news_screen.dart"
Cohesion: 0.14
Nodes (17): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+9 more)

### Community 37 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): releasesProvider, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 38 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 39 - "MaterialPageRoute"
Cohesion: 0.14
Nodes (17): eventsProvider, newsProvider, _openAuthorProfile, _openPlannedEvent, _openProfile, _readOnlyProfileWidgets, build, _artistContent (+9 more)

### Community 40 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 41 - "communityServiceProvider"
Cohesion: 0.17
Nodes (16): ConsumerWidget, communityAuthProvider, communityServiceProvider, CommunityAvatarButton, _delete, _moderateUser, _PostAuthorAvatar, _editCustomResource (+8 more)

### Community 42 - "news_detail_screen.dart"
Cohesion: 0.12
Nodes (14): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, build, _formatDate, NewsDetailScreen, _openLink (+6 more)

### Community 43 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 44 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 45 - "organizers_screen.dart"
Cohesion: 0.14
Nodes (15): organizersProvider, build, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard (+7 more)

### Community 46 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 47 - "release_preview_player.dart"
Cohesion: 0.14
Nodes (14): AudioPlayer, Duration, ReleaseTrack, build, createState, dispose, index, initState (+6 more)

### Community 48 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 49 - "release.dart"
Cohesion: 0.13
Nodes (14): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+6 more)

### Community 50 - "ConsumerState"
Cohesion: 0.20
Nodes (14): ConsumerState, ConsumerStatefulWidget, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _PostCard, _PostCardState (+6 more)

### Community 51 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+5 more)

### Community 52 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 53 - "home_screen.dart"
Cohesion: 0.17
Nodes (12): community/community_screen.dart, _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews (+4 more)

### Community 54 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 55 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 56 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.15
Nodes (9): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, main, main, main (+1 more)

### Community 57 - "featured_news_card.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 58 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 59 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 60 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 61 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 62 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 63 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 64 - "artists_provider.dart"
Cohesion: 0.20
Nodes (8): ArtistListQuery, getArtist, getArtists, service, ReleaseQuery, ../models/artist.dart, ../models/release.dart, typedef

### Community 65 - "community_provider.dart"
Cohesion: 0.20
Nodes (9): communityPostsProvider, watch, build, LiveFeedScreen, _LiveFeedScreenState, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart (+1 more)

### Community 66 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 67 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 68 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.22
Nodes (8): HuhsRelease, build, _label, release, ReleaseDetailScreen, package:cached_network_image/cached_network_image.dart, releases_screen.dart, ../../widgets/release_preview_player.dart

### Community 69 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.22
Nodes (7): enableTestAds, package:flutter_riverpod/flutter_riverpod.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/providers/ads_provider.dart, package:hungarian_hardstyle_app/providers/events_provider.dart, package:hungarian_hardstyle_app/providers/news_provider.dart, main

### Community 70 - "State"
Cohesion: 0.31
Nodes (9): CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, StartupGate, _StartupGateState, SingleTickerProviderStateMixin, State (+1 more)

### Community 71 - "FlutterMacOS"
Cohesion: 0.32
Nodes (4): Cocoa, FlutterMacOS, RunnerTests, XCTest

### Community 72 - "events_screen.dart"
Cohesion: 0.25
Nodes (7): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, ../../widgets/event_card.dart

### Community 73 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 74 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 75 - "List"
Cohesion: 0.25
Nodes (7): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List

### Community 76 - "profile_submission_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 77 - "image_saver.dart"
Cohesion: 0.25
Nodes (7): _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart, static final Dio

### Community 78 - "favorites_screen.dart"
Cohesion: 0.29
Nodes (6): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, _label, ../news/news_detail_screen.dart, ../organizers/organizer_detail_screen.dart, ../../providers/events_provider.dart

### Community 79 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 80 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.24
Nodes (6): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTestCase

### Community 81 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 82 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 83 - "event_card_test.dart"
Cohesion: 0.33
Nodes (4): package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/widgets/event_card.dart, main, main

### Community 84 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.33
Nodes (5): ../core/navigation/in_app_browser.dart, build, _openSpotify, _playlists, SpotifyPlaylistsScreen

### Community 85 - "app_navigator.dart"
Cohesion: 0.40
Nodes (4): appNavigatorKey, appScaffoldMessengerKey, NavigatorState, ScaffoldMessengerState

### Community 86 - "static const"
Cohesion: 0.40
Nodes (4): AppTheme, backgroundDecoration, package:google_fonts/google_fonts.dart, static const

### Community 87 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 89 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 90 - "_EventSubmissionScreenState"
Cohesion: 0.50
Nodes (4): eventSubmissionGenresProvider, build, EventSubmissionScreen, _EventSubmissionScreenState

### Community 92 - "_GenreDiscoveryScreenState"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

## Knowledge Gaps
- **1039 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1034 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CommunityService` connect `community_provider.dart` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `SubmissionImage` connect `SubmissionImage` to `community_screen.dart`, `event_submission_screen.dart`, `artist_submission_screen.dart`, `organizer_submission_screen.dart`, `submission_image_picker.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artist.dart`, `artists_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1039 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._