# Graph Report - .  (2026-08-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1830 nodes · 2558 edges · 107 communities (99 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `317e0ed4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- genre_discovery_screen.dart
- post.dart
- artists_screen.dart
- releases_screen.dart
- home_screen.dart
- event.dart
- community_users_screen.dart
- artist.dart
- event_submission_screen.dart
- wordpress_admin_screen.dart
- favorites_provider.dart
- organizer.dart
- artist_submission_screen.dart
- news_provider.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- organizer_submission_screen.dart
- voting.dart
- more_screen.dart
- RadioPlaybackService
- ConsumerWidget
- post_embed_card.dart
- settings_screen.dart
- newsroom/app/main.py
- event_detail_screen.dart
- profile_submission.dart
- radio_player_bar.dart
- html_linkifier.dart
- main_navigation.dart
- package:flutter/material.dart
- event_submission.dart
- voting_screen.dart
- push_notification_service.dart
- GeneratedPluginRegistrant.swift
- events_screen.dart
- index.js
- in_app_browser.dart
- startup_gate.dart
- package:flutter_test/flutter_test.dart
- mobile_ad_banner.dart
- community_post.dart
- newsletter_screen.dart
- release.dart
- ConsumerState
- voting_service.dart
- organizers_screen.dart
- organizer_detail_screen.dart
- main.dart
- State
- static const
- communityServiceProvider
- package:cached_network_image/cached_network_image.dart
- news_detail_screen.dart
- wWinMain
- submission_image_picker.dart
- event_card.dart
- package.json
- gallery_screen.dart
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- MaterialPageRoute
- about_screen.dart
- spotify_player.dart
- brand_loading_indicator.dart
- social_contact_screen.dart
- List
- ios/RunnerTests/RunnerTests.swift
- AppDelegate
- faq.dart
- news_provider.dart
- widget_test.dart
- FlutterMacOS
- dart:async
- SubmissionImage
- AppDelegate
- package:flutter_riverpod/flutter_riverpod.dart
- community_provider.dart
- _EventSubmissionScreenState
- favorite_button.dart
- event_card_test.dart
- RunnerTests
- app_navigator.dart
- organizers_provider.dart
- genre_chip.dart
- RegisterGeneratedPlugins
- package:intl/intl.dart
- OpenAPITests
- event_submission_test.dart
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
9. `eventsProvider` - 9 edges
10. `MessageHandler` - 9 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `_CommunityAdminScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `CommunityAvatarButton` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_CommunityProfileScreenState` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (107 total, 8 thin omitted)

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

### Community 4 - "genre_discovery_screen.dart"
Cohesion: 0.04
Nodes (47): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+39 more)

### Community 5 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 6 - "artists_screen.dart"
Cohesion: 0.05
Nodes (44): artist_detail_screen.dart, ArtistListQuery get, Artist, artistDetailProvider, ArtistListQuery, artistsProvider, getArtist, getArtists (+36 more)

### Community 7 - "releases_screen.dart"
Cohesion: 0.05
Nodes (41): AudioPlayer, Duration, HuhsRelease, ReleaseTrack, ReleaseQuery, releasesProvider, build, _label (+33 more)

### Community 8 - "home_screen.dart"
Cohesion: 0.05
Nodes (42): paginatedNewsProvider, _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews (+34 more)

### Community 9 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 10 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (40): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+32 more)

### Community 11 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 12 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 13 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (34): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+26 more)

### Community 14 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (30): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+22 more)

### Community 15 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 16 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 17 - "news_provider.dart"
Cohesion: 0.07
Nodes (27): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+19 more)

### Community 18 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 19 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 20 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 21 - "voting.dart"
Cohesion: 0.08
Nodes (24): int get, active, artist, candidates, categories, fromJson, id, image (+16 more)

### Community 22 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 23 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 24 - "ConsumerWidget"
Cohesion: 0.12
Nodes (24): ConsumerWidget, communityAuthProvider, eventsProvider, favoritesProvider, newsProvider, votingProvider, CommunityAvatarButton, _openPlannedEvent (+16 more)

### Community 25 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (23): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+15 more)

### Community 26 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 27 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 28 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 29 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 30 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 31 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 32 - "main_navigation.dart"
Cohesion: 0.11
Nodes (18): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, build, createState, _currentIndex, MainNavigation, _MainNavigationState (+10 more)

### Community 33 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (15): ../core/navigation/in_app_browser.dart, build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen (+7 more)

### Community 34 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 35 - "voting_screen.dart"
Cohesion: 0.13
Nodes (17): wordpressServiceProvider, votingServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState, _busyCategory, _category, createState, _link (+9 more)

### Community 36 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 37 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 38 - "events_screen.dart"
Cohesion: 0.12
Nodes (14): ../artists/artist_detail_screen.dart, event_submission_screen.dart, ../events/event_detail_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, _label (+6 more)

### Community 39 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 40 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 41 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 42 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.12
Nodes (11): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart, package:hungarian_hardstyle_app/models/profile_submission.dart, main, main (+3 more)

### Community 43 - "mobile_ad_banner.dart"
Cohesion: 0.16
Nodes (14): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+6 more)

### Community 44 - "community_post.dart"
Cohesion: 0.13
Nodes (14): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+6 more)

### Community 45 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 46 - "release.dart"
Cohesion: 0.13
Nodes (14): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+6 more)

### Community 47 - "ConsumerState"
Cohesion: 0.20
Nodes (14): ConsumerState, ConsumerStatefulWidget, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _PostCard, _PostCardState (+6 more)

### Community 48 - "voting_service.dart"
Cohesion: 0.15
Nodes (12): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVotes, package:cloud_firestore/cloud_firestore.dart (+4 more)

### Community 49 - "organizers_screen.dart"
Cohesion: 0.17
Nodes (12): createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError, OrganizersScreen (+4 more)

### Community 50 - "organizer_detail_screen.dart"
Cohesion: 0.14
Nodes (14): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+6 more)

### Community 51 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:flutter_localizations/flutter_localizations.dart (+4 more)

### Community 52 - "State"
Cohesion: 0.22
Nodes (13): InAppBrowserScreen, _InAppBrowserScreenState, GalleryScreen, _GalleryScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState (+5 more)

### Community 53 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 54 - "communityServiceProvider"
Cohesion: 0.17
Nodes (13): communityPostsProvider, communityServiceProvider, build, _delete, LiveFeedScreen, _LiveFeedScreenState, _moderateUser, _editCustomResource (+5 more)

### Community 55 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 56 - "news_detail_screen.dart"
Cohesion: 0.17
Nodes (11): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, build, _formatDate, NewsDetailScreen, _openLink, post, package:flutter_html/flutter_html.dart (+3 more)

### Community 57 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 58 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 59 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 60 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 61 - "gallery_screen.dart"
Cohesion: 0.18
Nodes (10): build, _controller, createState, _current, dispose, images, initialIndex, initState (+2 more)

### Community 62 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 63 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 64 - "MaterialPageRoute"
Cohesion: 0.20
Nodes (10): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _open (+2 more)

### Community 65 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 66 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 67 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 68 - "social_contact_screen.dart"
Cohesion: 0.22
Nodes (8): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value

### Community 69 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../models/post.dart

### Community 70 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.38
Nodes (4): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit

### Community 71 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 72 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 73 - "news_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 74 - "widget_test.dart"
Cohesion: 0.25
Nodes (7): package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/voting.dart, package:hungarian_hardstyle_app/providers/ads_provider.dart, package:hungarian_hardstyle_app/providers/events_provider.dart, package:hungarian_hardstyle_app/providers/news_provider.dart, package:hungarian_hardstyle_app/providers/voting_provider.dart, main

### Community 75 - "FlutterMacOS"
Cohesion: 0.32
Nodes (5): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow, XCTest

### Community 76 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 77 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 78 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 79 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.33
Nodes (4): enableTestAds, VotingService, package:flutter_riverpod/flutter_riverpod.dart, ../services/voting_service.dart

### Community 80 - "community_provider.dart"
Cohesion: 0.33
Nodes (5): watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 81 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 82 - "favorite_button.dart"
Cohesion: 0.33
Nodes (5): FavoriteKind, id, kind, title, ../providers/favorites_provider.dart

### Community 83 - "event_card_test.dart"
Cohesion: 0.33
Nodes (4): package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/widgets/event_card.dart, main, main

### Community 84 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 85 - "app_navigator.dart"
Cohesion: 0.40
Nodes (4): appNavigatorKey, appScaffoldMessengerKey, NavigatorState, ScaffoldMessengerState

### Community 86 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 87 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

### Community 88 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

### Community 89 - "package:intl/intl.dart"
Cohesion: 0.50
Nodes (3): formatEventDate, formatHungarianDate, package:intl/intl.dart

## Knowledge Gaps
- **1073 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1068 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SubmissionImage` connect `SubmissionImage` to `community_screen.dart`, `event_submission_screen.dart`, `artist_submission_screen.dart`, `organizer_submission_screen.dart`, `submission_image_picker.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `CommunityService` connect `community_provider.dart` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `communityServiceProvider` connect `communityServiceProvider` to `voting_screen.dart`, `ConsumerState`, `community_provider.dart`, `_EventSubmissionScreenState`, `ConsumerWidget`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1073 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._