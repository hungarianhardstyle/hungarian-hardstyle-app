# Graph Report - .  (2026-08-06)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1768 nodes · 2457 edges · 106 communities (98 shown, 8 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ba75e2bd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- community_service.dart
- community_screen.dart
- Win32Window
- wordpress_service.dart
- tagged_news_screen.dart
- post.dart
- event.dart
- news_provider.dart
- artist.dart
- event_submission_screen.dart
- genre_discovery_screen.dart
- wordpress_admin_screen.dart
- favorites_provider.dart
- package:flutter_test/flutter_test.dart
- organizer.dart
- artist_submission_screen.dart
- hungarian-hardstyle-newsroom/app/main.py
- organizer_submission_screen.dart
- my_application.cc
- community_users_screen.dart
- communityServiceProvider
- event_detail_screen.dart
- more_screen.dart
- RadioPlaybackService
- main_navigation.dart
- settings_screen.dart
- newsroom/app/main.py
- artists_screen.dart
- post_embed_card.dart
- profile_submission.dart
- radio_player_bar.dart
- html_linkifier.dart
- event_submission.dart
- push_notification_service.dart
- in_app_browser.dart
- artist_detail_screen.dart
- releases_screen.dart
- GeneratedPluginRegistrant.swift
- package:flutter_riverpod/flutter_riverpod.dart
- mobile_ad_banner.dart
- community_post.dart
- index.js
- StatelessWidget
- startup_gate.dart
- release_preview_player.dart
- release.dart
- ConsumerWidget
- organizer_detail_screen.dart
- organizers_screen.dart
- favorites_screen.dart
- main.dart
- static const
- State
- package:cached_network_image/cached_network_image.dart
- wWinMain
- gallery_screen.dart
- submission_image_picker.dart
- news_detail_screen.dart
- event_card.dart
- package.json
- home_screen.dart
- manifest.json
- hungarian-hardstyle-newsroom/app/graphics.py
- social_contact_screen.dart
- MaterialPageRoute
- about_screen.dart
- spotify_player.dart
- brand_loading_indicator.dart
- List
- package:url_launcher/url_launcher.dart
- package:flutter/material.dart
- FlutterMacOS
- events_screen.dart
- AppDelegate
- faq.dart
- release_detail_screen.dart
- community_provider.dart
- dart:async
- ios/RunnerTests/RunnerTests.swift
- ../core/navigation/in_app_browser.dart
- SubmissionImage
- AppDelegate
- _EventSubmissionScreenState
- favorite_button.dart
- RunnerTests
- organizers_provider.dart
- RegisterGeneratedPlugins
- package:intl/intl.dart
- _ArtistSubmissionScreenState
- OpenAPITests
- FavoritesNotifier
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
- `CommunityAvatarButton` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart
- `_delete` --references--> `communityServiceProvider`  [EXTRACTED]
  lib/screens/community/community_screen.dart → lib/providers/community_provider.dart

## Import Cycles
- None detected.

## Communities (106 total, 8 thin omitted)

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

### Community 4 - "tagged_news_screen.dart"
Cohesion: 0.05
Nodes (46): paginatedNewsProvider, build, _category, createState, _ErrorState, faqProvider, FaqScreen, _FaqScreenState (+38 more)

### Community 5 - "post.dart"
Cohesion: 0.04
Nodes (47): alt, categories, categoryIds, _closestFigure, content, date, _decodeHtmlText, description (+39 more)

### Community 6 - "event.dart"
Cohesion: 0.05
Nodes (43): bool get, 0, artists, _decodeHtmlText, description, endDate, endTime, EventArtist (+35 more)

### Community 7 - "news_provider.dart"
Cohesion: 0.05
Nodes (41): FormState, categories, copyWith, error, getLatestPosts, _getPostsPage, hasMore, isLoading (+33 more)

### Community 8 - "artist.dart"
Cohesion: 0.05
Nodes (36): 0, ArtistCategory, ArtistsPage, biography, bookingEmail, bookingViaHuhs, categories, city (+28 more)

### Community 9 - "event_submission_screen.dart"
Cohesion: 0.05
Nodes (36): _addressController, _cityController, createState, _descriptionController, dispose, _emailController, _endDate, _endTime (+28 more)

### Community 10 - "genre_discovery_screen.dart"
Cohesion: 0.06
Nodes (32): wordpressServiceProvider, _artistHasMore, _artistPage, _artists, build, child, createState, dispose (+24 more)

### Community 11 - "wordpress_admin_screen.dart"
Cohesion: 0.06
Nodes (32): build, _busyIds, _confirm, _creatableSections, _createResource, createState, _customSections, _deleteUser (+24 more)

### Community 12 - "favorites_provider.dart"
Cohesion: 0.06
Nodes (30): dart:convert, FirebaseAuth, FirebaseFirestore, _auth, _authSubscription, clearAll, _clearCloud, contains (+22 more)

### Community 13 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (22): package:flutter_test/flutter_test.dart, package:hungarian_hardstyle_app/core/content/html_linkifier.dart, package:hungarian_hardstyle_app/main.dart, package:hungarian_hardstyle_app/models/artist.dart, package:hungarian_hardstyle_app/models/event.dart, package:hungarian_hardstyle_app/models/event_submission.dart, package:hungarian_hardstyle_app/models/organizer.dart, package:hungarian_hardstyle_app/models/post.dart (+14 more)

### Community 14 - "organizer.dart"
Cohesion: 0.07
Nodes (29): event.dart, 0, city, country, description, excerpt, false, featured (+21 more)

### Community 15 - "artist_submission_screen.dart"
Cohesion: 0.07
Nodes (28): _background, _biography, _bookingEmail, _bookingViaHuhs, _categories, _city, _contactEmail, _country (+20 more)

### Community 16 - "hungarian-hardstyle-newsroom/app/main.py"
Cohesion: 0.14
Nodes (21): BaseHTTPMiddleware, create_wordpress_draft(), custom_openapi(), health(), HealthResponse, Any, BaseModel, get (+13 more)

### Community 17 - "organizer_submission_screen.dart"
Cohesion: 0.08
Nodes (26): class, build, _city, _contactEmail, _country, createState, _description, dispose (+18 more)

### Community 18 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 19 - "community_users_screen.dart"
Cohesion: 0.08
Nodes (25): DocumentSnapshot, _action, connectionData, _connectionStatus, createState, data, dispose, _favoriteTile (+17 more)

### Community 20 - "communityServiceProvider"
Cohesion: 0.12
Nodes (25): ConsumerState, ConsumerStatefulWidget, communityServiceProvider, CommunityAdminScreen, _CommunityAdminScreenState, CommunityProfileScreen, _CommunityProfileScreenState, _delete (+17 more)

### Community 21 - "event_detail_screen.dart"
Cohesion: 0.08
Nodes (24): Future, HuhsEvent get, _ArtistLinks, artists, _attendanceBusy, _attendanceFuture, _attendanceState, createState (+16 more)

### Community 22 - "more_screen.dart"
Cohesion: 0.08
Nodes (23): about_screen.dart, ../artists/artists_screen.dart, community_users_screen.dart, donate_screen.dart, faq_screen.dart, favorites_screen.dart, icon, _MenuCard (+15 more)

### Community 23 - "RadioPlaybackService"
Cohesion: 0.13
Nodes (9): MainActivity, RadioPlaybackService, FlutterEngine, FlutterFragmentActivity, IBinder, Intent, MediaPlayer, Notification (+1 more)

### Community 24 - "main_navigation.dart"
Cohesion: 0.09
Nodes (22): community/community_screen.dart, events/events_screen.dart, home/home_screen.dart, appNavigatorKey, appScaffoldMessengerKey, build, createState, _currentIndex (+14 more)

### Community 25 - "settings_screen.dart"
Cohesion: 0.09
Nodes (23): _biometricEnabled, build, _clearCache, _clearingCache, createState, _eventNotificationsEnabled, _eventNotificationsKey, initState (+15 more)

### Community 26 - "newsroom/app/main.py"
Cohesion: 0.14
Nodes (20): cover(), fetch(), generate(), Image, Path, render_psd(), create_wordpress_draft(), custom_openapi() (+12 more)

### Community 27 - "artists_screen.dart"
Cohesion: 0.09
Nodes (22): artist_detail_screen.dart, ArtistListQuery get, artistsProvider, artist, _ArtistCard, _ArtistError, ArtistsScreen, _ArtistsScreenState (+14 more)

### Community 28 - "post_embed_card.dart"
Cohesion: 0.09
Nodes (21): PostEmbed, _after, build, _controller, createState, embed, _embedUri, _ExternalLink (+13 more)

### Community 29 - "profile_submission.dart"
Cohesion: 0.09
Nodes (21): artistCategories, ArtistSubmission, biography, bookingEmail, bookingViaHuhs, categories, city, contactEmail (+13 more)

### Community 30 - "radio_player_bar.dart"
Cohesion: 0.11
Nodes (19): dart:io, build, _channel, createState, dispose, initState, _metadataTimer, _muted (+11 more)

### Community 31 - "html_linkifier.dart"
Cohesion: 0.10
Nodes (19): blocked, blockedTags, candidates, closing, cursor, end, linkifyPlainUrls, _linkifyText (+11 more)

### Community 32 - "event_submission.dart"
Cohesion: 0.11
Nodes (18): contactEmail, description, endDate, endTime, EventSubmission, eventUrl, flyerUrl, genres (+10 more)

### Community 33 - "push_notification_service.dart"
Cohesion: 0.11
Nodes (18): _api, _authSubscription, initialize, _initialized, PushNotificationService, _showForegroundMessage, _storeToken, _syncStoredToken (+10 more)

### Community 34 - "in_app_browser.dart"
Cohesion: 0.12
Nodes (17): build, _controller, createState, _handleSystemBack, InAppBrowserScreen, _InAppBrowserScreenState, initialUri, initState (+9 more)

### Community 35 - "artist_detail_screen.dart"
Cohesion: 0.12
Nodes (17): Artist, artistDetailProvider, artistClaimStatusProvider, artist, _ArtistContent, ArtistDetailScreen, artistId, _biographyHtml (+9 more)

### Community 36 - "releases_screen.dart"
Cohesion: 0.12
Nodes (17): releasesProvider, artistId, artistName, build, createState, dispose, _query, release (+9 more)

### Community 37 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.12
Nodes (16): audio_session, cloud_firestore, cloud_functions, file_selector_macos, firebase_auth, firebase_core, firebase_messaging, Foundation (+8 more)

### Community 38 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.14
Nodes (13): ProfileSubmissionOptions, enableTestAds, ArtistListQuery, getArtist, getArtists, service, ReleaseQuery, ../models/artist.dart (+5 more)

### Community 39 - "mobile_ad_banner.dart"
Cohesion: 0.15
Nodes (15): BannerAd?, int?, adsEnabledProvider, _ad, build, createState, dispose, _ensureAd (+7 more)

### Community 40 - "community_post.dart"
Cohesion: 0.12
Nodes (15): DateTime, authorAccessRole, authorId, authorImageUrl, authorName, authorRole, CommunityPost, createdAt (+7 more)

### Community 41 - "index.js"
Cohesion: 0.12
Nodes (11): admin, callWindows, db, { defineSecret }, functions, { getFirestore }, { onDocumentWritten }, submissionRoutes (+3 more)

### Community 42 - "StatelessWidget"
Cohesion: 0.12
Nodes (16): _Composer, _PostAuthorLabels, _ProfileAvatar, CommunityBlockedUsersScreen, CommunityConnectionsScreen, CommunityPublicFriendsScreen, CommunityReportsScreen, _ConnectionRequestTile (+8 more)

### Community 43 - "startup_gate.dart"
Cohesion: 0.12
Nodes (15): _animationDuration, _announcementUrl, build, _controller, createState, didChangeDependencies, _dismissedAnnouncementUrl, dispose (+7 more)

### Community 44 - "release_preview_player.dart"
Cohesion: 0.14
Nodes (14): AudioPlayer, Duration, ReleaseTrack, build, createState, dispose, index, initState (+6 more)

### Community 45 - "release.dart"
Cohesion: 0.13
Nodes (14): artists, coverUrl, fromJson, genre, id, links, name, previewUrl (+6 more)

### Community 46 - "ConsumerWidget"
Cohesion: 0.20
Nodes (14): ConsumerWidget, communityAuthProvider, eventsProvider, newsProvider, CommunityAvatarButton, _openPlannedEvent, _PostAuthorAvatar, build (+6 more)

### Community 47 - "organizer_detail_screen.dart"
Cohesion: 0.15
Nodes (13): OrganizerProfile, organizerDetailProvider, build, _descriptionHtml, _escapeHtml, fallbackName, _MissingOrganizer, name (+5 more)

### Community 48 - "organizers_screen.dart"
Cohesion: 0.15
Nodes (13): createState, dispose, onRetry, _onSearchChanged, organizer, _OrganizerCard, _OrganizerError, OrganizersScreen (+5 more)

### Community 49 - "favorites_screen.dart"
Cohesion: 0.17
Nodes (12): ../artists/artist_detail_screen.dart, ../events/event_detail_screen.dart, favoritesProvider, build, FavoritesScreen, _label, _OrganizerContent, build (+4 more)

### Community 50 - "main.dart"
Cohesion: 0.15
Nodes (12): core/navigation/app_navigator.dart, core/theme/app_theme.dart, build, HungarianHardstyleApp, initializeDateFormatting, _initializePushNotifications, main, package:firebase_core/firebase_core.dart (+4 more)

### Community 51 - "static const"
Cohesion: 0.15
Nodes (11): AppTheme, backgroundDecoration, _channel, _dio, ImageSaver, saveFromUrl, package:dio/dio.dart, package:flutter/services.dart (+3 more)

### Community 52 - "State"
Cohesion: 0.22
Nodes (13): _NewsSlider, _NewsSliderState, CommunityPublicProfileScreen, _CommunityPublicProfileScreenState, BrandLoadingIndicator, _BrandLoadingIndicatorState, PostEmbedCard, _PostEmbedCardState (+5 more)

### Community 53 - "package:cached_network_image/cached_network_image.dart"
Cohesion: 0.21
Nodes (10): ../core/content/date_formatters.dart, favorite_button.dart, build, FeaturedNewsCard, post, build, NewsCard, post (+2 more)

### Community 54 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 55 - "gallery_screen.dart"
Cohesion: 0.18
Nodes (11): build, _controller, createState, _current, dispose, GalleryScreen, _GalleryScreenState, images (+3 more)

### Community 56 - "submission_image_picker.dart"
Cohesion: 0.17
Nodes (11): build, helperText, image, maxBytes, onChanged, _pick, SubmissionImagePicker, title (+3 more)

### Community 57 - "news_detail_screen.dart"
Cohesion: 0.18
Nodes (10): ../../core/content/html_linkifier.dart, ../gallery/gallery_screen.dart, build, _formatDate, NewsDetailScreen, post, package:flutter_html/flutter_html.dart, tagged_news_screen.dart (+2 more)

### Community 58 - "event_card.dart"
Cohesion: 0.18
Nodes (10): double?, genre_chip.dart, HuhsEvent, build, event, EventCard, height, _visibleGenres (+2 more)

### Community 59 - "package.json"
Cohesion: 0.18
Nodes (10): firebase-admin, firebase-functions, dependencies, firebase-admin, firebase-functions, engines, node, main (+2 more)

### Community 60 - "home_screen.dart"
Cohesion: 0.18
Nodes (10): _controller, createState, dispose, initState, onShowMoreNews, _page, posts, _timer (+2 more)

### Community 61 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 62 - "hungarian-hardstyle-newsroom/app/graphics.py"
Cohesion: 0.33
Nodes (8): cover(), fetch(), generate(), Image, Path, render_psd(), Fit, Path

### Community 63 - "social_contact_screen.dart"
Cohesion: 0.20
Nodes (9): IconData, build, icon, label, _LinkTile, onTap, SocialContactScreen, value (+1 more)

### Community 64 - "MaterialPageRoute"
Cohesion: 0.20
Nodes (10): _openAuthorProfile, _openProfile, _readOnlyProfileWidgets, build, _artistContent, _postContent, _open, _openLink (+2 more)

### Community 65 - "about_screen.dart"
Cohesion: 0.20
Nodes (9): AboutScreen, build, icon, _InfoTile, label, onTap, value, package:package_info_plus/package_info_plus.dart (+1 more)

### Community 66 - "spotify_player.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, _expanded, initState, SpotifyPlayer, _SpotifyPlayerState, package:webview_flutter/webview_flutter.dart (+1 more)

### Community 67 - "brand_loading_indicator.dart"
Cohesion: 0.22
Nodes (8): AnimationController, build, _controller, createState, didChangeDependencies, dispose, initState, size

### Community 68 - "List"
Cohesion: 0.22
Nodes (8): PostShortcode, build, PostShortcodeCard, postUrl, relatedPosts, shortcode, List, ../models/post.dart

### Community 69 - "package:url_launcher/url_launcher.dart"
Cohesion: 0.22
Nodes (7): build, DonateScreen, _donateUri, build, RadioProviderScreen, package:url_launcher/url_launcher.dart, static final

### Community 70 - "package:flutter/material.dart"
Cohesion: 0.22
Nodes (7): build, PrivacyScreen, build, genre, GenreChip, package:flutter/material.dart, ../screens/genres/genre_discovery_screen.dart

### Community 71 - "FlutterMacOS"
Cohesion: 0.38
Nodes (4): Cocoa, FlutterMacOS, MainFlutterWindow, NSWindow

### Community 72 - "events_screen.dart"
Cohesion: 0.25
Nodes (7): event_submission_screen.dart, _EventsHeader, onSubmit, _openSubmission, showSubmit, ../../providers/community_provider.dart, ../../widgets/event_card.dart

### Community 73 - "AppDelegate"
Cohesion: 0.25
Nodes (6): FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Any, Bool, UIApplication

### Community 74 - "faq.dart"
Cohesion: 0.25
Nodes (7): answer, category, FaqItem, fromJson, id, order, question

### Community 75 - "release_detail_screen.dart"
Cohesion: 0.25
Nodes (7): HuhsRelease, build, _label, release, ReleaseDetailScreen, releases_screen.dart, ../../widgets/release_preview_player.dart

### Community 76 - "community_provider.dart"
Cohesion: 0.25
Nodes (7): communityPostsProvider, watch, build, CommunityService, ../models/community_post.dart, package:firebase_auth/firebase_auth.dart, ../services/community_service.dart

### Community 77 - "dart:async"
Cohesion: 0.29
Nodes (6): dart:async, getEvents, getEventSubmissionGenres, refreshTimer, service, ../models/event.dart

### Community 78 - "ios/RunnerTests/RunnerTests.swift"
Cohesion: 0.32
Nodes (5): Flutter, FlutterSceneDelegate, SceneDelegate, UIKit, XCTest

### Community 79 - "../core/navigation/in_app_browser.dart"
Cohesion: 0.33
Nodes (5): ../core/navigation/in_app_browser.dart, build, _openSpotify, _playlists, SpotifyPlaylistsScreen

### Community 80 - "SubmissionImage"
Cohesion: 0.33
Nodes (5): dart:typed_data, bytes, name, SubmissionImage, Uint8List

### Community 81 - "AppDelegate"
Cohesion: 0.47
Nodes (4): FlutterAppDelegate, AppDelegate, Bool, NSApplication

### Community 82 - "_EventSubmissionScreenState"
Cohesion: 0.40
Nodes (6): eventSubmissionGenresProvider, organizersProvider, build, EventSubmissionScreen, _EventSubmissionScreenState, build

### Community 83 - "favorite_button.dart"
Cohesion: 0.33
Nodes (5): FavoriteKind, id, kind, title, ../providers/favorites_provider.dart

### Community 84 - "RunnerTests"
Cohesion: 0.40
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 85 - "organizers_provider.dart"
Cohesion: 0.40
Nodes (4): getOrganizer, getOrganizers, service, ../models/organizer.dart

### Community 86 - "RegisterGeneratedPlugins"
Cohesion: 0.50
Nodes (3): FlutterPluginRegistry, FlutterViewController, RegisterGeneratedPlugins()

### Community 87 - "package:intl/intl.dart"
Cohesion: 0.50
Nodes (3): formatEventDate, formatHungarianDate, package:intl/intl.dart

### Community 88 - "_ArtistSubmissionScreenState"
Cohesion: 0.50
Nodes (4): profileSubmissionOptionsProvider, ArtistSubmissionScreen, _ArtistSubmissionScreenState, build

## Knowledge Gaps
- **1037 isolated node(s):** `functions`, `{ onDocumentWritten }`, `{ defineSecret }`, `admin`, `{ getFirestore }` (+1032 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CommunityService` connect `community_provider.dart` to `community_service.dart`, `community_screen.dart`, `community_users_screen.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `SubmissionImage` connect `SubmissionImage` to `community_screen.dart`, `event_submission_screen.dart`, `artist_submission_screen.dart`, `organizer_submission_screen.dart`, `submission_image_picker.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `favoritesProvider` connect `favorites_screen.dart` to `favorites_provider.dart`, `organizer_detail_screen.dart`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `functions`, `{ onDocumentWritten }`, `{ defineSecret }` to the rest of the system?**
  _1037 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `community_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.023255813953488372 - nodes in this community are weakly interconnected._
- **Should `community_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024096385542168676 - nodes in this community are weakly interconnected._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._