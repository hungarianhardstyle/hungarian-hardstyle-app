# Graph Report - hungarian_hardstyle_app  (2026-08-06)

## Corpus Check
- 156 files · ~260,592 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1940 nodes · 2586 edges · 118 communities (108 shown, 10 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a4a4696d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_screen.dart
- community_service.dart
- Win32Window
- wordpress_service.dart
- post.dart
- Hungarian Hardstyle – FAQ vázlat
- PROJECT_CONTEXT.md
- event.dart
- news_provider.dart
- profile_submission.dart
- community_users_screen.dart
- artist.dart
- event_submission_screen.dart
- Roadmap
- favorites_provider.dart
- wordpress_admin_screen.dart
- artists_screen.dart
- genre_discovery_screen.dart
- package:flutter_test/flutter_test.dart
- organizer.dart
- artist_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- organizer_submission_screen.dart
- my_application.cc
- home_screen.dart
- more_screen.dart
- RadioPlaybackService
- settings_screen.dart
- newsroom/app/main.py
- Roadmap
- main_navigation.dart
- post_embed_card.dart
- radio_player_bar.dart
- event_detail_screen.dart
- html_linkifier.dart
- Hungarian Hardstyle App - Project Context for AI Agents
- tagged_news_screen.dart
- event_submission.dart
- in_app_browser.dart
- List
- communityServiceProvider
- artist_detail_screen.dart
- MaterialPageRoute
- event_card.dart
- push_notification_service.dart
- mobile_ad_banner.dart
- news_detail_screen.dart
- index.js
- news_screen.dart
- GeneratedPluginRegistrant.swift
- events_screen.dart
- organizer_detail_screen.dart
- ConsumerWidget
- newsletter_screen.dart
- main.dart
- static const
- State
- _GenreDiscoveryScreenState
- featured_news_card.dart
- wWinMain
- submission_image_picker.dart
- faq_screen.dart
- package.json
- ConsumerState
- gallery_screen.dart
- manifest.json
- favorite_button.dart
- hungarian-hardstyle-newsroom/app/graphics.py
- about_screen.dart
- spotify_player.dart
- startup_gate.dart
- Hungarian Hardstyle Newsroom GPT v2
- social_contact_screen.dart
- package:flutter_riverpod/flutter_riverpod.dart
- ios/RunnerTests/RunnerTests.swift
- AppDelegate
- Hungarian Hardstyle Newsroom v2
- Newsroom GPT v2 telepítés
- Newsroom GPT v2 elfogadási tesztek
- faq.dart
- profile_submission_provider.dart
- brand_loading_indicator.dart
- FlutterMacOS
- dart:async
- artists_provider.dart
- AppDelegate
- Hungarian Hardstyle szerkesztőségi referencia
- Main Brands
- Cloudinary Image Upload Demo
- Hungarian Hardstyle Newsroom
- RunnerTests
- _EventSubmissionScreenState
- RegisterGeneratedPlugins
- Release And Store Business Model
- OpenAPITests
- KNOWLEDGE-SEO.md
- hungarian-hardstyle-newsroom/app/__init__.py
- LaunchImage.imageset/README.md
- newsroom/app/__init__.py
- newsroom/README.md
- @hungarianhardstyle
- hungarian-hardstyle-newsroom
- hungarian-hardstyle-newsroom
- String?
- SubmissionImage
- package:flutter/material.dart
- community_provider.dart
- genre_chip.dart

## God Nodes (most connected - your core abstractions)
1. `Roadmap` - 23 edges
2. `Win32Window` - 22 edges
3. `communityServiceProvider` - 21 edges
4. `Hungarian Hardstyle App - Project Context for AI Agents` - 21 edges
5. `Roadmap` - 16 edges
6. `RadioPlaybackService` - 15 edges
7. `MessageHandler` - 12 edges
8. `Current status` - 12 edges
9. `Hungarian Hardstyle – FAQ vázlat` - 12 edges
10. `update_metadata()` - 11 edges

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

## Communities (118 total, 10 thin omitted)

### Community 0 - "community_screen.dart"
Cohesion: 0.02
Nodes (82): CommunityService get, dart:math, _anonymous, _authSubscription, _avatarFocusX, _avatarFocusY, _avatarLetter, _avatarPanX (+74 more)

### Community 1 - "community_service.dart"
Cohesion: 0.02
Nodes (85): accessAdmin, accessModerator, accessNone, accountRole, adminBlockUser, adminEmail, _anonymousNumber, _attendance (+77 more)

### Community 2 - "Win32Window"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 3 - "wordpress_service.dart"
Cohesion: 0.04
Nodes (48): Dio, _allowedImageExtensions, _cloudinaryCloudName, _cloudinaryUploadPreset, count, _decodePossiblyPrefixedJson, _dio, fallback (+40 more)

### Community 4 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 5 - "Hungarian Hardstyle – FAQ vázlat"
Cohesion: 0.04
Nodes (45): Adatvédelem, Az appról, Chat, DJ-k és szervezők, Elfelejtettem a jelszavam. Mit tegyek?, Események, Fiók és profil, Használható a Chat regisztráció nélkül? (+37 more)

### Community 6 - "PROJECT_CONTEXT.md"
Cohesion: 0.04
Nodes (45): AI-assisted editorial importer, AI-assisted English post translation, Annual Top DJ And Track Voting, Architecture, Artists, Authentication, Current Version, Current WordPress Modules (+37 more)

### Community 7 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 8 - "news_provider.dart"
Cohesion: 0.07
Nodes (27): categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading, isLoadingMore (+19 more)

### Community 9 - "profile_submission.dart"
Cohesion: 0.05
Nodes (37): DateTime?, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+29 more)

### Community 10 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (41): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+33 more)

### Community 11 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 12 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 13 - "Roadmap"
Cohesion: 0.06
Nodes (34): Brands, Current bug-fix backlog, Current status, FAQ-választervezet, Hungarian Hardstyle App, Language direction, Long-term vision, Navigation direction (+26 more)

### Community 14 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (32): ChangeNotifier, dart:convert, FirebaseAuth, FirebaseFirestore, _auth, _authSubscription, clearAll, _clearCloud (+24 more)

### Community 15 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (34): build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections, _deleteUser (+26 more)

### Community 16 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 17 - "genre_discovery_screen.dart"
Cohesion: 0.07
Nodes (29): _artistHasMore, _artistPage, _artists, build, child, createState, dispose, _Empty (+21 more)

### Community 18 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (22): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+14 more)

### Community 19 - "organizer.dart"
Cohesion: 0.05
Nodes (44): event.dart, 0, city, country, description, excerpt, false, featured (+36 more)

### Community 20 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 21 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 22 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (24): class, build, _city, _contactEmail, _country, createState, _description, dispose (+16 more)

### Community 23 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 24 - "home_screen.dart"
Cohesion: 0.15
Nodes (13): _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews, _page (+5 more)

### Community 25 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 26 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 27 - "settings_screen.dart"
Cohesion: 0.09
Nodes (21): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+13 more)

### Community 28 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 29 - "Roadmap"
Cohesion: 0.09
Nodes (23): Roadmap, v0.4 - Foundation, v0.5 - Dynamic Events, v0.6 - DJ Database, v0.7 - Organizers, v0.8 - Rich Content, v0.95 - Media, v0.97 - Polish build (complete) (+15 more)

### Community 30 - "main_navigation.dart"
Cohesion: 0.09
Nodes (21): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+13 more)

### Community 31 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 32 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 33 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 34 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 35 - "Hungarian Hardstyle App - Project Context for AI Agents"
Cohesion: 0.11
Nodes (18): Agent Reminder, Android Notes, API Direction, Coding Style, Content Language, Core Product Direction, Current State, Data Source Rule (+10 more)

### Community 36 - "tagged_news_screen.dart"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+8 more)

### Community 37 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 38 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 39 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../screens/news/news_detail_screen.dart

### Community 40 - "communityServiceProvider"
Cohesion: 0.14
Nodes (14): communityServiceProvider, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _delete, _moderateUser, _PostCard (+6 more)

### Community 41 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 42 - "MaterialPageRoute"
Cohesion: 0.20
Nodes (10): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, build, _artistContent, _postContent, build, _open (+2 more)

### Community 43 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 44 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (18): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+10 more)

### Community 45 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 46 - "news_detail_screen.dart"
Cohesion: 0.12
Nodes (14): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, formatEventDate, formatHungarianDate, build, _formatDate, NewsDetailScreen, _openLink (+6 more)

### Community 47 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 48 - "news_screen.dart"
Cohesion: 0.15
Nodes (16): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+8 more)

### Community 49 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.13
Nodes (14): cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation, google_sign_in_ios (+6 more)

### Community 50 - "events_screen.dart"
Cohesion: 0.12
Nodes (14): ../artists/artist_detail_screen.dart, event_submission_screen.dart, ../events/event_detail_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, _label (+6 more)

### Community 51 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name, organizer (+5 more)

### Community 52 - "ConsumerWidget"
Cohesion: 0.19
Nodes (15): ConsumerWidget, communityAuthProvider, eventsProvider, newsProvider, CommunityAvatarButton, _openPlannedEvent, _PostAuthorAvatar, build (+7 more)

### Community 53 - "newsletter_screen.dart"
Cohesion: 0.14
Nodes (14): FormState, build, _consent, createState, dispose, _emailController, _formKey, _hostedSignupUrl (+6 more)

### Community 54 - "main.dart"
Cohesion: 0.15
Nodes (12): ../core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 55 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 56 - "State"
Cohesion: 0.22
Nodes (13): CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, SettingsScreen, _SettingsScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, PostEmbedCard, _PostEmbedCardState (+5 more)

### Community 57 - "_GenreDiscoveryScreenState"
Cohesion: 0.67
Nodes (3): wordpressServiceProvider, GenreDiscoveryScreen, _GenreDiscoveryScreenState

### Community 58 - "featured_news_card.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 59 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 60 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 61 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 62 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 63 - "ConsumerState"
Cohesion: 0.27
Nodes (10): ConsumerState, ConsumerStatefulWidget, EventDetailScreen, _EventDetailScreenState, CommunityUsersScreen, _CommunityUsersScreenState, TaggedNewsScreen, _TaggedNewsScreenState (+2 more)

### Community 64 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 65 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 66 - "favorite_button.dart"
Cohesion: 0.20
Nodes (10): FavoriteKind, favoritesProvider, build, _OrganizerContent, build, FavoriteButton, id, kind (+2 more)

### Community 67 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 68 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 69 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 70 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 71 - "Hungarian Hardstyle Newsroom GPT v2"
Cohesion: 0.22
Nodes (8): Egyetlen munkafolyamat, Forráskezelési módok, GPT, Hungarian Hardstyle Newsroom GPT v2, Rendszerhatárok, Stabilitási szabály, Tudatosan nincs benne, WordPress Action

### Community 72 - "social_contact_screen.dart"
Cohesion: 0.22
Nodes (8): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value

### Community 73 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.25
Nodes (6): enableTestAds, getOrganizer, getOrganizers, service, ../models/organizer.dart, package:flutter_riverpod/flutter_riverpod.dart

### Community 74 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.32
Nodes (5): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit, XCTest

### Community 75 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 76 - "Hungarian Hardstyle Newsroom v2"
Cohesion: 0.25
Nodes (7): Automatikus workflow, Feladattípus, Hungarian Hardstyle Newsroom v2, SEO, Social, Tények, WordPress Action

### Community 77 - "Newsroom GPT v2 telepítés"
Cohesion: 0.25
Nodes (7): 1. Új GPT, 2. Instructions, 3. Knowledge, 4. Képességek, 5. Action, 6. Mentés és teszt, Newsroom GPT v2 telepítés

### Community 78 - "Newsroom GPT v2 elfogadási tesztek"
Cohesion: 0.25
Nodes (7): Newsroom GPT v2 elfogadási tesztek, T1 – Action, T2 – URL, T3 – Screenshot, T4 – Több screenshot, T5 – Forrásvédelem, T6 – Hibás Action

### Community 79 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 80 - "profile_submission_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 81 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 82 - "FlutterMacOS"
Cohesion: 0.38
Nodes (4): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow

### Community 83 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 84 - "artists_provider.dart"
Cohesion: 0.29
Nodes (6): ArtistListQuery, getArtist, getArtists, service, ../models/artist.dart, typedef

### Community 85 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 86 - "Hungarian Hardstyle szerkesztőségi referencia"
Cohesion: 0.33
Nodes (5): Forrásmegjelölés, Hangvétel, Hungarian Hardstyle szerkesztőségi referencia, Megnevezések, Tények

### Community 87 - "Main Brands"
Cohesion: 0.40
Nodes (5): Hard Lake, Hardstyle Revolution, Hungarian Hardstyle, Main Brands, Rave Revolution

### Community 88 - "Cloudinary Image Upload Demo"
Cohesion: 0.40
Nodes (4): Beállítás, Cloudinary Image Upload Demo, Futtatás, Telepítés

### Community 89 - "Hungarian Hardstyle Newsroom"
Cohesion: 0.40
Nodes (4): API, Hungarian Hardstyle Newsroom, Local run, Required Render variables

### Community 90 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 91 - "_EventSubmissionScreenState"
Cohesion: 0.50
Nodes (4): eventSubmissionGenresProvider, build, EventSubmissionScreen, _EventSubmissionScreenState

### Community 92 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

### Community 93 - "Release And Store Business Model"
Cohesion: 0.67
Nodes (3): Free Release, Premium Release, Release And Store Business Model

### Community 114 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List?

### Community 115 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (15): ../core/navigation/in_app_browser.dart, build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen (+7 more)

### Community 116 - "community_provider.dart"
Cohesion: 0.20
Nodes (9): communityPostsProvider, watch, build, LiveFeedScreen, _LiveFeedScreenState, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart (+1 more)

### Community 119 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

## Knowledge Gaps
- **1185 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1180 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CommunityService` connect `community_provider.dart` to `community_screen.dart`, `community_service.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `Artist` connect `artist_detail_screen.dart` to `artists_screen.dart`, `artist.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `HuhsEvent` connect `event_card.dart` to `event_detail_screen.dart`, `event.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1185 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._