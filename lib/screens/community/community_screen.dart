import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/community_post.dart';
import '../../models/event.dart';
import '../../models/submission_image.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/input/sentence_capitalization_formatter.dart';
import '../../providers/community_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/submission_image_picker.dart';
import '../more/favorites_screen.dart';
import '../more/community_users_screen.dart';
import '../artists/artist_detail_screen.dart';
import '../events/event_detail_screen.dart';
import 'wordpress_admin_screen.dart';
import 'private_messages_screen.dart';

String _chatError(Object error) {
  return userFacingError(error);
}

class ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String initial;
  final double size;
  final double focusX;
  final double focusY;
  final double zoom;
  final double panX;
  final double panY;
  final Uint8List? imageBytes;

  const ProfileAvatar({
    required this.imageUrl,
    required this.initial,
    required this.size,
    this.focusX = 50,
    this.focusY = 25,
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(initial, style: TextStyle(fontSize: size * .36)),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFFE53935),
          child: imageBytes == null && imageUrl.isEmpty
              ? fallback
              : Transform.translate(
                  offset: Offset(panX * size, panY * size),
                  child: Transform.scale(
                    scale: zoom.clamp(1, 3),
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              (focusX.clamp(0, 100) - 50) / 50,
                              (focusY.clamp(0, 100) - 50) / 50,
                            ),
                            errorBuilder: (_, _, _) => fallback,
                          )
                        : Image.network(
                            imageUrl,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              (focusX.clamp(0, 100) - 50) / 50,
                              (focusY.clamp(0, 100) - 50) / 50,
                            ),
                            errorBuilder: (_, _, _) => fallback,
                          ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PostAuthorAvatar extends ConsumerWidget {
  final CommunityPost post;
  final bool compact;

  const _PostAuthorAvatar(this.post, {this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = post.authorName.trim().isEmpty
        ? '?'
        : post.authorName.trim().characters.first.toUpperCase();
    if (post.authorId.isEmpty) {
      return ProfileAvatar(
        imageUrl: post.authorImageUrl,
        initial: initial,
        size: compact ? 30 : 34,
      );
    }
    final service = ref.watch(communityServiceProvider);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.firestore
          .collection('community_profiles')
          .doc(post.authorId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        return ProfileAvatar(
          imageUrl: service.resolveProfileImage(data, post.authorImageUrl),
          initial: initial,
          size: compact ? 30 : 34,
          focusX: (data['profileFocusX'] as num?)?.toDouble() ?? 50,
          focusY: (data['profileFocusY'] as num?)?.toDouble() ?? 25,
          zoom: (data['profileZoom'] as num?)?.toDouble() ?? 1,
          panX: (data['profilePanX'] as num?)?.toDouble() ?? 0,
          panY: (data['profilePanY'] as num?)?.toDouble() ?? 0,
        );
      },
    );
  }
}

class CommunityAvatarButton extends ConsumerWidget {
  final VoidCallback onPressed;

  const CommunityAvatarButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = IconButton(
      tooltip: 'Profil',
      onPressed: onPressed,
      icon: const ProfileAvatar(imageUrl: '', initial: 'H', size: 36),
    );
    if (Firebase.apps.isEmpty) return fallback;
    ref.watch(communityAuthProvider);
    final service = ref.watch(communityServiceProvider);
    final user = service.auth.currentUser;
    if (user == null || user.isAnonymous) return fallback;
    final authName = (user.displayName ?? user.email ?? 'HU').trim();
    final authInitial = authName.isEmpty
        ? 'H'
        : authName.characters.first.toUpperCase();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.firestore
          .collection('community_profiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final rawUrl = service.resolveProfileImage(data, user.photoURL ?? '');
        final name =
            (data['displayName'] as String? ?? user.displayName ?? 'HU').trim();
        final initial = name.isEmpty
            ? authInitial
            : name.characters.first.toUpperCase();
        return IconButton(
          tooltip: 'Profil',
          onPressed: onPressed,
          icon: ProfileAvatar(
            imageUrl: rawUrl,
            initial: initial,
            size: 36,
            focusX: (data['profileFocusX'] as num?)?.toDouble() ?? 50,
            focusY: (data['profileFocusY'] as num?)?.toDouble() ?? 25,
            zoom: (data['profileZoom'] as num?)?.toDouble() ?? 1,
            panX: (data['profilePanX'] as num?)?.toDouble() ?? 0,
            panY: (data['profilePanY'] as num?)?.toDouble() ?? 0,
          ),
        );
      },
    );
  }
}

class CommunityAdminScreen extends ConsumerStatefulWidget {
  const CommunityAdminScreen({super.key});

  @override
  ConsumerState<CommunityAdminScreen> createState() =>
      _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends ConsumerState<CommunityAdminScreen> {
  final _search = TextEditingController();
  final _pinnedText = TextEditingController();
  String _roleFilter = 'all';

  String _roleFilterLabel() =>
      const {
        'all': 'Mindenki',
        'admin': 'Admin',
        'dj': 'DJ',
        'organizer': 'Szervező',
        'partygoer': 'Bulizó',
      }[_roleFilter] ??
      'Mindenki';

  Future<String?> _pickAdminRole({
    required String title,
    required List<(String, String)> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            for (final option in options)
              ListTile(
                title: Text(option.$2),
                trailing: option.$1 == current
                    ? const Icon(Icons.check, color: Colors.redAccent)
                    : null,
                selected: option.$1 == current,
                onTap: () => Navigator.pop(sheetContext, option.$1),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAdminAccountRole(
    CommunityService service,
    String uid,
    String current,
  ) async {
    final value = await _pickAdminRole(
      title: 'Fiók-szerepkör',
      current: current,
      options: const [
        ('dj', 'DJ'),
        ('organizer', 'Szervező'),
        ('partygoer', 'Bulizó'),
      ],
    );
    if (value == null || value == current || !mounted) return;
    try {
      await service.setAccountRole(uid, value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _changeAdminAccessRole(
    CommunityService service,
    String uid,
    String current,
  ) async {
    final value = await _pickAdminRole(
      title: 'Hozzáférési jog',
      current: current,
      options: const [
        (CommunityService.accessNone, 'Nincs jogosultság'),
        (CommunityService.accessModerator, 'Moderátor'),
        (CommunityService.accessAdmin, 'Admin'),
      ],
    );
    if (value == null || value == current || !mounted) return;
    try {
      await service.setAccessRole(uid, value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _pinnedText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Közösségi adminisztráció')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(_chatError(snapshot.error!)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _search.text.trim().toLowerCase();
          final profiles = snapshot.data!.docs.where((doc) {
            if (query.isEmpty) return true;
            final data = doc.data();
            final name = (data['displayName'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
          final filteredProfiles = profiles.where((doc) {
            if (_roleFilter == 'all') return true;
            final data = doc.data();
            if (_roleFilter == 'admin') {
              return data['accessRole'] == CommunityService.accessAdmin ||
                  data['role'] == CommunityService.accessAdmin;
            }
            return service.accountRole(data['role'] as String?) == _roleFilter;
          }).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 220),
            children: [
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('HUHS Vezérlőközpont'),
                subtitle: const Text('WordPress Mobile API adminisztráció'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WordPressAdminScreen(),
                  ),
                ),
              ),
              if (profiles.isEmpty)
                const Center(child: Text('Még nincs regisztrált profil.')),
              if (profiles.isNotEmpty)
                const ListTile(
                  leading: Icon(Icons.people_outline),
                  title: Text('Felhasználók'),
                  subtitle: Text('Regisztrált felhasználók és jogosultságok'),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pinnedText,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Rögzített Chat-üzenet',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Küldés és rögzítés',
                          icon: const Icon(Icons.push_pin_outlined),
                          onPressed: () async {
                            final text = _pinnedText.text.trim();
                            if (text.isEmpty) return;
                            try {
                              await service.publishPost(
                                text: text,
                                pinned: true,
                              );
                              _pinnedText.clear();
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_chatError(error))),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Felhasználó keresése',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CommunityReportsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Jelentések kezelése'),
                ),
              ),
              /*
              if (false)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // The dedicated report-management screen owns this list.
                  stream: service.watchReports(),
                  builder: (context, reportSnapshot) {
                    if (reportSnapshot.hasError || !reportSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final reports = reportSnapshot.data!.docs;
                    if (reports.isEmpty) return const SizedBox.shrink();
                    return Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text('Jelentések (${reports.length})'),
                        children: [
                          for (final report in reports)
                            ListTile(
                              dense: true,
                              title: Text(
                                'Bejegyzés: ${report.data()['postId'] ?? '-'}',
                              ),
                              subtitle: Text(
                                'Ok: ${report.data()['reason'] ?? 'egyéb'}',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              */
              ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.people_outline),
                title: Text(
                  'Regisztrált felhasználók (${filteredProfiles.length})',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: PopupMenuButton<String>(
                      tooltip: 'Szerepkör szűrése',
                      offset: const Offset(0, 58),
                      color: const Color(0xFF171717),
                      onSelected: (value) =>
                          setState(() => _roleFilter = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'all', child: Text('Mindenki')),
                        PopupMenuItem(value: 'admin', child: Text('Admin')),
                        PopupMenuItem(value: 'dj', child: Text('DJ')),
                        PopupMenuItem(
                          value: 'organizer',
                          child: Text('Szervező'),
                        ),
                        PopupMenuItem(
                          value: 'partygoer',
                          child: Text('Bulizó'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF21B1B1B),
                          border: Border.all(color: const Color(0xFF5A2424)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('Szerepkör szűrése'),
                            const Spacer(),
                            Text(_roleFilterLabel()),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      final doc = filteredProfiles[index];
                      final data = doc.data();
                      final role = service.accountRole(data['role'] as String?);
                      return Card(
                        child: ListTile(
                          leading: IconButton(
                            tooltip: 'Felhasználó törlése',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: doc.id == service.auth.currentUser?.uid
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text(
                                          'Felhasználó törlése',
                                        ),
                                        content: const Text(
                                          'A profil, a Chat-üzenetek és a bejelentkezés is törlődik. Folytatod?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const Text('Mégse'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: const Text('Törlés'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !context.mounted) {
                                      return;
                                    }
                                    try {
                                      await service.deleteUser(doc.id);
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(_chatError(error)),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          title: Text(
                            data['displayName'] as String? ?? 'HUHS user',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['email'] as String? ?? doc.id),
                              TextButton(
                                onPressed:
                                    doc.id == service.auth.currentUser?.uid
                                    ? null
                                    : () => _changeAdminAccessRole(
                                        service,
                                        doc.id,
                                        data['accessRole'] as String? ??
                                            CommunityService.accessNone,
                                      ),
                                child: Text(
                                  'Jog: ${data['accessRole'] ?? (data['role'] == 'admin' ? 'admin' : 'none')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: doc.id == service.auth.currentUser?.uid
                                ? null
                                : () => _changeAdminAccountRole(
                                    service,
                                    doc.id,
                                    data['role'] as String? ?? 'partygoer',
                                  ),
                            child: Text(
                              const {
                                    'dj': 'DJ',
                                    'organizer': 'Szervező',
                                    'partygoer': 'Bulizó',
                                  }[role] ??
                                  role,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class LiveFeedScreen extends ConsumerStatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  final _textController = TextEditingController();
  final _composerFocusNode = FocusNode();
  Uint8List? _image;
  bool _sending = false;
  String? _replyQuote;
  bool _anonymous = true;
  String _avatarUrl = '';
  String _avatarLetter = 'H';
  double _avatarFocusX = 50;
  double _avatarFocusY = 25;
  double _avatarZoom = 1;
  double _avatarPanX = 0;
  double _avatarPanY = 0;
  StreamSubscription<User?>? _authSubscription;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    _authSubscription = _service.auth.userChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _anonymous = user == null || user.isAnonymous;
        if (_anonymous) {
          _avatarUrl = '';
          _avatarLetter = 'H';
        }
      });
      unawaited(_refreshAvatar());
    });
    _prepareAnonymousUser();
  }

  Future<void> _prepareAnonymousUser() async {
    try {
      final user = await _service.ensureAnonymousUser();
      if (mounted) setState(() => _anonymous = user.isAnonymous);
      await _refreshAvatar();
    } catch (_) {}
  }

  Future<void> _refreshAvatar() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _avatarUrl = '';
          _avatarLetter = 'H';
        });
      }
      return;
    }
    try {
      final data =
          (await _service.profile()).data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _avatarUrl = _service.resolveProfileImage(data, user.photoURL ?? '');
        _avatarFocusX = (data['profileFocusX'] as num?)?.toDouble() ?? 50;
        _avatarFocusY = (data['profileFocusY'] as num?)?.toDouble() ?? 25;
        _avatarZoom = (data['profileZoom'] as num?)?.toDouble() ?? 1;
        _avatarPanX = (data['profilePanX'] as num?)?.toDouble() ?? 0;
        _avatarPanY = (data['profilePanY'] as num?)?.toDouble() ?? 0;
        final name = data['displayName'] as String? ?? user.displayName ?? '';
        _avatarLetter = name.trim().isEmpty
            ? 'H'
            : name.trim()[0].toUpperCase();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _textController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    if (_anonymous) {
      _showMessage('Kép feltöltéséhez regisztráció szükséges.');
      return;
    }
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('A kép legfeljebb 5 MB lehet.');
      return;
    }
    if (mounted) setState(() => _image = bytes);
  }

  Future<void> _send() async {
    if (_textController.text.trim().isEmpty && _image == null) {
      _showMessage('Írj egy üzenetet vagy válassz képet.');
      return;
    }
    setState(() => _sending = true);
    try {
      final body = _replyQuote == null
          ? _textController.text
          : 'Válasz erre: $_replyQuote\n\n${_textController.text}';
      await _service.publishPost(text: body, imageBytes: _image);
      _textController.clear();
      if (mounted) {
        setState(() {
          _image = null;
          _replyQuote = null;
        });
      }
    } catch (error) {
      _showMessage(_chatError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CommunityProfileScreen()),
    );
    if (!mounted) return;
    final user = _service.auth.currentUser;
    setState(() => _anonymous = user?.isAnonymous ?? true);
    await _refreshAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityPostsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Privát üzenetek',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivateMessagesScreen(),
              ),
            ),
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            onPressed: _openProfile,
            icon: _anonymous
                ? const ProfileAvatar(imageUrl: '', initial: 'H', size: 36)
                : ProfileAvatar(
                    imageUrl: _avatarUrl,
                    initial: _avatarLetter,
                    size: 32,
                    focusX: _avatarFocusX,
                    focusY: _avatarFocusY,
                    zoom: _avatarZoom,
                    panX: _avatarPanX,
                    panY: _avatarPanY,
                  ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A keyboard opening reduces the available height.  Deriving the
          // orientation from the LayoutBuilder constraints therefore flips a
          // portrait phone into the landscape branch while typing, which
          // moves the composer and drops its focus.  Use the device
          // orientation instead; it remains stable while insets change.
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final composer = _Composer(
            controller: _textController,
            focusNode: _composerFocusNode,
            image: _image,
            anonymous: _anonymous,
            sending: _sending,
            replyQuote: _replyQuote,
            onClearReply: () => setState(() => _replyQuote = null),
            onTakePhoto: () => _pickImage(source: ImageSource.camera),
            onPickGallery: () => _pickImage(source: ImageSource.gallery),
            onSend: _send,
            onRemoveImage: () => setState(() => _image = null),
          );
          final postList = Expanded(
            child: posts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'A Chat nem érhető el.\\n${_chatError(error)}',
                  textAlign: TextAlign.center,
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Még nincs bejegyzés.'))
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(communityPostsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _PostCard(
                          post: items[index],
                          compact: !landscape,
                          onReply: () => setState(() {
                            _replyQuote = items[index].text.trim();
                          }),
                        ),
                      ),
                    ),
            ),
          );
          return Flex(
            direction: landscape ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (landscape)
                SizedBox(
                  width: constraints.maxWidth < 700
                      ? 240
                      : constraints.maxWidth < 1000
                      ? 280
                      : 360,
                  child: composer,
                )
              else
                composer,
              postList,
            ],
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Uint8List? image;
  final bool anonymous;
  final bool sending;
  final String? replyQuote;
  final VoidCallback onClearReply;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onSend;
  final VoidCallback onRemoveImage;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.image,
    required this.anonymous,
    required this.sending,
    required this.replyQuote,
    required this.onClearReply,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onSend,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (replyQuote != null)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(
                    'Válasz: $replyQuote',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: onClearReply,
                ),
              ),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: const [SentenceCapitalizationFormatter()],
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Írj valamit a közösségnek…',
                border: InputBorder.none,
              ),
            ),
            if (image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      image!,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filled(
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kamera',
                  onPressed: onTakePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kép kiválasztása',
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Küldés'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPost post;
  final bool compact;
  final VoidCallback onReply;
  const _PostCard({
    required this.post,
    required this.compact,
    required this.onReply,
  });

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  String? _selectedReaction;

  Future<void> _react(String emoji) async {
    setState(() => _selectedReaction = emoji);
    try {
      await ref
          .read(communityServiceProvider)
          .toggleReaction(postId: widget.post.id, emoji: emoji);
    } catch (_) {
      if (mounted) setState(() => _selectedReaction = null);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Üzenet törlése'),
        content: const Text('Biztosan törlöd ezt a Chat-üzenetet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(communityServiceProvider).deletePost(widget.post.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _edit() async {
    var editedText = widget.post.text;
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Üzenet szerkesztése'),
        content: TextFormField(
          initialValue: editedText,
          autofocus: true,
          maxLines: 5,
          onChanged: (value) => editedText = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedText),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    if (updated == null || !mounted) return;
    try {
      await ref
          .read(communityServiceProvider)
          .updatePostText(postId: widget.post.id, text: updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _togglePinned() async {
    try {
      await ref
          .read(communityServiceProvider)
          .setPostPinned(widget.post.id, !widget.post.pinned);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _moderateUser(String action) async {
    final service = ref.read(communityServiceProvider);
    try {
      if (action == 'report') {
        await service.reportPost(widget.post.id);
      } else {
        await service.blockUser(widget.post.authorId);
        ref.invalidate(communityPostsProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'report'
                ? 'Jelentés elküldve.'
                : 'Felhasználó blokkolva.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        await _edit();
      case 'delete':
        await _delete();
      case 'pin':
        await _togglePinned();
      case 'report':
      case 'block':
        await _moderateUser(action);
    }
  }

  Future<void> _openAuthorProfile() async {
    if (widget.post.authorId.isEmpty ||
        widget.post.authorName.startsWith('Unknown User ')) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CommunityPublicProfileScreen(userId: widget.post.authorId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final canOpenProfile =
        post.authorId.isNotEmpty &&
        !post.authorName.startsWith('Unknown User ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canOpenProfile ? _openAuthorProfile : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  _PostAuthorAvatar(post, compact: widget.compact),
                  SizedBox(width: widget.compact ? 7 : 9),
                  Expanded(
                    child: _PostAuthorLabels(
                      post: post,
                      service: ref.read(communityServiceProvider),
                    ),
                  ),
                  Text(
                    _timeLabel(post.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (ref.read(communityServiceProvider).isAdmin ||
                      widget.post.authorId !=
                          ref
                              .read(communityServiceProvider)
                              .auth
                              .currentUser
                              ?.uid)
                    PopupMenuButton<String>(
                      tooltip: 'Üzenetműveletek',
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => [
                        if (ref.read(communityServiceProvider).isAdmin) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Szerkesztés'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Törlés'),
                          ),
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(
                              post.pinned
                                  ? 'Rögzítés feloldása'
                                  : 'Üzenet rögzítése',
                            ),
                          ),
                        ],
                        if (widget.post.authorId !=
                            ref
                                .read(communityServiceProvider)
                                .auth
                                .currentUser
                                ?.uid) ...[
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Jelentés'),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Text('Blokkolás'),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            if (post.pinned)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Rögzített üzenet',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            if (post.text.isNotEmpty) ...[
              SizedBox(height: widget.compact ? 7 : 10),
              Text(post.text),
            ],
            if (post.imageUrl.isNotEmpty) ...[
              SizedBox(height: widget.compact ? 7 : 10),
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          minScale: .8,
                          maxScale: 4,
                          child: Image.network(
                            post.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            tooltip: 'Bezárás',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(post.imageUrl, fit: BoxFit.cover),
                ),
              ),
            ],
            SizedBox(height: widget.compact ? 3 : 6),
            Wrap(
              spacing: 6,
              runSpacing: widget.compact ? 0 : 6,
              children: [
                ActionChip(
                  visualDensity: widget.compact ? VisualDensity.compact : null,
                  avatar: const Icon(Icons.reply, size: 16),
                  label: const Text('Válasz'),
                  onPressed: widget.onReply,
                ),
                ...['❤️', '🔥', '🙌'].map((emoji) {
                  final count = post.reactions[emoji] ?? 0;
                  return ActionChip(
                    visualDensity: widget.compact
                        ? VisualDensity.compact
                        : null,
                    label: Text('$emoji${count > 0 ? ' $count' : ''}'),
                    backgroundColor: _selectedReaction == emoji
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .25)
                        : null,
                    onPressed: () => _react(emoji),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return 'most';
    if (difference.inHours < 1) return '${difference.inMinutes} p';
    if (difference.inDays < 1) return '${difference.inHours} ó';
    return '${value.month}.${value.day}.';
  }
}

class _PostAuthorLabels extends StatelessWidget {
  final CommunityPost post;
  final CommunityService service;

  const _PostAuthorLabels({required this.post, required this.service});

  @override
  Widget build(BuildContext context) {
    if (post.authorId.isEmpty) {
      return _labels(post.authorRole, post.authorAccessRole);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.watchProfile(post.authorId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        return _labels(
          data?['role'] as String? ?? post.authorRole,
          data?['accessRole'] as String? ?? CommunityService.accessNone,
        );
      },
    );
  }

  Widget _labels(String role, String accessRole) {
    return Row(
      children: [
        Flexible(
          child: Text(
            post.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (role.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              role == 'dj'
                  ? 'DJ'
                  : role == 'organizer'
                  ? 'Szervező'
                  : 'Bulizó',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
        if (accessRole == CommunityService.accessAdmin)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text(
              'Admin',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (accessRole == CommunityService.accessModerator)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text(
              'Moderátor',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class CommunityProfileScreen extends ConsumerStatefulWidget {
  final bool editing;

  const CommunityProfileScreen({super.key, this.editing = false});

  @override
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState
    extends ConsumerState<CommunityProfileScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final Map<String, TextEditingController> _social = {
    'facebook': TextEditingController(),
    'instagram': TextEditingController(),
    'tiktok': TextEditingController(),
    'youtube': TextEditingController(),
    'spotify': TextEditingController(),
  };
  SubmissionImage? _profileImage;
  String _profileImageUrl = '';
  String _role = 'partygoer';
  bool _register = true;
  bool _busy = false;
  bool _passwordVisible = false;
  double _focusX = 50;
  double _focusY = 25;
  double _zoom = 1;
  double _panX = 0;
  double _panY = 0;
  double _gestureStartZoom = 1;
  List<int> _claimedArtistIds = const [];
  String? _loadedUid;
  bool _loadingProfile = false;
  StreamSubscription<User?>? _authSubscription;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    _authSubscription = _service.auth.userChanges().listen((_) {
      _loadedUid = null;
      _loadProfile();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    _name.dispose();
    _bio.dispose();
    for (final controller in _social.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetImageTransform() {
    _zoom = 1;
    _focusX = 50;
    _focusY = 50;
    _panX = 0;
    _panY = 0;
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty ||
        _password.text.length < 6 ||
        (_register && _name.text.trim().isEmpty)) {
      _message('Töltsd ki a mezőket; a jelszó legalább 6 karakter legyen.');
      return;
    }
    if (_register && _password.text != _passwordConfirmation.text) {
      _message('A két jelszó nem egyezik.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        await _service.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          role: _role,
          socialLinks: _socialValues(),
        );
        // Registration succeeded and the verification mail was sent. A cleanup
        // sign-out must not turn that successful registration into a false error.
        try {
          await _service.signOut();
        } catch (_) {
          // Firebase keeps the account created; the next app start can recover.
        }
        _message(
          'Megerősítő e-mailt küldtünk. A profil használatához erősítsd meg a címedet.',
        );
      } else {
        await _service.signIn(email: _email.text, password: _password.text);
      }
      _loadedUid = null;
      await _loadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      _message(_chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile) return;
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous || _loadedUid == user.uid) return;
    _loadingProfile = true;
    try {
      if (!await _unlockProfile(user)) return;
      final snapshot = await _service.profile();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final claimedArtistIds = await _service.myClaimedArtists().catchError(
        (_) => const <int>[],
      );
      if (!mounted) return;
      setState(() {
        _name.text = data['displayName'] as String? ?? user.displayName ?? '';
        _bio.text = data['bio'] as String? ?? '';
        _loadSocialValues(data['socialLinks']);
        _profileImageUrl = _service.resolveProfileImage(
          data,
          user.photoURL ?? '',
        );
        _focusX = (data['profileFocusX'] as num?)?.toDouble() ?? 50;
        _focusY = (data['profileFocusY'] as num?)?.toDouble() ?? 25;
        _zoom = (data['profileZoom'] as num?)?.toDouble() ?? 1;
        _panX = (data['profilePanX'] as num?)?.toDouble() ?? 0;
        _panY = (data['profilePanY'] as num?)?.toDouble() ?? 0;
        _role = _service.isOwner
            ? 'organizer'
            : _service.accountRole(data['role'] as String?);
        _loadedUid = user.uid;
        _claimedArtistIds = claimedArtistIds;
      });
    } catch (_) {
    } finally {
      _loadingProfile = false;
    }
  }

  Future<bool> _unlockProfile(User user) async {
    final passwordAccount = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    final biometric = await _service.biometricEnabled();
    final deviceCode = await _service.deviceCodeEnabled();
    final authenticator =
        passwordAccount && await _service.authenticatorEnabled();
    if (!biometric && !deviceCode && !authenticator) return true;
    return _service.unlockProfileSession(user.uid, () async {
      if (biometric && !await _service.authenticateBiometric()) return false;
      if (deviceCode && !await _service.authenticateDeviceCode()) return false;
      if (authenticator) {
        if (!mounted) return false;
        final controller = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Authenticator-kód'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6 számjegyű kód'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Feloldás'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (code == null || !await _service.verifyAuthenticatorCode(code)) {
          if (mounted) _message('Az authenticator-kód hibás.');
          return false;
        }
      }
      return true;
    });
  }

  Future<void> _saveProfile() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    setState(() => _busy = true);
    try {
      final sourceImageUrl = _profileImage == null
          ? _profileImageUrl
          : await _service.uploadImage(
              _profileImage!.bytes,
              filename: _profileImage!.name,
            );
      final uploadedImageUrl = sourceImageUrl;
      final savedFocusX = _focusX.clamp(0, 100).toDouble();
      final savedFocusY = _focusY.clamp(0, 100).toDouble();
      await _service.firestore
          .collection('community_profiles')
          .doc(user.uid)
          .set({
            if (_service.isAdmin) 'displayName': _name.text.trim(),
            'bio': _bio.text.trim(),
            'socialLinks': _socialValues(),
            'profileFocusX': savedFocusX,
            'profileFocusY': savedFocusY,
            'profileZoom': _zoom,
            'profilePanX': _panX,
            'profilePanY': _panY,
            'profileImageUrl': sourceImageUrl,
            'profileSourceImageUrl': sourceImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      // Firestore is the source of truth; an Auth refresh must not turn a saved profile into a failure.
      if (_service.isAdmin) {
        await user.updateDisplayName(_name.text.trim()).catchError((_) {});
      }
      if (uploadedImageUrl.isNotEmpty) {
        await user.updatePhotoURL(uploadedImageUrl).catchError((_) {});
      }
      await user.reload().catchError((_) {});
      if (mounted) {
        setState(() {
          _profileImageUrl = sourceImageUrl;
          _focusX = savedFocusX.toDouble();
          _focusY = savedFocusY.toDouble();
          _profileImage = null;
        });
      }
      ref.invalidate(communityAuthProvider);
      _message('Profil mentve.');
    } catch (error) {
      _message('A profil mentése sikertelen: ${_chatError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestGoogleDisplayName() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Válassz megjelenési nevet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Megjelenési név',
            hintText: 'Ezt fogják látni az appban',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      final signedIn = await _service.signInWithGoogle(
        role: _register ? _role : null,
        displayName: _register ? _name.text.trim() : null,
        socialLinks: _register ? _socialValues() : null,
        requestDisplayName: _register ? null : _requestGoogleDisplayName,
      );
      if (!signedIn) return;
      _loadedUid = null;
      await _loadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      _message('Google-bejelentkezés nem sikerült: ${_chatError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _suggestPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    final random = Random.secure();
    _password.text = List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    setState(() => _passwordVisible = true);
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var currentVisible = false;
    var nextVisible = false;
    var confirmVisible = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Jelszó módosítása'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: !currentVisible,
                  decoration: InputDecoration(
                    labelText: 'Jelenlegi jelszó',
                    suffixIcon: IconButton(
                      tooltip: currentVisible ? 'Elrejtés' : 'Megjelenítés',
                      icon: Icon(
                        currentVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => currentVisible = !currentVisible,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: next,
                  obscureText: !nextVisible,
                  decoration: InputDecoration(
                    labelText: 'Új jelszó',
                    suffixIcon: IconButton(
                      tooltip: nextVisible ? 'Elrejtés' : 'Megjelenítés',
                      icon: Icon(
                        nextVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => nextVisible = !nextVisible),
                    ),
                  ),
                ),
                TextField(
                  controller: confirm,
                  obscureText: !confirmVisible,
                  decoration: InputDecoration(
                    labelText: 'Új jelszó megerősítése',
                    suffixIcon: IconButton(
                      tooltip: confirmVisible ? 'Elrejtés' : 'Megjelenítés',
                      icon: Icon(
                        confirmVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => confirmVisible = !confirmVisible,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      current.dispose();
      next.dispose();
      confirm.dispose();
      return;
    }
    if (next.text.length < 6 || next.text != confirm.text) {
      _message(
        'Az új jelszó legalább 6 karakter legyen, és a két mező egyezzen.',
      );
    } else {
      try {
        await _service.changePassword(
          currentPassword: current.text,
          newPassword: next.text,
        );
        _message('A jelszó módosítása sikerült.');
      } catch (error) {
        _message(_chatError(error));
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<bool> _reauthenticateBeforeDeletion() async {
    final user = _service.auth.currentUser;
    final usesPassword =
        user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
    if (!usesPassword) return true;

    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Újrahitelesítés'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Jelenlegi jelszó'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ellenőrzés'),
          ),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (confirmed != true || !mounted) return false;
    try {
      await _service.reauthenticateWithPassword(value);
      return true;
    } catch (error) {
      _message(_chatError(error));
      return false;
    }
  }

  Map<String, String> _socialValues() => {
    for (final entry in _social.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };

  void _loadSocialValues(Object? raw) {
    if (raw is Map) {
      for (final entry in _social.entries) {
        entry.value.text = raw[entry.key]?.toString() ?? '';
      }
      return;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      _social['facebook']!.text = raw.trim();
    }
  }

  List<Widget> _socialFields() => [
    for (final entry in const {
      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'tiktok': 'TikTok',
      'youtube': 'YouTube',
      'spotify': 'Spotify',
    }.entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _social[entry.key],
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: entry.value),
        ),
      ),
  ];

  String _roleLabel(String role) =>
      const <String, String>{
        'dj': 'DJ',
        'organizer': 'Szervező',
        'partygoer': 'Bulizó',
      }[role] ??
      'Bulizó';

  Future<void> _chooseRole() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Szerepkör'),
        children: [
          for (final option in const {
            'dj': 'DJ',
            'organizer': 'Szervező',
            'partygoer': 'Bulizó',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(option.value),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) setState(() => _role = selected);
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  Future<void> _openPlannedEvent(
    BuildContext context,
    WidgetRef ref,
    int eventId,
  ) async {
    try {
      final events = await ref.read(eventsProvider.future);
      HuhsEvent? match;
      for (final event in events) {
        if (event.id == eventId) {
          match = event;
          break;
        }
      }
      if (!context.mounted) return;
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Az esemény már nem érhető el.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(event: match!),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Az esemény nem tölthető be.')),
        );
      }
    }
  }

  List<Widget> _readOnlyProfileWidgets(User user, String initial) {
    final socialLabels = const {
      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'tiktok': 'TikTok',
      'youtube': 'YouTube',
      'spotify': 'Spotify',
    };
    final profileFavorites = ref
        .watch(favoritesProvider)
        .entries
        .where((entry) => entry.kind != FavoriteKind.news)
        .toList(growable: false);
    return [
      Center(
        child: ProfileAvatar(
          imageUrl: _profileImageUrl,
          initial: initial,
          size: 84,
          focusX: _focusX,
          focusY: _focusY,
          zoom: _zoom,
          panX: _panX,
          panY: _panY,
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: Text(
          _name.text.trim().isEmpty
              ? (user.displayName ?? user.email ?? 'HUHS user')
              : _name.text.trim(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 20),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Szerepkör'),
        subtitle: Text(
          _service.isAdmin
              ? '${_roleLabel(_service.isOwner ? 'organizer' : _role)} / Admin'
              : _roleLabel(_role),
        ),
      ),
      if (_bio.text.trim().isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes_outlined),
          title: const Text('Bemutatkozás'),
          subtitle: Text(_bio.text.trim()),
        ),
      if (_social.values.any((controller) => controller.text.trim().isNotEmpty))
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _social.entries)
              if (entry.value.text.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => openSocialLink(
                    context,
                    entry.value.text.trim(),
                    title: socialLabels[entry.key] ?? entry.key,
                  ),
                  icon: Icon(_socialIcon(entry.key)),
                  label: Text(socialLabels[entry.key] ?? entry.key),
                ),
          ],
        ),
      const SizedBox(height: 12),
      if (_claimedArtistIds.isNotEmpty)
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ArtistDetailScreen(artistId: _claimedArtistIds.first),
            ),
          ),
          icon: const Icon(Icons.library_music_outlined),
          label: const Text('Saját DJ-adatlap megnyitása'),
        ),
      if (_claimedArtistIds.isNotEmpty) const SizedBox(height: 8),
      if (profileFavorites.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'Kedvelt tartalmak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final entry in profileFavorites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: Text(entry.title),
            onTap: () => FavoritesScreen.openEntry(context, ref, entry),
            subtitle: Text(switch (entry.kind) {
              FavoriteKind.event => 'Esemény',
              FavoriteKind.artist => 'DJ',
              FavoriteKind.organizer => 'Szervező',
              FavoriteKind.news => 'Hír',
            }),
          ),
      ],
      StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _service.watchActivePlannedEvents(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const [];
          if (events.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Események, ahol ott leszek',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (final event in events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(event.data()['title'] as String? ?? 'Esemény'),
                  onTap: () {
                    final eventId = (event.data()['eventId'] as num?)?.toInt();
                    if (eventId != null) {
                      _openPlannedEvent(context, ref, eventId);
                    }
                  },
                ),
            ],
          );
        },
      ),
      FilledButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CommunityProfileScreen(editing: true),
            ),
          );
          _loadedUid = null;
          await _loadProfile();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Profil szerkesztése'),
      ),
      if (_service.isAdmin) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CommunityAdminScreen(),
            ),
          ),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Közösségi adminisztráció'),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
        ),
        icon: const Icon(Icons.favorite_outline),
        label: const Text('Kedvencek'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityConnectionsScreen(),
          ),
        ),
        icon: const Icon(Icons.people_outline),
        label: const Text('Ismerősök'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityBlockedUsersScreen(),
          ),
        ),
        icon: const Icon(Icons.block_outlined),
        label: const Text('Blokkolt felhasználók'),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () async {
          final navigator = Navigator.of(context);
          await _service.signOut();
          if (mounted) navigator.pop();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Kijelentkezés'),
      ),
    ];
  }

  IconData _socialIcon(String key) => switch (key) {
    'facebook' => Icons.facebook,
    'instagram' => Icons.camera_alt_outlined,
    'tiktok' => Icons.music_note,
    'youtube' => Icons.smart_display_outlined,
    'spotify' => Icons.queue_music_outlined,
    _ => Icons.link_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final user = _service.auth.currentUser;
    final signedIn = user != null && !user.isAnonymous;
    final profileName = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : (user?.displayName ?? user?.email ?? 'HU').trim();
    final profileInitial = profileName.isEmpty
        ? 'H'
        : profileName.characters.first.toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Profil szerkesztése' : 'Profil'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: landscape ? 900 : double.infinity,
              ),
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: signedIn
                    ? (widget.editing
                          ? [
                              Center(
                                child: ProfileAvatar(
                                  imageUrl: _profileImageUrl,
                                  initial: profileInitial,
                                  size: 84,
                                  focusX: _focusX,
                                  focusY: _focusY,
                                  zoom: _zoom,
                                  panX: _panX,
                                  panY: _panY,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Text(
                                  user.displayName ?? user.email ?? 'HUHS user',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_service.isAdmin)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                  title: Text('Szerepkör'),
                                  subtitle: Text(
                                    '${_roleLabel(_service.isOwner ? 'organizer' : _role)} / Admin',
                                  ),
                                )
                              else ...[
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      _role == 'dj' ||
                                          _role == 'organizer' ||
                                          _role == 'partygoer'
                                      ? _role
                                      : 'partygoer',
                                  decoration: const InputDecoration(
                                    labelText: 'Szerepkör',
                                    helperText:
                                        'Válaszd ki, hogyan használod az appot.',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'dj',
                                      child: Text('DJ'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'organizer',
                                      child: Text('Szervező'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'partygoer',
                                      child: Text('Bulizó'),
                                    ),
                                  ],
                                  onChanged: null,
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (_service.isAdmin)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const CommunityAdminScreen(),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                  label: const Text('Közösségi adminisztráció'),
                                ),
                              const SizedBox(height: 20),
                              SubmissionImagePicker(
                                image: _profileImage,
                                title: 'Profilkép',
                                helperText:
                                    'Opcionális kép; monogram jelenik meg, ha nincs feltöltve.',
                                onChanged: (image) => setState(() {
                                  _profileImage = image;
                                  if (image != null) _resetImageTransform();
                                }),
                              ),
                              if (_profileImage != null ||
                                  _profileImageUrl.isNotEmpty) ...[
                                const Text('Kép igazítása (húzás és nagyítás)'),
                                Center(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: (_) =>
                                        _gestureStartZoom = _zoom,
                                    onScaleUpdate: (details) {
                                      setState(() {
                                        _zoom =
                                            (_gestureStartZoom * details.scale)
                                                .clamp(1, 3);
                                        _panX =
                                            (_panX +
                                                    details.focalPointDelta.dx /
                                                        260)
                                                .clamp(-1, 1);
                                        _panY =
                                            (_panY +
                                                    details.focalPointDelta.dy /
                                                        260)
                                                .clamp(-1, 1);
                                      });
                                    },
                                    child: ProfileAvatar(
                                      imageUrl: _profileImageUrl,
                                      imageBytes: _profileImage?.bytes,
                                      initial: profileInitial,
                                      size: 260,
                                      focusX: _focusX,
                                      focusY: _focusY,
                                      zoom: _zoom,
                                      panX: _panX,
                                      panY: _panY,
                                    ),
                                  ),
                                ),
                              ],
                              TextField(
                                controller: _name,
                                readOnly: !_service.isAdmin,
                                decoration: const InputDecoration(
                                  labelText: 'Megjelenő név',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _bio,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Bemutatkozás',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._socialFields(),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _busy ? null : _saveProfile,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Profil mentése'),
                              ),
                              if (user.providerData.any(
                                (provider) => provider.providerId == 'password',
                              )) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _changePassword,
                                  icon: const Icon(Icons.password_outlined),
                                  label: const Text('Jelszó módosítása'),
                                ),
                              ],
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const FavoritesScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.favorite_outline),
                                label: const Text('Kedvencek'),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tervezett események az Ott leszek funkcióval jelennek majd meg.',
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  await _service.signOut();
                                  if (mounted) navigator.pop();
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Kijelentkezés'),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text('Profil törlése'),
                                            content: const Text(
                                              'A profilod, a Chat-üzeneteid és a bejelentkezésed is törlődik. Folytatod?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                ),
                                                child: const Text('Mégse'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Profil törlése',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;
                                        if (!context.mounted) return;
                                        if (!await _reauthenticateBeforeDeletion()) {
                                          return;
                                        }
                                        if (!context.mounted) return;
                                        final typedConfirmation =
                                            TextEditingController();
                                        final verified = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) =>
                                              AlertDialog(
                                                title: const Text(
                                                  'Végső megerősítés',
                                                ),
                                                content: TextField(
                                                  controller: typedConfirmation,
                                                  autofocus: true,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Írd be: TÖRLÉS',
                                                      ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          false,
                                                        ),
                                                    child: const Text('Mégse'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          typedConfirmation.text
                                                                  .trim() ==
                                                              'TÖRLÉS',
                                                        ),
                                                    child: const Text(
                                                      'Törlés megerősítése',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        );
                                        typedConfirmation.dispose();
                                        if (verified != true || !mounted) {
                                          return;
                                        }
                                        setState(() => _busy = true);
                                        try {
                                          await _service.deleteOwnProfile();
                                          ref.invalidate(communityAuthProvider);
                                          ref.invalidate(
                                            communityPostsProvider,
                                          );
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                        } catch (error) {
                                          if (mounted) {
                                            _message(
                                              'A profil törlése sikertelen: ${_chatError(error)}',
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _busy = false);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.delete_forever_outlined),
                                label: const Text('Profil törlése'),
                              ),
                            ]
                          : _readOnlyProfileWidgets(user, profileInitial))
                    : [
                        const Text(
                          'Regisztráció és bejelentkezés',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'A Chat névvel és képfeltöltéssel használható.'
                              : 'Jelentkezz be a közösségi profilodhoz.',
                        ),
                        const SizedBox(height: 18),
                        if (_register)
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Megjelenő név',
                            ),
                          ),
                        if (_register) const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            labelText: 'Jelszó',
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? 'Elrejtés'
                                  : 'Megjelenítés',
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (_register) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy ? null : _suggestPassword,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                              label: const Text('Erős jelszó ajánlása'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordConfirmation,
                            obscureText: !_passwordVisible,
                            decoration: const InputDecoration(
                              labelText: 'Jelszó megerősítése',
                            ),
                          ),
                          const Text(
                            'A regisztráció után megerősítő e-mailt küldünk. '
                            'A profil használatához erősítsd meg a címedet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          ..._socialFields(),
                          const SizedBox(height: 6),
                          const Text(
                            'A profil védelméhez a regisztráció után opcionális kétfaktoros védelem kapcsolható be a Beállításokban.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _busy ? null : _chooseRole,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Szerepkör',
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(_roleLabel(_role)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _register ? 'Regisztráció' : 'Bejelentkezés',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(Icons.login),
                          label: const Text('Folytatás Google-fiókkal'),
                        ),
                        if (!_register)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (_email.text.trim().isEmpty) {
                                      _message('Add meg az e-mail-címedet.');
                                      return;
                                    }
                                    try {
                                      await _service.sendPasswordReset(
                                        _email.text,
                                      );
                                      _message(
                                        'A jelszó-visszaállító e-mail elküldve.',
                                      );
                                    } catch (error) {
                                      _message(_chatError(error));
                                    }
                                  },
                            child: const Text('Jelszó visszaállítása'),
                          ),
                        if (!_register)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (_email.text.trim().isEmpty ||
                                        _password.text.isEmpty) {
                                      _message(
                                        'Add meg az e-mail-címet és a jelszót.',
                                      );
                                      return;
                                    }
                                    try {
                                      await _service
                                          .resendEmailVerificationForCredentials(
                                            email: _email.text,
                                            password: _password.text,
                                          );
                                      _message(
                                        'Az ellenőrző e-mailt újraküldtük.',
                                      );
                                    } catch (error) {
                                      _message(_chatError(error));
                                    }
                                  },
                            child: const Text('Ellenőrző e-mail újraküldése'),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _register = !_register),
                          child: Text(
                            _register
                                ? 'Már van fiókom'
                                : 'Új fiók létrehozása',
                          ),
                        ),
                      ],
              ),
            ),
          );
        },
      ),
    );
  }
}
