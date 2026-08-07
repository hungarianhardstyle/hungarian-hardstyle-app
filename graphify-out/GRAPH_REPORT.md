# Graph Report - .  (2026-08-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1828 nodes · 2554 edges · 101 communities (94 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7f7b3959`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- post.dart
- genre_discovery_screen.dart
- wordpress_admin_screen.dart
- releases_screen.dart
- event_submission_screen.dart
- event.dart
- news_provider.dart
- community_users_screen.dart
- artist.dart
- widget_test.dart
- favorites_provider.dart
- organizer.dart
- artist_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- my_application.cc
- organizer_submission_screen.dart
- communityServiceProvider
- more_screen.dart
- RadioPlaybackService
- main_navigation.dart
- voting.dart
- settings_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- ConsumerWidget
- event_detail_screen.dart
- post_embed_card.dart
- profile_submission.dart
- html_linkifier.dart
- package:flutter/material.dart
- event_submission.dart
- tagged_news_screen.dart
- radio_player_bar.dart
- artist_detail_screen.dart
- push_notification_service.dart
- startup_gate.dart
- GeneratedPluginRegistrant.swift
- events_screen.dart
- mobile_ad_banner.dart
- index.js
- in_app_browser.dart
- news_screen.dart
- organizers_screen.dart
- community_post.dart
- release.dart
- home_screen.dart
- organizer_detail_screen.dart
- faq_screen.dart
- main.dart
- static const
- gallery_screen.dart
- brand_loading_indicator.dart
- package:cached_network_image/cached_network_image.dart
- voting_service.dart
- wWinMain
- news_detail_screen.dart
- event_card.dart
- package.json
- favorite_button.dart
- MaterialPageRoute
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- State
- about_screen.dart
- spotify_player.dart
- social_contact_screen.dart
- List
- FlutterMacOS
- AppDelegate
- faq.dart
- news_provider.dart
- package:flutter_riverpod/flutter_riverpod.dart
- community_provider.dart
- dart:async
- ios/RunnerTests/RunnerTests.swift
- SubmissionImage
- AppDelegate
- artists_provider.dart
- RunnerTests
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
9. `eventsProvider` - 9 edges
10. `MessageHandler` - 9 edges

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

## Communities (101 total, 7 thin omitted)

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

### Community 5 - "genre_discovery_screen.dart"
Cohesion: 0.05
Nodes (46): wordpressServiceProvider, votingServiceProvider, _artistHasMore, _artistPage, _artists, build, child, createState (+38 more)

### Community 6 - "wordpress_admin_screen.dart"
Cohesion: 0.04
Nodes (45): _adminField, build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections (+37 more)

### Community 7 - "releases_screen.dart"
Cohesion: 0.05
Nodes (41): AudioPlayer, Duration, HuhsRelease, ReleaseTrack, ReleaseQuery, releasesProvider, build, _label (+33 more)

### Community 8 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (43): formatEventDate, formatHungarianDate, eventSubmissionGenresProvider, _addressController, build, _cityController, createState, _descriptionController (+35 more)

### Community 9 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 10 - "news_provider.dart"
Cohesion: 0.05
Nodes (41): FormState, categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading (+33 more)

### Community 11 - "community_users_screen.dart"
Cohesion: 0.06
Nodes (40): DocumentSnapshot, _Composer, _PostAuthorLabels, _ProfileAvatar, _action, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen (+32 more)

### Community 12 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 13 - "widget_test.dart"
Cohesion: 0.06
Nodes (24): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+16 more)

### Community 14 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (30): ChangeNotifier, dart:convert, _auth, _authSubscription, clearAll, _clearCloud, contains, _databaseId (+22 more)

### Community 15 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 16 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 17 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 18 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 19 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (25): class, build, _city, _contactEmail, _country, createState, _description, dispose (+17 more)

### Community 20 - "communityServiceProvider"
Cohesion: 0.12
Nodes (25): ConsumerState, ConsumerStatefulWidget, communityServiceProvider, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _delete (+17 more)

### Community 21 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 22 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 23 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 24 - "voting.dart"
Cohesion: 0.08
Nodes (22): active, artist, candidates, categories, fromJson, id, image, inactive (+14 more)

### Community 25 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 26 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 27 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 28 - "ConsumerWidget"
Cohesion: 0.12
Nodes (22): ConsumerWidget, communityAuthProvider, eventsProvider, newsProvider, votingProvider, CommunityAvatarButton, _openPlannedEvent, _PostAuthorAvatar (+14 more)

### Community 29 - "event_detail_screen.dart"
Cohesion: 0.09
Nodes (22): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+14 more)

### Community 30 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 31 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 32 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 33 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (15): ../core/navigation/in_app_browser.dart, build, DonateScreen, _donateUri, build, PrivacyScreen, build, RadioProviderScreen (+7 more)

### Community 34 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 35 - "tagged_news_screen.dart"
Cohesion: 0.11
Nodes (18): build, createState, dispose, _error, _hasMore, _hasTag, initState, _loading (+10 more)

### Community 36 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (17): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+9 more)

### Community 37 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 38 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (17): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+9 more)

### Community 39 - "startup_gate.dart"
Cohesion: 0.12
Nodes (17): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+9 more)

### Community 40 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 41 - "events_screen.dart"
Cohesion: 0.12
Nodes (14): ../artists/artist_detail_screen.dart, event_submission_screen.dart, ../events/event_detail_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, _label (+6 more)

### Community 42 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 43 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 44 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (15): build, _controller, createState, _handleSystemBack, initialUri, initState, normalizedUrl, of (+7 more)

### Community 45 - "news_screen.dart"
Cohesion: 0.16
Nodes (15): paginatedNewsProvider, build, createState, dispose, initState, NewsScreen, _NewsScreenState, _onScroll (+7 more)

### Community 46 - "organizers_screen.dart"
Cohesion: 0.14
Nodes (15): organizersProvider, build, createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard (+7 more)

### Community 47 - "community_post.dart"
Cohesion: 0.13
Nodes (14): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+6 more)

### Community 48 - "release.dart"
Cohesion: 0.13
Nodes (14): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+6 more)

### Community 49 - "home_screen.dart"
Cohesion: 0.14
Nodes (14): _controller, createState, dispose, initState, _NewsSlider, _NewsSliderState, onShowMoreNews, _page (+6 more)

### Community 50 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+5 more)

### Community 51 - "faq_screen.dart"
Cohesion: 0.18
Nodes (13): build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState, message (+5 more)

### Community 52 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 53 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 54 - "gallery_screen.dart"
Cohesion: 0.17
Nodes (12): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+4 more)

### Community 55 - "brand_loading_indicator.dart"
Cohesion: 0.18
Nodes (11): AnimationController, BrandLoadingIndicator, _BrandLoadingIndicatorState, build, _controller, createState, didChangeDependencies, dispose (+3 more)

### Community 56 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 57 - "voting_service.dart"
Cohesion: 0.17
Nodes (10): FirebaseAuth, FirebaseFirestore, _auth, _firestore, hasVoted, _registeredUser, submitVote, VotingService (+2 more)

### Community 58 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 59 - "news_detail_screen.dart"
Cohesion: 0.18
Nodes (10): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, _formatDate, NewsDetailScreen, _openLink, post, package:flutter_html/flutter_html.dart, tagged_news_screen.dart (+2 more)

### Community 60 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 61 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 62 - "favorite_button.dart"
Cohesion: 0.20
Nodes (10): FavoriteKind, favoritesProvider, build, _OrganizerContent, build, FavoriteButton, id, kind (+2 more)

### Community 63 - "MaterialPageRoute"
Cohesion: 0.18
Nodes (11): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, _special, build, _artistContent, _postContent, _open (+3 more)

### Community 64 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 65 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 66 - "State"
Cohesion: 0.27
Nodes (10): InAppBrowserScreen, _InAppBrowserScreenState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, PostEmbedCard, _PostEmbedCardState, RadioPlayerBar, _RadioPlayerBarState (+2 more)

### Community 67 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 68 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 69 - "social_contact_screen.dart"
Cohesion: 0.22
Nodes (8): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value

### Community 70 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../screens/news/news_detail_screen.dart

### Community 71 - "FlutterMacOS"
Cohesion: 0.32
Nodes (5): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow, XCTest

### Community 72 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 73 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 74 - "news_provider.dart"
Cohesion: 0.25
Nodes (7): ProfileSubmissionOptions, profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build, ../models/profile_submission.dart, news_provider.dart

### Community 75 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.25
Nodes (6): enableTestAds, getOrganizer, getOrganizers, service, ../models/organizer.dart, package:flutter_riverpod/flutter_riverpod.dart

### Community 76 - "community_provider.dart"
Cohesion: 0.25
Nodes (7): communityPostsProvider, watch, build, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 77 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 78 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.38
Nodes (4): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit

### Community 79 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 80 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 81 - "artists_provider.dart"
Cohesion: 0.33
Nodes (5): ArtistListQuery, getArtist, getArtists, service, ../models/artist.dart

### Community 82 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 83 - "genre_chip.dart"
Cohesion: 0.40
Nodes (4): build, genre, GenreChip, ../screens/genres/genre_discovery_screen.dart

### Community 84 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

## Knowledge Gaps
- **1072 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1067 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SubmissionImage` connect `SubmissionImage` to `community_screen.dart`, `wordpress_admin_screen.dart`, `event_submission_screen.dart`, `artist_submission_screen.dart`, `organizer_submission_screen.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `CommunityService` connect `community_provider.dart` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `favoritesProvider` connect `favorite_button.dart` to `organizer_detail_screen.dart`, `ConsumerWidget`, `favorites_provider.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1072 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._