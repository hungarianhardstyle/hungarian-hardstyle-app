# Graph Report - hungarian_hardstyle_app  (2026-07-30)

## Corpus Check
- 152 files · ~248,633 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1759 nodes · 2315 edges · 113 communities (101 shown, 12 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `73215dcd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- Win32Window
- community_service.dart
- wordpress_service.dart
- event_submission_screen.dart
- post.dart
- artists_screen.dart
- Hungarian Hardstyle – FAQ vázlat
- event.dart
- Hungarian Hardstyle App - Project Context for AI Agents
- PROJECT_CONTEXT.md
- artist.dart
- wordpress_admin_screen.dart
- organizer.dart
- package:flutter_test/flutter_test.dart
- package:flutter/material.dart
- news_provider.dart
- artist_submission_screen.dart
- genre_discovery_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- organizer_submission_screen.dart
- my_application.cc
- Roadmap
- newsroom/app/main.py
- profile_submission.dart
- settings_screen.dart
- main_navigation.dart
- event_card.dart
- RadioPlaybackService
- MaterialPageRoute
- html_linkifier.dart
- post_embed_card.dart
- event_submission.dart
- organizer_detail_screen.dart
- more_screen.dart
- news_screen.dart
- favorites_provider.dart
- community_post.dart
- tagged_news_screen.dart
- organizers_screen.dart
- startup_gate.dart
- radio_player_bar.dart
- in_app_browser.dart
- ConsumerState
- index.js
- mobile_ad_banner.dart
- GeneratedPluginRegistrant.swift
- newsletter_screen.dart
- event_detail_screen.dart
- push_notification_service.dart
- communityServiceProvider
- main.dart
- artist_detail_screen.dart
- events_screen.dart
- wWinMain
- gallery_screen.dart
- submission_image_picker.dart
- package.json
- State
- ConsumerWidget
- manifest.json
- favorites_screen.dart
- FlutterMacOS
- dart:async
- List
- hungarian-hardstyle-newsroom/app/graphics.py
- AppDelegate
- spotify_player.dart
- brand_loading_indicator.dart
- AppDelegate
- Hungarian Hardstyle Newsroom GPT v2
- StatelessWidget
- ios/RunnerTests/RunnerTests.swift
- Hungarian Hardstyle Newsroom v2
- Newsroom GPT v2 telepítés
- Newsroom GPT v2 elfogadási tesztek
- profile_submission_provider.dart
- image_saver.dart
- community_provider.dart
- SubmissionImage
- RegisterGeneratedPlugins
- Hungarian Hardstyle szerkesztőségi referencia
- Cloudinary Image Upload Demo
- Hungarian Hardstyle Newsroom
- RunnerTests
- static const
- eventsProvider
- OpenAPITests
- _EventSubmissionScreenState
- KNOWLEDGE-SEO.md
- hungarian-hardstyle-newsroom/app/__init__.py
- LaunchImage.imageset/README.md
- newsroom/app/__init__.py
- newsroom/README.md
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- organizers_provider.dart
- home_screen.dart
- hungarian-hardstyle-newsroom
- package:flutter_riverpod/flutter_riverpod.dart
- String?
- _GenreDiscoveryScreenState
- _WordPressAdminScreenState

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `Hungarian Hardstyle App - Project Context for AI Agents` - 21 edges
3. `communityServiceProvider` - 17 edges
4. `RadioPlaybackService` - 15 edges
5. `Roadmap` - 15 edges
6. `Roadmap` - 15 edges
7. `MessageHandler` - 12 edges
8. `Hungarian Hardstyle – FAQ vázlat` - 12 edges
9. `update_metadata()` - 11 edges
10. `FlutterWindow` - 10 edges

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

## Communities (113 total, 12 thin omitted)

### Community 0 - "community_screen.dart"
Cohesion: 0.03
Nodes (77): CommunityService get, dart:math, DocumentSnapshot, _anonymous, _authSubscription, _avatarFocusX, _avatarFocusY, _avatarLetter (+69 more)

### Community 1 - "Win32Window"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 2 - "community_service.dart"
Cohesion: 0.04
Nodes (50): FirebaseAuth, FirebaseFirestore, accessAdmin, accessModerator, accessNone, accountRole, adminEmail, _anonymousNumber (+42 more)

### Community 3 - "wordpress_service.dart"
Cohesion: 0.04
Nodes (47): Dio, _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback (+39 more)

### Community 4 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (37): int?, _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate (+29 more)

### Community 5 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 6 - "artists_screen.dart"
Cohesion: 0.11
Nodes (19): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, ArtistsScreen, _ArtistsScreenState, build, _category (+11 more)

### Community 7 - "Hungarian Hardstyle – FAQ vázlat"
Cohesion: 0.04
Nodes (45): Adatvédelem, Az appról, Chat, DJ-k és szervezők, Elfelejtettem a jelszavam. Mit tegyek?, Események, Fiók és profil, Használható a Chat regisztráció nélkül? (+37 more)

### Community 8 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 9 - "Hungarian Hardstyle App - Project Context for AI Agents"
Cohesion: 0.05
Nodes (41): Agent Reminder, Android Notes, API Direction, Coding Style, Content Language, Core Product Direction, Current State, Data Source Rule (+33 more)

### Community 10 - "PROJECT_CONTEXT.md"
Cohesion: 0.05
Nodes (41): AI-assisted editorial importer, AI-assisted English post translation, Annual Top DJ And Track Voting, Architecture, Artists, Authentication, Current Version, Current WordPress Modules (+33 more)

### Community 11 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 12 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (32): build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections, _deleteUser (+24 more)

### Community 13 - "organizer.dart"
Cohesion: 0.06
Nodes (30): event.dart, 0, city, country, description, excerpt, false, featured (+22 more)

### Community 14 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (22): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+14 more)

### Community 15 - "package:flutter/material.dart"
Cohesion: 0.07
Nodes (28): ../core/navigation/in_app_browser.dart, IconData, AboutScreen, build, icon, _InfoTile, label, onTap (+20 more)

### Community 16 - "news_provider.dart"
Cohesion: 0.07
Nodes (27): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+19 more)

### Community 17 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 18 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (27): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _error (+19 more)

### Community 19 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 20 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (24): class, build, _city, _contactEmail, _country, createState, _description, dispose (+16 more)

### Community 21 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 22 - "Roadmap"
Cohesion: 0.08
Nodes (25): Brands, Current bug-fix backlog, Current status, Hungarian Hardstyle App, Language direction, Long-term vision, Navigation direction, Roadmap (+17 more)

### Community 23 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 24 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 25 - "settings_screen.dart"
Cohesion: 0.10
Nodes (19): build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState, _loading (+11 more)

### Community 26 - "main_navigation.dart"
Cohesion: 0.09
Nodes (21): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+13 more)

### Community 27 - "event_card.dart"
Cohesion: 0.09
Nodes (24): ../core/content/date_formatters.dart, double?, favorite_button.dart, genre_chip.dart, HuhsEvent, FavoriteKind, build, event (+16 more)

### Community 28 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterActivity, FlutterEngine, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 29 - "MaterialPageRoute"
Cohesion: 0.11
Nodes (19): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, _openProfile, _readOnlyProfileWidgets, build, _artistContent, _postContent, _open (+11 more)

### Community 30 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 31 - "post_embed_card.dart"
Cohesion: 0.11
Nodes (17): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+9 more)

### Community 32 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 33 - "organizer_detail_screen.dart"
Cohesion: 0.18
Nodes (10): _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name, organizer, organizerId, _socialLabel (+2 more)

### Community 34 - "more_screen.dart"
Cohesion: 0.11
Nodes (18): about_screen.dart, ../artists/artists_screen.dart, favorites_screen.dart, icon, _MenuCard, onTap, _SubmissionCard, subtitle (+10 more)

### Community 35 - "news_screen.dart"
Cohesion: 0.16
Nodes (15): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+7 more)

### Community 36 - "favorites_provider.dart"
Cohesion: 0.12
Nodes (16): ChangeNotifier, dart:convert, Future, contains, entries, FavoriteEntry, FavoritesNotifier, id (+8 more)

### Community 37 - "community_post.dart"
Cohesion: 0.12
Nodes (16): DateTime?, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+8 more)

### Community 38 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 39 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError (+5 more)

### Community 40 - "startup_gate.dart"
Cohesion: 0.11
Nodes (18): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+10 more)

### Community 41 - "radio_player_bar.dart"
Cohesion: 0.10
Nodes (20): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+12 more)

### Community 42 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 43 - "ConsumerState"
Cohesion: 0.23
Nodes (12): ConsumerState, ConsumerStatefulWidget, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, LiveFeedScreen, _LiveFeedScreenState (+4 more)

### Community 44 - "index.js"
Cohesion: 0.13
Nodes (10): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, submissionRoutes, WORDPRESS_ADMIN_PATHS (+2 more)

### Community 45 - "mobile_ad_banner.dart"
Cohesion: 0.18
Nodes (13): BannerAd?, adsEnabledProvider, _ad, build, createState, dispose, initState, _loadAd (+5 more)

### Community 46 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.14
Nodes (13): cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation, google_sign_in_ios (+5 more)

### Community 47 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 48 - "event_detail_screen.dart"
Cohesion: 0.11
Nodes (16): formatEventDate, formatHungarianDate, _ArtistLinks, artists, _descriptionHtml, _escapeHtml, event, EventDetailScreen (+8 more)

### Community 49 - "push_notification_service.dart"
Cohesion: 0.14
Nodes (13): _api, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _tokenKey, updatePreferences (+5 more)

### Community 50 - "communityServiceProvider"
Cohesion: 0.22
Nodes (11): communityAuthProvider, communityPostsProvider, communityServiceProvider, build, CommunityAvatarButton, _delete, _editCustomResource, _editStartup (+3 more)

### Community 51 - "main.dart"
Cohesion: 0.15
Nodes (12): ../core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 52 - "artist_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Artist, artistDetailProvider, ArtistListQuery, getArtist, getArtists, service, artist, _ArtistContent (+14 more)

### Community 53 - "events_screen.dart"
Cohesion: 0.20
Nodes (9): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, ../../providers/events_provider.dart, VoidCallback (+1 more)

### Community 54 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 55 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 56 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 57 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 58 - "State"
Cohesion: 0.27
Nodes (10): InAppBrowserScreen, _InAppBrowserScreenState, _NewsSlider, _NewsSliderState, SettingsScreen, _SettingsScreenState, PostEmbedCard, _PostEmbedCardState (+2 more)

### Community 59 - "ConsumerWidget"
Cohesion: 0.20
Nodes (12): ConsumerWidget, favoritesProvider, organizerDetailProvider, _PostAuthorAvatar, build, FavoritesScreen, MoreScreen, build (+4 more)

### Community 60 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 61 - "favorites_screen.dart"
Cohesion: 0.29
Nodes (6): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, _label, ../news/news_detail_screen.dart, ../organizers/organizer_detail_screen.dart, ../../providers/news_provider.dart

### Community 62 - "FlutterMacOS"
Cohesion: 0.38
Nodes (4): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow

### Community 63 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 64 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../models/post.dart

### Community 65 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 66 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 67 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 68 - "brand_loading_indicator.dart"
Cohesion: 0.20
Nodes (10): AnimationController, BrandLoadingIndicator, _BrandLoadingIndicatorState, build, _controller, createState, didChangeDependencies, dispose (+2 more)

### Community 69 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 70 - "Hungarian Hardstyle Newsroom GPT v2"
Cohesion: 0.22
Nodes (8): Egyetlen munkafolyamat, Forráskezelési módok, GPT, Hungarian Hardstyle Newsroom GPT v2, Rendszerhatárok, Stabilitási szabály, Tudatosan nincs benne, WordPress Action

### Community 71 - "StatelessWidget"
Cohesion: 0.14
Nodes (13): _ArtistCard, _ArtistError, _CategoryChip, _Composer, _ProfileAvatar, _InfoRow, _Empty, _Section (+5 more)

### Community 72 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.32
Nodes (5): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit, XCTest

### Community 73 - "Hungarian Hardstyle Newsroom v2"
Cohesion: 0.25
Nodes (7): Automatikus workflow, Feladattípus, Hungarian Hardstyle Newsroom v2, SEO, Social, Tények, WordPress Action

### Community 74 - "Newsroom GPT v2 telepítés"
Cohesion: 0.25
Nodes (7): 1. Új GPT, 2. Instructions, 3. Knowledge, 4. Képességek, 5. Action, 6. Mentés és teszt, Newsroom GPT v2 telepítés

### Community 75 - "Newsroom GPT v2 elfogadási tesztek"
Cohesion: 0.25
Nodes (7): Newsroom GPT v2 elfogadási tesztek, T1 – Action, T2 – URL, T3 – Screenshot, T4 – Több screenshot, T5 – Forrásvédelem, T6 – Hibás Action

### Community 76 - "profile_submission_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 77 - "image_saver.dart"
Cohesion: 0.25
Nodes (7): _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart, static final Dio

### Community 78 - "community_provider.dart"
Cohesion: 0.33
Nodes (5): watch, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../../services/community_service.dart

### Community 79 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List?

### Community 80 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

### Community 81 - "Hungarian Hardstyle szerkesztőségi referencia"
Cohesion: 0.33
Nodes (5): Forrásmegjelölés, Hangvétel, Hungarian Hardstyle szerkesztőségi referencia, Megnevezések, Tények

### Community 82 - "Cloudinary Image Upload Demo"
Cohesion: 0.40
Nodes (4): Beállítás, Cloudinary Image Upload Demo, Futtatás, Telepítés

### Community 83 - "Hungarian Hardstyle Newsroom"
Cohesion: 0.40
Nodes (4): API, Hungarian Hardstyle Newsroom, Local run, Required Render variables

### Community 84 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 85 - "static const"
Cohesion: 0.40
Nodes (4): AppTheme, backgroundDecoration, package:google_fonts/google_fonts.dart, static const

### Community 86 - "eventsProvider"
Cohesion: 0.33
Nodes (7): eventsProvider, newsProvider, build, EventsScreen, build, HomeScreen, _openEntry

### Community 88 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 104 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 105 - "home_screen.dart"
Cohesion: 0.15
Nodes (12): _controller, createState, dispose, initState, onShowMoreNews, _page, posts, _timer (+4 more)

### Community 111 - "_GenreDiscoveryScreenState"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

## Knowledge Gaps
- **1052 isolated node(s):** `functions`, `{ defineSecret }`, `admin`, `{ getFirestore }`, `db` (+1047 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Artist` connect `artist_detail_screen.dart` to `artist.dart`, `artists_screen.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `OrganizerProfile` connect `organizers_screen.dart` to `organizer_detail_screen.dart`, `organizer.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `FlutterWindow` connect `Win32Window` to `RegisterGeneratedPlugins`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `functions`, `{ defineSecret }`, `admin` to the rest of the system?**
  _1052 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02564102564102564 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._