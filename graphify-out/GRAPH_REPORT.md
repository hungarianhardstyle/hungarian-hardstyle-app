# Graph Report - .  (2026-07-23)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1441 nodes · 1978 edges · 94 communities (85 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1b304389`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 82
- Community 83
- Community 87
- Community 89
- Community 92
- Community 93

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `communityServiceProvider` - 12 edges
3. `MessageHandler` - 12 edges
4. `update_metadata()` - 11 edges
5. `RadioPlaybackService` - 10 edges
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

## Communities (94 total, 9 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 1 - "Community 1"
Cohesion: 0.04
Nodes (53): CommunityService get, dart:math, DocumentSnapshot, _anonymous, _authSubscription, _avatarLetter, _avatarUrl, _bio (+45 more)

### Community 2 - "Community 2"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (46): _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback, fromJson (+38 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (44): Dio, FirebaseAuth, FirebaseFirestore, accessAdmin, accessModerator, accessNone, accountRole, adminEmail (+36 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (41): FormState, categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading (+33 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (41): int?, eventSubmissionGenresProvider, _addressController, build, _cityController, createState, _descriptionController, dispose (+33 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (36): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+28 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (30): event.dart, 0, city, country, description, excerpt, false, featured (+22 more)

### Community 11 - "Community 11"
Cohesion: 0.08
Nodes (26): ../core/navigation/in_app_browser.dart, IconData, AboutScreen, build, icon, _InfoTile, label, onTap (+18 more)

### Community 12 - "Community 12"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 13 - "Community 13"
Cohesion: 0.07
Nodes (27): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _error (+19 more)

### Community 14 - "Community 14"
Cohesion: 0.08
Nodes (26): class, build, _city, _contactEmail, _country, createState, _description, dispose (+18 more)

### Community 15 - "Community 15"
Cohesion: 0.15
Nodes (19): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, RequestLoggingMiddleware (+11 more)

### Community 16 - "Community 16"
Cohesion: 0.10
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 17 - "Community 17"
Cohesion: 0.09
Nodes (22): Artist, artistDetailProvider, ArtistListQuery, getArtist, getArtists, service, artist, _ArtistContent (+14 more)

### Community 18 - "Community 18"
Cohesion: 0.11
Nodes (20): ../core/content/date_formatters.dart, double?, favorite_button.dart, genre_chip.dart, HuhsEvent, Post, event, EventCard (+12 more)

### Community 19 - "Community 19"
Cohesion: 0.15
Nodes (12): artists, _descriptionHtml, _escapeHtml, event, EventDetailScreen, _formatDate, icon, onTap (+4 more)

### Community 20 - "Community 20"
Cohesion: 0.15
Nodes (17): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+9 more)

### Community 21 - "Community 21"
Cohesion: 0.11
Nodes (19): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, ArtistsScreen, _ArtistsScreenState, build, _category (+11 more)

### Community 22 - "Community 22"
Cohesion: 0.11
Nodes (18): events/events_screen.dart, home/home_screen.dart, appNavigatorKey, build, createState, _currentIndex, MainNavigation, _MainNavigationState (+10 more)

### Community 23 - "Community 23"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 24 - "Community 24"
Cohesion: 0.10
Nodes (19): build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState, _loading (+11 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (18): about_screen.dart, ../artists/artists_screen.dart, favorites_screen.dart, icon, _MenuCard, onTap, _SubmissionCard, subtitle (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.15
Nodes (9): MainActivity, RadioPlaybackService, FlutterActivity, FlutterEngine, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 27 - "Community 27"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (17): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+9 more)

### Community 29 - "Community 29"
Cohesion: 0.12
Nodes (16): ChangeNotifier, dart:convert, Future, contains, entries, FavoriteEntry, FavoritesNotifier, id (+8 more)

### Community 30 - "Community 30"
Cohesion: 0.15
Nodes (16): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+8 more)

### Community 31 - "Community 31"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+8 more)

### Community 32 - "Community 32"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 33 - "Community 33"
Cohesion: 0.14
Nodes (15): organizersProvider, build, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard (+7 more)

### Community 34 - "Community 34"
Cohesion: 0.13
Nodes (15): _animationDuration, build, _controller, createState, didChangeDependencies, dispose, initState, _logoAsset (+7 more)

### Community 35 - "Community 35"
Cohesion: 0.14
Nodes (14): community/community_screen.dart, newsProvider, build, _controller, createState, dispose, HomeScreen, initState (+6 more)

### Community 36 - "Community 36"
Cohesion: 0.20
Nodes (15): ConsumerWidget, communityAuthProvider, communityPostsProvider, communityServiceProvider, eventsProvider, build, CommunityAvatarButton, _delete (+7 more)

### Community 37 - "Community 37"
Cohesion: 0.13
Nodes (13): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, _formatDate, NewsDetailScreen, _openLink, post (+5 more)

### Community 38 - "Community 38"
Cohesion: 0.14
Nodes (14): dart:async, dart:io, build, _channel, createState, _muted, _playing, RadioPlayerBar (+6 more)

### Community 39 - "Community 39"
Cohesion: 0.18
Nodes (13): BannerAd?, adsEnabledProvider, _ad, build, createState, dispose, initState, _loadAd (+5 more)

### Community 40 - "Community 40"
Cohesion: 0.14
Nodes (13): cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation, google_sign_in_ios (+5 more)

### Community 41 - "Community 41"
Cohesion: 0.15
Nodes (13): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+5 more)

### Community 42 - "Community 42"
Cohesion: 0.14
Nodes (13): _api, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _tokenKey, updatePreferences (+5 more)

### Community 43 - "Community 43"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 44 - "Community 44"
Cohesion: 0.15
Nodes (9): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/post.dart, package:hungarian_hardstyle_app/models/profile_submission.dart, main, main, main (+1 more)

### Community 45 - "Community 45"
Cohesion: 0.18
Nodes (11): AnimationController, BrandLoadingIndicator, _BrandLoadingIndicatorState, build, _controller, createState, didChangeDependencies, dispose (+3 more)

### Community 46 - "Community 46"
Cohesion: 0.23
Nodes (12): ConsumerState, ConsumerStatefulWidget, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, LiveFeedScreen, _LiveFeedScreenState (+4 more)

### Community 47 - "Community 47"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 48 - "Community 48"
Cohesion: 0.23
Nodes (12): InAppBrowserScreen, _InAppBrowserScreenState, GalleryScreen, _GalleryScreenState, _NewsSlider, _NewsSliderState, SettingsScreen, _SettingsScreenState (+4 more)

### Community 49 - "Community 49"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 50 - "Community 50"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 51 - "Community 51"
Cohesion: 0.18
Nodes (8): AppTheme, build, PrivacyScreen, build, genre, GenreChip, package:flutter/material.dart, ../screens/genres/genre_discovery_screen.dart

### Community 52 - "Community 52"
Cohesion: 0.20
Nodes (10): FavoriteKind, favoritesProvider, build, _OrganizerContent, build, FavoriteButton, id, kind (+2 more)

### Community 53 - "Community 53"
Cohesion: 0.18
Nodes (10): build, _controller, createState, _current, dispose, images, initialIndex, initState (+2 more)

### Community 54 - "Community 54"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 55 - "Community 55"
Cohesion: 0.20
Nodes (8): admin, db, { defineSecret }, { getFirestore }, { onCall, HttpsError }, submissionRoutes, WORDPRESS_APPLICATION_PASSWORD, WORDPRESS_USERNAME

### Community 56 - "Community 56"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 57 - "Community 57"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 58 - "Community 58"
Cohesion: 0.22
Nodes (8): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, ../../providers/events_provider.dart, ../../widgets/event_card.dart

### Community 59 - "Community 59"
Cohesion: 0.22
Nodes (7): enableTestAds, package:flutter_riverpod/flutter_riverpod.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/providers/ads_provider.dart, package:hungarian_hardstyle_app/providers/events_provider.dart, package:hungarian_hardstyle_app/providers/news_provider.dart, main

### Community 60 - "Community 60"
Cohesion: 0.22
Nodes (9): _openProfile, build, _artistContent, _postContent, _open, build, _handleOpenedMessage, build (+1 more)

### Community 61 - "Community 61"
Cohesion: 0.22
Nodes (8): _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart, static const, static final Dio

### Community 62 - "Community 62"
Cohesion: 0.32
Nodes (5): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit, XCTest

### Community 63 - "Community 63"
Cohesion: 0.22
Nodes (7): FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 64 - "Community 64"
Cohesion: 0.25
Nodes (7): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List

### Community 65 - "Community 65"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 66 - "Community 66"
Cohesion: 0.29
Nodes (6): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, _label, ../news/news_detail_screen.dart, ../organizers/organizer_detail_screen.dart, ../../providers/news_provider.dart

### Community 67 - "Community 67"
Cohesion: 0.29
Nodes (5): Cocoa, FlutterMacOS, AppDelegate, Bool, NSApplication

### Community 68 - "Community 68"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 69 - "Community 69"
Cohesion: 0.22
Nodes (9): _ArtistCard, _ArtistError, _CategoryChip, _Composer, _ArtistLinks, _InfoRow, _Empty, _Section (+1 more)

### Community 70 - "Community 70"
Cohesion: 0.33
Nodes (5): watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 71 - "Community 71"
Cohesion: 0.33
Nodes (4): package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/widgets/event_card.dart, main, main

### Community 72 - "Community 72"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 73 - "Community 73"
Cohesion: 0.40
Nodes (4): getEvents, getEventSubmissionGenres, service, ../models/event.dart

### Community 74 - "Community 74"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 75 - "Community 75"
Cohesion: 0.33
Nodes (5): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 77 - "Community 77"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

## Knowledge Gaps
- **811 isolated node(s):** `{ onCall, HttpsError }`, `{ defineSecret }`, `admin`, `{ getFirestore }`, `db` (+806 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Artist` connect `Community 17` to `Community 9`, `Community 21`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `Post` connect `Community 18` to `Community 2`, `Community 37`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `OrganizerProfile` connect `Community 41` to `Community 33`, `Community 10`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `{ onCall, HttpsError }`, `{ defineSecret }`, `admin` to the rest of the system?**
  _811 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06120218579234973 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._