# Graph Report - .  (2026-08-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1939 nodes · 2668 edges · 120 communities (113 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 22 edges (avg confidence: 0.76)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `debae25a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- event.dart
- release.dart
- artist.dart
- event_submission_screen.dart
- wordpress_admin_screen.dart
- widget_test.dart
- more_screen.dart
- organizer.dart
- genre_discovery_screen.dart
- favorites_provider.dart
- artist_submission_screen.dart
- organizer_detail_screen.dart
- community_users_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- organizer_submission_screen.dart
- news_provider.dart
- package:flutter/material.dart
- radio_player_bar.dart
- RadioPlaybackService
- main_navigation.dart
- ConsumerState
- newsroom/app/main.py
- artists_screen.dart
- event_detail_screen.dart
- voting.dart
- post_embed_card.dart
- profile_submission.dart
- settings_screen.dart
- release_detail_screen.dart
- events_screen.dart
- kozponti-cegregiszter.php
- label_purchase_service.dart
- html_linkifier.dart
- index.js
- event_submission.dart
- GeneratedPluginRegistrant.swift
- releases_screen.dart
- in_app_browser.dart
- artist_detail_screen.dart
- push_notification_service.dart
- startup_gate.dart
- news_screen.dart
- tagged_news_screen.dart
- mobile_ad_banner.dart
- community_post.dart
- StatelessWidget
- news_detail_screen.dart
- newsletter_screen.dart
- artists_provider.dart
- voting_screen.dart
- package:flutter_riverpod/flutter_riverpod.dart
- faq_screen.dart
- organizers_screen.dart
- main.dart
- package.json
- static const
- gallery_screen.dart
- home_screen.dart
- brand_loading_indicator.dart
- wWinMain
- State
- submission_image_picker.dart
- event_card.dart
- voting_service.dart
- ios/RunnerTests/RunnerTests.swift
- MaterialPageRoute
- manifest.json
- ../core/navigation/in_app_browser.dart
- hungarian-hardstyle-newsroom/app/graphics.py
- social_contact_screen.dart
- about_screen.dart
- spotify_player.dart
- communityServiceProvider
- AppDelegate
- faq.dart
- import_mosets.py
- FlutterMacOS
- dart:async
- community_provider.dart
- submission_image.dart
- build
- AppDelegate
- RegisterGeneratedPlugins
- _EventSubmissionScreenState
- ads_provider.dart
- organizers_provider.dart
- genre_chip.dart
- _ArtistSubmissionScreenState
- OpenAPITests
- PaginatedNewsNotifier
- wordpressServiceProvider
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

## Communities (120 total, 7 thin omitted)

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

### Community 5 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 6 - "release.dart"
Cohesion: 0.05
Nodes (37): AudioPlayer, Duration, artists, audioStatus, available, coverUrl, fromJson, genre (+29 more)

### Community 7 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 8 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 9 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (33): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+25 more)

### Community 10 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 11 - "more_screen.dart"
Cohesion: 0.06
Nodes (30): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, _callback, createState (+22 more)

### Community 12 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 13 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (29): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+21 more)

### Community 14 - "favorites_provider.dart"
Cohesion: 0.07
Nodes (28): ChangeNotifier, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId, dispose (+20 more)

### Community 15 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 16 - "organizer_detail_screen.dart"
Cohesion: 0.09
Nodes (26): ConsumerWidget, OrganizerProfile, FavoriteKind, favoritesProvider, organizerDetailProvider, _PostAuthorAvatar, build, FavoritesScreen (+18 more)

### Community 17 - "community_users_screen.dart"
Cohesion: 0.07
Nodes (27): DocumentSnapshot, _action, CommunityUsersScreen, _CommunityUsersScreenState, connectionData, _connectionStatus, createState, data (+19 more)

### Community 18 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 19 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 20 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 21 - "news_provider.dart"
Cohesion: 0.08
Nodes (25): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+17 more)

### Community 22 - "package:flutter/material.dart"
Cohesion: 0.10
Nodes (21): ../core/content/date_formatters.dart, favorite_button.dart, PostShortcode, build, PrivacyScreen, build, FeaturedNewsCard, post (+13 more)

### Community 23 - "radio_player_bar.dart"
Cohesion: 0.08
Nodes (23): dart:io, build, DonateScreen, _donateUri, build, _channel, createState, dispose (+15 more)

### Community 24 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 25 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 26 - "ConsumerState"
Cohesion: 0.13
Nodes (24): communityAuthProvider, communityPostsProvider, communityServiceProvider, ConsumerState, ConsumerStatefulWidget, build, CommunityAdminScreen, _CommunityAdminScreenState (+16 more)

### Community 27 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 28 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 29 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 30 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 31 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 32 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 33 - "settings_screen.dart"
Cohesion: 0.09
Nodes (21): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+13 more)

### Community 34 - "release_detail_screen.dart"
Cohesion: 0.09
Nodes (21): createState, dispose, _download, _downloadVariant, initState, _label, _loadProducts, _message (+13 more)

### Community 35 - "events_screen.dart"
Cohesion: 0.12
Nodes (18): ../artists/artist_detail_screen.dart, event_submission_screen.dart, ../events/event_detail_screen.dart, communityAuthProvider, eventsProvider, build, _EventsHeader, EventsScreen (+10 more)

### Community 36 - "kozponti-cegregiszter.php"
Cohesion: 0.13
Nodes (6): kcr_fields(), kcr_item(), kcr_meta_box_html(), kcr_routes(), kcr_save(), kcr_schema()

### Community 37 - "label_purchase_service.dart"
Cohesion: 0.10
Nodes (19): dart:convert, InAppPurchase, buy, dispose, getDownloadUrl, LabelPurchaseService, listen, loadProducts (+11 more)

### Community 38 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 39 - "index.js"
Cohesion: 0.11
Nodes (14): admin, callWindows, crypto, db, { defineSecret }, functions, { getFirestore }, { google } (+6 more)

### Community 40 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 41 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.11
Nodes (17): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+9 more)

### Community 42 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): HuhsRelease, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 43 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 44 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 45 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 46 - "startup_gate.dart"
Cohesion: 0.12
Nodes (17): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+9 more)

### Community 47 - "news_screen.dart"
Cohesion: 0.15
Nodes (16): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+8 more)

### Community 48 - "tagged_news_screen.dart"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+8 more)

### Community 49 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 50 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 51 - "StatelessWidget"
Cohesion: 0.12
Nodes (16): _Composer, _PostAuthorLabels, _ProfileAvatar, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen, CommunityReportsScreen, _ConnectionRequestTile (+8 more)

### Community 52 - "news_detail_screen.dart"
Cohesion: 0.13
Nodes (13): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, _formatDate, NewsDetailScreen, _openLink, post (+5 more)

### Community 53 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 54 - "artists_provider.dart"
Cohesion: 0.14
Nodes (12): ProfileSubmissionOptions, ArtistListQuery, getArtist, getArtists, service, ReleaseQuery, releasesProvider, ../models/artist.dart (+4 more)

### Community 55 - "voting_screen.dart"
Cohesion: 0.15
Nodes (14): votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent, _selected (+6 more)

### Community 56 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.16
Nodes (11): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+3 more)

### Community 57 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 58 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError, OrganizersScreen (+5 more)

### Community 59 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 60 - "package.json"
Cohesion: 0.15
Nodes (12): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, googleapis, engines, node (+4 more)

### Community 61 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 62 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 63 - "home_screen.dart"
Cohesion: 0.15
Nodes (12): _controller, createState, dispose, initState, onShowMoreNews, _page, posts, _timer (+4 more)

### Community 64 - "brand_loading_indicator.dart"
Cohesion: 0.18
Nodes (11): AnimationController, BrandLoadingIndicator, _BrandLoadingIndicatorState, build, _controller, createState, didChangeDependencies, dispose (+3 more)

### Community 65 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 66 - "State"
Cohesion: 0.23
Nodes (12): _NewsSlider, _NewsSliderState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, SettingsScreen, _SettingsScreenState, ReleaseDetailScreen, _ReleaseDetailScreenState (+4 more)

### Community 67 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 68 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 69 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, VotingService (+2 more)

### Community 70 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.22
Nodes (7): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTest, XCTestCase

### Community 71 - "MaterialPageRoute"
Cohesion: 0.18
Nodes (11): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, build (+3 more)

### Community 72 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 73 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.20
Nodes (8): ../core/navigation/in_app_browser.dart, build, RadioProviderScreen, build, _openSpotify, _playlists, SpotifyPlaylistsScreen, package:url_launcher/url_launcher.dart

### Community 74 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 75 - "social_contact_screen.dart"
Cohesion: 0.20
Nodes (9): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value (+1 more)

### Community 76 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 77 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 78 - "communityServiceProvider"
Cohesion: 0.22
Nodes (9): communityServiceProvider, _editCustomResource, _editStartup, _load, _sendPersonalizedPush, WordPressAdminScreen, _WordPressAdminScreenState, _submit (+1 more)

### Community 79 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 80 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 81 - "import_mosets.py"
Cohesion: 0.52
Nodes (6): api(), attrib(), main(), rows(), statements(), val()

### Community 82 - "FlutterMacOS"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 83 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 84 - "community_provider.dart"
Cohesion: 0.29
Nodes (6): communityPostsProvider, watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 85 - "submission_image.dart"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 86 - "build"
Cohesion: 0.47
Nodes (6): eventsProvider, _openPlannedEvent, build, HomeScreen, newsProvider, votingProvider

### Community 87 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 88 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 89 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 90 - "ads_provider.dart"
Cohesion: 0.40
Nodes (4): enableTestAds, productionAdMobAppId, productionBannerAdUnitId, productionRewardedAdUnitId

### Community 91 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 92 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

### Community 93 - "_ArtistSubmissionScreenState"
Cohesion: 0.50
Nodes (4): profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build

### Community 96 - "PaginatedNewsNotifier"
Cohesion: 0.67
Nodes (3): PaginatedNewsNotifier, PaginatedNewsState, StateNotifier

### Community 97 - "wordpressServiceProvider"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

## Knowledge Gaps
- **1133 isolated node(s):** `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate`, `output`, `blockedTags` (+1128 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `build` connect `build` to `MaterialPageRoute`, `home_screen.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `HomeScreen` connect `build` to `organizer_detail_screen.dart`, `home_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artists_screen.dart`, `artist.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate` to the rest of the system?**
  _1133 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._