import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/main_navigation.dart';
import '../services/community_service.dart';
import '../services/startup_announcement_cooldown.dart';
import '../core/navigation/in_app_browser.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with SingleTickerProviderStateMixin {
  static final Dio _announcementClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  static const _animationDuration = Duration(milliseconds: 850);
  static const _startupDelay = Duration(milliseconds: 700);
  static const _logoAsset = 'assets/logos/huhs_full_logo.png';
  static const _repeatAnnouncementForUxTesting = false;
  static const _announcementCooldown = StartupAnnouncementCooldown();

  late final AnimationController _controller;
  Timer? _timer;
  bool _ready = false;
  String? _announcementUrl;
  String? _announcementButtonLabel;
  String? _announcementButtonUrl;
  String? _dismissedAnnouncementUrl;
  StreamSubscription<User?>? _authSubscription;
  String? _preloadedUid;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      lowerBound: .88,
      upperBound: 1,
      value: .88,
    )..repeat(reverse: true);
    // Widget tests and fallback startup can run without Firebase platform
    // initialization. Preloading is optional and must never break the gate.
    try {
      final service = CommunityService();
      _authSubscription = service.auth.userChanges().listen((user) {
        if (user != null && !user.isAnonymous) {
          _preloadUserData(service, user);
        }
      });
      // userChanges normally emits the restored session, but warm it
      // immediately as well so an already signed-in user does not wait for
      // the stream callback before profile data starts loading.
      final currentUser = service.auth.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        _preloadUserData(service, currentUser);
      }
    } catch (_) {}
    _timer = Timer(_startupDelay, () {
      if (mounted) setState(() => _ready = true);
    });
    _loadAnnouncement();
  }

  void _preloadUserData(CommunityService service, User user) {
    if (_preloadedUid == user.uid) return;
    _preloadedUid = user.uid;
    unawaited(service.preloadOwnProfile());
    unawaited(service.preloadWordPressAdmin());
  }

  Future<void> _loadAnnouncement() async {
    try {
      final response = await _announcementClient.get<Map<String, dynamic>>(
        'https://hungarianhardstyle.hu/wp-json/huhs/v1/startup-announcement',
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
        options: Options(headers: const {'Cache-Control': 'no-cache'}),
      );
      final data = response.data;
      final imageUrl = (data?['imageUrl'] as String?)?.trim();
      final buttonLabel = (data?['buttonLabel'] as String?)?.trim();
      final buttonUrl = (data?['buttonUrl'] as String?)?.trim();
      final parsedButtonUrl = Uri.tryParse(buttonUrl ?? '');
      final validButton =
          buttonLabel != null &&
          buttonLabel.isNotEmpty &&
          buttonUrl != null &&
          parsedButtonUrl != null &&
          parsedButtonUrl.scheme == 'https' &&
          parsedButtonUrl.host.isNotEmpty;
      final enabled = data?['enabled'] == true;
      final validImage = imageUrl != null && imageUrl.isNotEmpty;
      final identity = [
        imageUrl ?? '',
        validButton ? buttonLabel : '',
        validButton ? buttonUrl : '',
      ].join('|');
      String ownerId = 'device';
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid.trim();
        if (uid != null && uid.isNotEmpty) ownerId = uid;
      } catch (_) {}
      final canShow = enabled && validImage
          ? (_repeatAnnouncementForUxTesting ||
                await _announcementCooldown.canShow(
                  identity: identity,
                  ownerId: ownerId,
                ))
          : false;
      if (!mounted) return;
      if (canShow) {
        await _announcementCooldown.markShown(
          identity: identity,
          ownerId: ownerId,
        );
      }
      if (!mounted) return;
      setState(() {
        _announcementUrl = canShow && imageUrl != _dismissedAnnouncementUrl
            ? imageUrl
            : null;
        _announcementButtonLabel = validButton ? buttonLabel : null;
        _announcementButtonUrl = validButton ? buttonUrl : null;
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 1;
      _timer?.cancel();
      _ready = true;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      final home = const MainNavigation();
      if (_announcementUrl == null) return home;
      final announcement = _announcementUrl;
      return Stack(
        children: [
          home,
          if (announcement != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .68),
                child: SafeArea(
                  child: Center(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .84,
                          maxWidth: 390,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'KIEMELT ESEMÉNY',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Bezárás',
                                    onPressed: () => setState(() {
                                      _dismissedAnnouncementUrl = announcement;
                                      _announcementUrl = null;
                                    }),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: CachedNetworkImage(
                                imageUrl: announcement,
                                fit: BoxFit.contain,
                                errorWidget: (_, _, _) => const SizedBox(
                                  height: 96,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
                              child: Row(
                                children: [
                                  const Spacer(),
                                  if (_announcementButtonLabel != null &&
                                      _announcementButtonUrl != null)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 18,
                                      ),
                                      label: Text(_announcementButtonLabel!),
                                      onPressed: () async {
                                        final uri = Uri.tryParse(
                                          _announcementButtonUrl!,
                                        );
                                        if (uri == null ||
                                            uri.scheme != 'https' ||
                                            uri.host.isEmpty ||
                                            !mounted) {
                                          return;
                                        }
                                        await openInAppBrowser(
                                          context,
                                          uri.toString(),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) =>
              Transform.scale(scale: _controller.value, child: child),
          child: Image.asset(
            _logoAsset,
            width: MediaQuery.sizeOf(context).width * .82,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
