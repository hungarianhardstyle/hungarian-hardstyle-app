# Graph Report - .  (2026-08-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1901 nodes · 2628 edges · 113 communities (104 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `eb0be90c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- artists_screen.dart
- event.dart
- news_provider.dart
- release.dart
- artist.dart
- event_submission_screen.dart
- wordpress_admin_screen.dart
- genre_discovery_screen.dart
- more_screen.dart
- startup_gate.dart
- favorites_provider.dart
- organizer.dart
- artist_submission_screen.dart
- community_users_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- favorites_screen.dart
- organizer_submission_screen.dart
- RadioPlaybackService
- newsroom/app/main.py
- event_detail_screen.dart
- release_detail_screen.dart
- ConsumerState
- voting.dart
- post_embed_card.dart
- profile_submission.dart
- settings_screen.dart
- List
- radio_player_bar.dart
- label_purchase_service.dart
- html_linkifier.dart
- main_navigation.dart
- index.js
- event_submission.dart
- tagged_news_screen.dart
- GeneratedPluginRegistrant.swift
- releases_screen.dart
- in_app_browser.dart
- push_notification_service.dart
- news_screen.dart
- mobile_ad_banner.dart
- community_post.dart
- StatelessWidget
- news_detail_screen.dart
- home_screen.dart
- organizer_detail_screen.dart
- faq_screen.dart
- organizers_screen.dart
- package.json
- static const
- package:flutter_test/flutter_test.dart
- main.dart
- package:flutter/material.dart
- wWinMain
- State
- submission_image_picker.dart
- event_card.dart
- voting_service.dart
- ios/RunnerTests/RunnerTests.swift
- voting_provider.dart
- MaterialPageRoute
- gallery_screen.dart
- voting_screen.dart
- manifest.json
- ../core/navigation/in_app_browser.dart
- hungarian-hardstyle-newsroom/app/graphics.py
- social_contact_screen.dart
- about_screen.dart
- communityServiceProvider
- AppDelegate
- faq.dart
- news_provider.dart
- _VotingScreenState
- spotify_player.dart
- widget_test.dart
- FlutterMacOS
- dart:async
- community_provider.dart
- package:flutter_riverpod/flutter_riverpod.dart
- submission_image.dart
- build
- AppDelegate
- RegisterGeneratedPlugins
- _EventSubmissionScreenState
- app_navigator.dart
- ads_provider.dart
- organizers_provider.dart
- releases_provider.dart
- donate_screen.dart
- genre_chip.dart
- OpenAPITests
- organizer_test.dart
- post_test.dart
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

## Communities (113 total, 9 thin omitted)

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

### Community 5 - "artists_screen.dart"
Cohesion: 0.05
Nodes (44): artist_detail_screen.dart, ArtistListQuery get, Artist, artistDetailProvider, ArtistListQuery, artistsProvider, getArtist, getArtists (+36 more)

### Community 6 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 7 - "news_provider.dart"
Cohesion: 0.05
Nodes (42): FormState, categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading (+34 more)

### Community 8 - "release.dart"
Cohesion: 0.05
Nodes (36): AudioPlayer, Duration, artists, available, coverUrl, fromJson, genre, HuhsRelease (+28 more)

### Community 9 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 10 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 11 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (33): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+25 more)

### Community 12 - "genre_discovery_screen.dart"
Cohesion: 0.06
Nodes (31): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+23 more)

### Community 13 - "more_screen.dart"
Cohesion: 0.06
Nodes (30): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, _callback, createState (+22 more)

### Community 14 - "startup_gate.dart"
Cohesion: 0.07
Nodes (28): AnimationController, BrandLoadingIndicator, _BrandLoadingIndicatorState, build, _controller, createState, didChangeDependencies, dispose (+20 more)

### Community 15 - "favorites_provider.dart"
Cohesion: 0.07
Nodes (29): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+21 more)

### Community 16 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 17 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 18 - "community_users_screen.dart"
Cohesion: 0.07
Nodes (27): DocumentSnapshot, _action, CommunityUsersScreen, _CommunityUsersScreenState, connectionData, _connectionStatus, createState, data (+19 more)

### Community 19 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 20 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 21 - "favorites_screen.dart"
Cohesion: 0.10
Nodes (24): ../artists/artist_detail_screen.dart, ConsumerWidget, ../events/event_detail_screen.dart, communityAuthProvider, eventsProvider, FavoriteKind, favoritesProvider, _PostAuthorAvatar (+16 more)

### Community 22 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 23 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 24 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 25 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 26 - "release_detail_screen.dart"
Cohesion: 0.09
Nodes (22): createState, dispose, _download, initState, _label, _loadProducts, _message, _productCard (+14 more)

### Community 27 - "ConsumerState"
Cohesion: 0.15
Nodes (22): communityAuthProvider, communityPostsProvider, communityServiceProvider, ConsumerState, ConsumerStatefulWidget, build, CommunityAdminScreen, _CommunityAdminScreenState (+14 more)

### Community 28 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 29 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 30 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 31 - "settings_screen.dart"
Cohesion: 0.09
Nodes (21): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+13 more)

### Community 32 - "List"
Cohesion: 0.12
Nodes (18): ../core/content/date_formatters.dart, favorite_button.dart, PostShortcode, build, FeaturedNewsCard, post, build, NewsCard (+10 more)

### Community 33 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 34 - "label_purchase_service.dart"
Cohesion: 0.10
Nodes (19): InAppPurchase, buy, dispose, getDownloadUrl, LabelPurchaseService, listen, loadProducts, _loadRewarded (+11 more)

### Community 35 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 36 - "main_navigation.dart"
Cohesion: 0.11
Nodes (18): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, build, createState, _currentIndex, MainNavigation, _MainNavigationState (+10 more)

### Community 37 - "index.js"
Cohesion: 0.11
Nodes (14): admin, callWindows, crypto, db, { defineSecret }, functions, { getFirestore }, { google } (+6 more)

### Community 38 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 39 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 40 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.11
Nodes (17): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+9 more)

### Community 41 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): HuhsRelease, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 42 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 43 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 44 - "news_screen.dart"
Cohesion: 0.15
Nodes (16): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+8 more)

### Community 45 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 46 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 47 - "StatelessWidget"
Cohesion: 0.12
Nodes (16): _Composer, _PostAuthorLabels, _ProfileAvatar, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen, CommunityReportsScreen, _ConnectionRequestTile (+8 more)

### Community 48 - "news_detail_screen.dart"
Cohesion: 0.13
Nodes (13): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, build, _formatDate, NewsDetailScreen, post (+5 more)

### Community 49 - "home_screen.dart"
Cohesion: 0.14
Nodes (14): _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews, _page (+6 more)

### Community 50 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+5 more)

### Community 51 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 52 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError, OrganizersScreen (+5 more)

### Community 53 - "package.json"
Cohesion: 0.15
Nodes (12): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, googleapis, engines, node (+4 more)

### Community 54 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 55 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.15
Nodes (9): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/profile_submission.dart, main, main, main (+1 more)

### Community 56 - "main.dart"
Cohesion: 0.17
Nodes (11): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+3 more)

### Community 57 - "package:flutter/material.dart"
Cohesion: 0.17
Nodes (10): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, build, PrivacyScreen, package:flutter/material.dart (+2 more)

### Community 58 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 59 - "State"
Cohesion: 0.23
Nodes (12): GalleryScreen, _GalleryScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, SettingsScreen, _SettingsScreenState, PostEmbedCard, _PostEmbedCardState (+4 more)

### Community 60 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 61 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 62 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, package:cloud_firestore/cloud_firestore.dart (+2 more)

### Community 63 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.22
Nodes (7): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTest, XCTestCase

### Community 64 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 65 - "MaterialPageRoute"
Cohesion: 0.18
Nodes (11): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _openLink (+3 more)

### Community 66 - "gallery_screen.dart"
Cohesion: 0.18
Nodes (10): build, _controller, createState, _current, dispose, images, initialIndex, initState (+2 more)

### Community 67 - "voting_screen.dart"
Cohesion: 0.18
Nodes (10): _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent, _selected, _voted (+2 more)

### Community 68 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 69 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.20
Nodes (8): ../core/navigation/in_app_browser.dart, build, RadioProviderScreen, build, _openSpotify, _playlists, SpotifyPlaylistsScreen, package:url_launcher/url_launcher.dart

### Community 70 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 71 - "social_contact_screen.dart"
Cohesion: 0.20
Nodes (9): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value (+1 more)

### Community 72 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 73 - "communityServiceProvider"
Cohesion: 0.22
Nodes (9): communityServiceProvider, _editCustomResource, _editStartup, _load, _sendPersonalizedPush, WordPressAdminScreen, _WordPressAdminScreenState, _submit (+1 more)

### Community 74 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 75 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 76 - "news_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 77 - "_VotingScreenState"
Cohesion: 0.29
Nodes (7): wordpressServiceProvider, votingServiceProvider, _vote, VotingScreen, _VotingScreenState, VotingService, ../services/voting_service.dart

### Community 78 - "spotify_player.dart"
Cohesion: 0.25
Nodes (7): build, _controller, createState, _expanded, initState, package:webview_flutter/webview_flutter.dart, WebViewController

### Community 79 - "widget_test.dart"
Cohesion: 0.25
Nodes (7): package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/voting.dart, package:hungarian_hardstyle_app/providers/ads_provider.dart, package:hungarian_hardstyle_app/providers/events_provider.dart, package:hungarian_hardstyle_app/providers/news_provider.dart, package:hungarian_hardstyle_app/providers/voting_provider.dart, main

### Community 80 - "FlutterMacOS"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 81 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 82 - "community_provider.dart"
Cohesion: 0.29
Nodes (6): communityPostsProvider, watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 83 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.29
Nodes (5): package:flutter_riverpod/flutter_riverpod.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/widgets/event_card.dart, main, main

### Community 84 - "submission_image.dart"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 85 - "build"
Cohesion: 0.47
Nodes (6): eventsProvider, _openPlannedEvent, build, HomeScreen, newsProvider, votingProvider

### Community 86 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 87 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 88 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 89 - "app_navigator.dart"
Cohesion: 0.40
Nodes (4): appNavigatorKey, appScaffoldMessengerKey, NavigatorState, ScaffoldMessengerState

### Community 90 - "ads_provider.dart"
Cohesion: 0.40
Nodes (4): enableTestAds, productionAdMobAppId, productionBannerAdUnitId, productionRewardedAdUnitId

### Community 91 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 92 - "releases_provider.dart"
Cohesion: 0.40
Nodes (4): ReleaseQuery, releasesProvider, ../models/release.dart, typedef

### Community 93 - "donate_screen.dart"
Cohesion: 0.40
Nodes (4): build, DonateScreen, _donateUri, static final

### Community 94 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

## Knowledge Gaps
- **1131 isolated node(s):** `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate`, `output`, `blockedTags` (+1126 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_LiveFeedScreenState` connect `ConsumerState` to `community_screen.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `build` connect `ConsumerState` to `community_screen.dart`, `MaterialPageRoute`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `HuhsEvent` connect `event_card.dart` to `event_detail_screen.dart`, `event.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate` to the rest of the system?**
  _1131 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._