# Graph Report - .  (2026-08-10)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1833 nodes · 2556 edges · 108 communities (101 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `649edfbe`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- post.dart
- event.dart
- news_provider.dart
- artist.dart
- event_submission_screen.dart
- wordpress_admin_screen.dart
- widget_test.dart
- genre_discovery_screen.dart
- favorites_provider.dart
- organizer.dart
- artist_submission_screen.dart
- community_users_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- organizer_submission_screen.dart
- communityServiceProvider
- RadioPlaybackService
- main_navigation.dart
- post_embed_card.dart
- settings_screen.dart
- newsroom/app/main.py
- more_screen.dart
- artists_screen.dart
- event_detail_screen.dart
- voting.dart
- profile_submission.dart
- releases_screen.dart
- events_screen.dart
- html_linkifier.dart
- event_submission.dart
- voting_screen.dart
- tagged_news_screen.dart
- favorites_screen.dart
- radio_player_bar.dart
- artist_detail_screen.dart
- push_notification_service.dart
- GeneratedPluginRegistrant.swift
- news_screen.dart
- StatelessWidget
- mobile_ad_banner.dart
- news_detail_screen.dart
- index.js
- in_app_browser.dart
- startup_gate.dart
- release_preview_player.dart
- community_post.dart
- release.dart
- organizers_screen.dart
- organizer_detail_screen.dart
- home_screen.dart
- faq_screen.dart
- static const
- gallery_screen.dart
- package:flutter/material.dart
- featured_news_card.dart
- main.dart
- wWinMain
- submission_image_picker.dart
- event_card.dart
- package.json
- voting_service.dart
- State
- voting_provider.dart
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- social_contact_screen.dart
- MaterialPageRoute
- about_screen.dart
- spotify_player.dart
- brand_loading_indicator.dart
- package:cached_network_image/cached_network_image.dart
- package:flutter_riverpod/flutter_riverpod.dart
- FlutterMacOS
- AppDelegate
- faq.dart
- List
- news_provider.dart
- community_provider.dart
- dart:async
- ios/RunnerTests/RunnerTests.swift
- ../core/navigation/in_app_browser.dart
- SubmissionImage
- AppDelegate
- _EventSubmissionScreenState
- build
- organizers_provider.dart
- genre_chip.dart
- RegisterGeneratedPlugins
- OpenAPITests
- hungarian-hardstyle-newsroom/app/__init__.py
- newsroom/app/__init__.py
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- hungarian-hardstyle-newsroom
- String?

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
- `build` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `CommunityAvatarButton` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_delete` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (108 total, 7 thin omitted)

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

### Community 5 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 6 - "news_provider.dart"
Cohesion: 0.05
Nodes (42): FormState, categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading (+34 more)

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

### Community 11 - "genre_discovery_screen.dart"
Cohesion: 0.06
Nodes (31): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+23 more)

### Community 12 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (30): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+22 more)

### Community 13 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 14 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 15 - "community_users_screen.dart"
Cohesion: 0.07
Nodes (27): DocumentSnapshot, _action, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, connectionData, _connectionStatus, createState, data (+19 more)

### Community 16 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 17 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 18 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 19 - "communityServiceProvider"
Cohesion: 0.12
Nodes (25): ConsumerState, ConsumerStatefulWidget, communityServiceProvider, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _delete (+17 more)

### Community 20 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 21 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 22 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (23): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+15 more)

### Community 23 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 24 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 25 - "more_screen.dart"
Cohesion: 0.09
Nodes (22): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, onTap (+14 more)

### Community 26 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 27 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 28 - "voting.dart"
Cohesion: 0.09
Nodes (21): int get, active, artist, candidates, categories, fromJson, id, image (+13 more)

### Community 29 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 30 - "releases_screen.dart"
Cohesion: 0.10
Nodes (20): ReleaseQuery, releasesProvider, artistId, artistName, build, createState, dispose, _query (+12 more)

### Community 31 - "events_screen.dart"
Cohesion: 0.13
Nodes (19): ConsumerWidget, event_submission_screen.dart, communityAuthProvider, eventsProvider, CommunityAvatarButton, _openPlannedEvent, _PostAuthorAvatar, build (+11 more)

### Community 32 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 33 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 34 - "voting_screen.dart"
Cohesion: 0.12
Nodes (17): wordpressServiceProvider, votingServiceProvider, _busyCategory, _category, createState, _link, _newsletterAsked, _newsletterConsent (+9 more)

### Community 35 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 36 - "favorites_screen.dart"
Cohesion: 0.12
Nodes (16): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, FavoriteKind, favoritesProvider, build, _label, _OrganizerContent, build (+8 more)

### Community 37 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (17): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+9 more)

### Community 38 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 39 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 40 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 41 - "news_screen.dart"
Cohesion: 0.15
Nodes (16): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+8 more)

### Community 42 - "StatelessWidget"
Cohesion: 0.12
Nodes (17): _Composer, _PostAuthorLabels, _ProfileAvatar, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen, CommunityReportsScreen, _ConnectionRequestTile (+9 more)

### Community 43 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 44 - "news_detail_screen.dart"
Cohesion: 0.12
Nodes (14): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, build, _formatDate, NewsDetailScreen, _openLink (+6 more)

### Community 45 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 46 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 47 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 48 - "release_preview_player.dart"
Cohesion: 0.14
Nodes (14): AudioPlayer, Duration, ReleaseTrack, build, createState, dispose, index, initState (+6 more)

### Community 49 - "community_post.dart"
Cohesion: 0.13
Nodes (14): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+6 more)

### Community 50 - "release.dart"
Cohesion: 0.13
Nodes (14): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+6 more)

### Community 51 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError (+5 more)

### Community 52 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name, organizer (+5 more)

### Community 53 - "home_screen.dart"
Cohesion: 0.15
Nodes (13): _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews, _page (+5 more)

### Community 54 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 55 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 56 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 57 - "package:flutter/material.dart"
Cohesion: 0.17
Nodes (10): build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen, package:flutter/material.dart (+2 more)

### Community 58 - "featured_news_card.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 59 - "main.dart"
Cohesion: 0.17
Nodes (11): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+3 more)

### Community 60 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 61 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 62 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 63 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 64 - "voting_service.dart"
Cohesion: 0.18
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, package:cloud_firestore/cloud_firestore.dart (+2 more)

### Community 65 - "State"
Cohesion: 0.25
Nodes (11): InAppBrowserScreen, _InAppBrowserScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, RadioPlayerBar, _RadioPlayerBarState, StartupGate, _StartupGateState (+3 more)

### Community 66 - "voting_provider.dart"
Cohesion: 0.20
Nodes (9): VotingSeason, votingProvider, watch, build, build, VotingSummaryScreen, ../models/voting.dart, package:cloud_functions/cloud_functions.dart (+1 more)

### Community 67 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 68 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 69 - "social_contact_screen.dart"
Cohesion: 0.20
Nodes (9): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value (+1 more)

### Community 70 - "MaterialPageRoute"
Cohesion: 0.20
Nodes (10): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _open (+2 more)

### Community 71 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 72 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 73 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 74 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.22
Nodes (8): HuhsRelease, build, _label, release, ReleaseDetailScreen, package:cached_network_image/cached_network_image.dart, releases_screen.dart, ../../widgets/release_preview_player.dart

### Community 75 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.22
Nodes (7): enableTestAds, ArtistListQuery, getArtist, getArtists, service, ../models/artist.dart, package:flutter_riverpod/flutter_riverpod.dart

### Community 76 - "FlutterMacOS"
Cohesion: 0.32
Nodes (4): Cocoa, FlutterMacOS, RunnerTests, XCTest

### Community 77 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 78 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 79 - "List"
Cohesion: 0.25
Nodes (7): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List

### Community 80 - "news_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 81 - "community_provider.dart"
Cohesion: 0.25
Nodes (7): communityPostsProvider, watch, build, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 82 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 83 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.24
Nodes (6): Flutter, FlutterSceneDelegate, SceneDelegate, RunnerTests, UIKit, XCTestCase

### Community 84 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.33
Nodes (5): ../core/navigation/in_app_browser.dart, build, _openSpotify, _playlists, SpotifyPlaylistsScreen

### Community 85 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 86 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 87 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 88 - "build"
Cohesion: 0.60
Nodes (5): eventsProvider, build, HomeScreen, newsProvider, votingProvider

### Community 90 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 91 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

### Community 92 - "RegisterGeneratedPlugins"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

## Knowledge Gaps
- **1074 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1069 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CommunityService` connect `community_provider.dart` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artists_screen.dart`, `artist.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `SubmissionImage` connect `SubmissionImage` to `community_screen.dart`, `event_submission_screen.dart`, `artist_submission_screen.dart`, `organizer_submission_screen.dart`, `submission_image_picker.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1074 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._