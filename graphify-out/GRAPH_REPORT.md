# Graph Report - .  (2026-08-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1937 nodes · 2667 edges · 115 communities (108 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 22 edges (avg confidence: 0.76)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `68c5d431`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- event_submission_screen.dart
- event.dart
- wordpress_admin_screen.dart
- community_users_screen.dart
- release.dart
- artist.dart
- widget_test.dart
- more_screen.dart
- organizer.dart
- genre_discovery_screen.dart
- favorites_provider.dart
- news_provider.dart
- artist_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- RadioPlaybackService
- organizer_submission_screen.dart
- main_navigation.dart
- settings_screen.dart
- release_detail_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- event_detail_screen.dart
- voting.dart
- post_embed_card.dart
- profile_submission.dart
- label_purchase_service.dart
- radio_player_bar.dart
- html_linkifier.dart
- kozponti-cegregiszter.php
- ConsumerWidget
- index.js
- event_submission.dart
- organizer_detail_screen.dart
- tagged_news_screen.dart
- GeneratedPluginRegistrant.swift
- releases_screen.dart
- in_app_browser.dart
- artist_detail_screen.dart
- package:flutter_riverpod/flutter_riverpod.dart
- news_screen.dart
- package:flutter/material.dart
- push_notification_service.dart
- ConsumerState
- mobile_ad_banner.dart
- communityServiceProvider
- community_post.dart
- organizers_screen.dart
- startup_gate.dart
- ../core/navigation/in_app_browser.dart
- newsletter_screen.dart
- voting_screen.dart
- home_screen.dart
- faq_screen.dart
- package.json
- static const
- State
- package:cached_network_image/cached_network_image.dart
- main.dart
- voting_service.dart
- wWinMain
- submission_image_picker.dart
- news_detail_screen.dart
- event_card.dart
- ios/RunnerTests/RunnerTests.swift
- voting_provider.dart
- MaterialPageRoute
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- gallery_screen.dart
- about_screen.dart
- spotify_player.dart
- brand_loading_indicator.dart
- events_screen.dart
- List
- AppDelegate
- faq.dart
- favorites_screen.dart
- import_mosets.py
- FlutterMacOS
- dart:async
- community_provider.dart
- submission_image.dart
- build
- AppDelegate
- RegisterGeneratedPlugins
- ads_provider.dart
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

## Communities (115 total, 7 thin omitted)

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

### Community 5 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (43): formatEventDate, formatHungarianDate, eventSubmissionGenresProvider, _addressController, build, _cityController, createState, _descriptionController (+35 more)

### Community 6 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 7 - "wordpress_admin_screen.dart"
Cohesion: 0.05
Nodes (42): communityServiceProvider, _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState (+34 more)

### Community 8 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (41): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+33 more)

### Community 9 - "release.dart"
Cohesion: 0.05
Nodes (37): AudioPlayer, Duration, artists, audioStatus, available, coverUrl, fromJson, genre (+29 more)

### Community 10 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 11 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 12 - "more_screen.dart"
Cohesion: 0.06
Nodes (30): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, _callback, createState (+22 more)

### Community 13 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 14 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (29): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+21 more)

### Community 15 - "favorites_provider.dart"
Cohesion: 0.07
Nodes (28): ChangeNotifier, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId, dispose (+20 more)

### Community 16 - "news_provider.dart"
Cohesion: 0.07
Nodes (28): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+20 more)

### Community 17 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 18 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 19 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 20 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 21 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (23): class, build, _city, _contactEmail, _country, createState, _description, dispose (+15 more)

### Community 22 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 23 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 24 - "release_detail_screen.dart"
Cohesion: 0.09
Nodes (23): createState, dispose, _download, _downloadVariant, initState, _label, _loadProducts, _message (+15 more)

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

### Community 31 - "label_purchase_service.dart"
Cohesion: 0.10
Nodes (19): dart:convert, InAppPurchase, buy, dispose, getDownloadUrl, LabelPurchaseService, listen, loadProducts (+11 more)

### Community 32 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 33 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 34 - "kozponti-cegregiszter.php"
Cohesion: 0.13
Nodes (6): kcr_fields(), kcr_item(), kcr_meta_box_html(), kcr_routes(), kcr_save(), kcr_schema()

### Community 35 - "ConsumerWidget"
Cohesion: 0.13
Nodes (18): ConsumerWidget, communityAuthProvider, eventsProvider, FavoriteKind, favoritesProvider, _PostAuthorAvatar, build, EventsScreen (+10 more)

### Community 36 - "index.js"
Cohesion: 0.11
Nodes (14): admin, callWindows, crypto, db, { defineSecret }, functions, { getFirestore }, { google } (+6 more)

### Community 37 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 38 - "organizer_detail_screen.dart"
Cohesion: 0.12
Nodes (17): OrganizerProfile, getOrganizer, getOrganizers, organizerDetailProvider, service, build, _descriptionHtml, _escapeHtml (+9 more)

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

### Community 43 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 44 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.13
Nodes (14): ProfileSubmissionOptions, ArtistListQuery, getArtist, getArtists, service, ReleaseQuery, releasesProvider, ../models/artist.dart (+6 more)

### Community 45 - "news_screen.dart"
Cohesion: 0.14
Nodes (17): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+9 more)

### Community 46 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (14): build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen, build (+6 more)

### Community 47 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 48 - "ConsumerState"
Cohesion: 0.15
Nodes (17): ConsumerState, ConsumerStatefulWidget, profileSubmissionOptionsProvider, EventDetailScreen, _EventDetailScreenState, GenreDiscoveryScreen, _GenreDiscoveryScreenState, CommunityUsersScreen (+9 more)

### Community 49 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 50 - "communityServiceProvider"
Cohesion: 0.15
Nodes (16): communityAuthProvider, communityPostsProvider, communityServiceProvider, build, CommunityAdminScreen, _CommunityAdminScreenState, CommunityAvatarButton, CommunityProfileScreen (+8 more)

### Community 51 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 52 - "organizers_screen.dart"
Cohesion: 0.14
Nodes (15): organizersProvider, build, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard (+7 more)

### Community 53 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 54 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.13
Nodes (13): ../core/navigation/in_app_browser.dart, IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen (+5 more)

### Community 55 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 56 - "voting_screen.dart"
Cohesion: 0.15
Nodes (14): wordpressServiceProvider, votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent (+6 more)

### Community 57 - "home_screen.dart"
Cohesion: 0.14
Nodes (14): _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews, _page (+6 more)

### Community 58 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 59 - "package.json"
Cohesion: 0.15
Nodes (12): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, googleapis, engines, node (+4 more)

### Community 60 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 61 - "State"
Cohesion: 0.22
Nodes (13): GalleryScreen, _GalleryScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, PostEmbedCard, _PostEmbedCardState (+5 more)

### Community 62 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 63 - "main.dart"
Cohesion: 0.17
Nodes (11): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+3 more)

### Community 64 - "voting_service.dart"
Cohesion: 0.17
Nodes (11): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, VotingService (+3 more)

### Community 65 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 66 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 67 - "news_detail_screen.dart"
Cohesion: 0.18
Nodes (10): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, build, _formatDate, NewsDetailScreen, post, package:flutter_html/flutter_html.dart, tagged_news_screen.dart (+2 more)

### Community 68 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 69 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.22
Nodes (7): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTest, XCTestCase

### Community 70 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 71 - "MaterialPageRoute"
Cohesion: 0.18
Nodes (11): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _openLink (+3 more)

### Community 72 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 73 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 74 - "gallery_screen.dart"
Cohesion: 0.20
Nodes (9): build, _controller, createState, _current, dispose, images, initialIndex, initState (+1 more)

### Community 75 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 76 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 77 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 78 - "events_screen.dart"
Cohesion: 0.22
Nodes (8): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, VoidCallback, ../../widgets/event_card.dart

### Community 79 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../screens/news/news_detail_screen.dart

### Community 80 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 81 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 82 - "favorites_screen.dart"
Cohesion: 0.29
Nodes (6): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, _label, ../news/news_detail_screen.dart, ../organizers/organizer_detail_screen.dart, ../../providers/events_provider.dart

### Community 83 - "import_mosets.py"
Cohesion: 0.52
Nodes (6): api(), attrib(), main(), rows(), statements(), val()

### Community 84 - "FlutterMacOS"
Cohesion: 0.38
Nodes (3): Cocoa, FlutterMacOS, RunnerTests

### Community 85 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 86 - "community_provider.dart"
Cohesion: 0.29
Nodes (6): communityPostsProvider, watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 87 - "submission_image.dart"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 88 - "build"
Cohesion: 0.47
Nodes (6): eventsProvider, _openPlannedEvent, build, HomeScreen, newsProvider, votingProvider

### Community 89 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 90 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 91 - "ads_provider.dart"
Cohesion: 0.40
Nodes (4): enableTestAds, productionAdMobAppId, productionBannerAdUnitId, productionRewardedAdUnitId

## Knowledge Gaps
- **1133 isolated node(s):** `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate`, `output`, `blockedTags` (+1128 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `build` connect `build` to `home_screen.dart`, `MaterialPageRoute`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `HomeScreen` connect `build` to `home_screen.dart`, `ConsumerWidget`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artist.dart`, `artists_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `hungarian-hardstyle-newsroom`, `formatHungarianDate`, `formatEventDate` to the rest of the system?**
  _1133 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._