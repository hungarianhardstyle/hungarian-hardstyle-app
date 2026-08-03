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

String _chatError(Object error) {
  final raw = error.toString();
  if (raw.contains('admin-restricted-operation')) {
    return 'A névtelen Chat-hozzáférés nincs engedélyezve a Firebase-ben.';
  }
  if (raw.contains('permission-denied')) {
    return 'A Chat-művelethez nincs megfelelő jogosultság.';
  }
  if (raw.contains('failed-precondition') || raw.contains('unavailable')) {
    return 'A Chat az alapértelmezett Firestore-adatbázist nem éri el. Ellenőrizd, hogy a `(default)` adatbázis létre van-e hozva.';
  }
  return raw.replaceFirst('Exception: ', '');
}

class _ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String initial;
  final double size;
  final double focusX;
  final double focusY;
  final double zoom;
  final double panX;
  final double panY;
  final Uint8List? imageBytes;

  const _ProfileAvatar({
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

  const _PostAuthorAvatar(this.post);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = post.authorName.trim().isEmpty
        ? '?'
        : post.authorName.trim().characters.first.toUpperCase();
    if (post.authorId.isEmpty) {
      return _ProfileAvatar(
        imageUrl: post.authorImageUrl,
        initial: initial,
        size: 34,
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
        return _ProfileAvatar(
          imageUrl: service.resolveProfileImage(data, post.authorImageUrl),
          initial: initial,
          size: 34,
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
    final fallback = IconButton.filledTonal(
      tooltip: 'Profil',
      onPressed: onPressed,
      icon: const Icon(Icons.person_outline),
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
          icon: _ProfileAvatar(
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
                        title: Text('JelentĂ©sek (${reports.length})'),
                        children: [
                          for (final report in reports)
                            ListTile(
                              dense: true,
                              title: Text(
                                'BejegyzĂ©s: ${report.data()['postId'] ?? '-'}',
                              ),
                              subtitle: Text(
                                'Ok: ${report.data()['reason'] ?? 'egyĂ©b'}',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              */
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final doc = profiles[index];
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
                                    title: const Text('Felhasználó törlése'),
                                    content: const Text(
                                      'A profil, a Chat-üzenetek és a bejelentkezés is törlődik. Folytatod?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Mégse'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_chatError(error))),
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
                          PopupMenuButton<String>(
                            enabled: doc.id != service.auth.currentUser?.uid,
                            padding: EdgeInsets.zero,
                            tooltip: 'Adminjog / moderátori jog',
                            onSelected: doc.id == service.auth.currentUser?.uid
                                ? null
                                : (value) async {
                                    try {
                                      await service.setAccessRole(
                                        doc.id,
                                        value,
                                      );
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
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: CommunityService.accessNone,
                                child: Text('Nincs jogosultság'),
                              ),
                              PopupMenuItem(
                                value: CommunityService.accessModerator,
                                child: Text('Moderátor'),
                              ),
                              PopupMenuItem(
                                value: CommunityService.accessAdmin,
                                child: Text('Admin'),
                              ),
                            ],
                            child: Text(
                              'Jog: ${data['accessRole'] ?? (data['role'] == 'admin' ? 'admin' : 'none')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      trailing: DropdownButton<String>(
                        value:
                            const {
                              'dj',
                              'organizer',
                              'partygoer',
                            }.contains(role)
                            ? role
                            : 'partygoer',
                        items: [
                          for (final entry in const {
                            'dj': 'DJ',
                            'organizer': 'Szervező',
                            'partygoer': 'Bulizó',
                          }.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: doc.id == service.auth.currentUser?.uid
                            ? null
                            : (value) async {
                                if (value == null) return;
                                try {
                                  await service.setAccountRole(doc.id, value);
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_chatError(error))),
                                  );
                                }
                              },
                      ),
                    ),
                  );
                },
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
  Uint8List? _image;
  bool _sending = false;
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_anonymous) {
      _showMessage('Kép feltöltéséhez regisztráció szükséges.');
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return;
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
      await _service.publishPost(
        text: _textController.text,
        imageBytes: _image,
      );
      _textController.clear();
      if (mounted) setState(() => _image = null);
    } catch (error) {
      _showMessage(_chatError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            onPressed: _openProfile,
            icon: _ProfileAvatar(
              imageUrl: _anonymous ? '' : _avatarUrl,
              initial: _anonymous ? '?' : _avatarLetter,
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ha hibát találsz, írd meg nekünk a Kapcsolat menüpontban található címen.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ),
          _Composer(
            controller: _textController,
            image: _image,
            anonymous: _anonymous,
            sending: _sending,
            onPickImage: _pickImage,
            onSend: _send,
            onRemoveImage: () => setState(() => _image = null),
          ),
          Expanded(
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
                        itemBuilder: (_, index) =>
                            _PostCard(post: items[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Uint8List? image;
  final bool anonymous;
  final bool sending;
  final VoidCallback onPickImage;
  final VoidCallback onSend;
  final VoidCallback onRemoveImage;

  const _Composer({
    required this.controller,
    required this.image,
    required this.anonymous,
    required this.sending,
    required this.onPickImage,
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
            TextField(
              controller: controller,
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
                  onPressed: onPickImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                Expanded(
                  child: Text(
                    'Emoji a billentyűzetről is használható · '
                    '${anonymous ? 'Névtelenül: Unknown User ####' : 'Regisztrált felhasználóként'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
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
  const _PostCard({required this.post});

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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PostAuthorAvatar(post),
                const SizedBox(width: 9),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (post.authorRole.isNotEmpty)
                        Text(
                          post.authorRole == 'dj'
                              ? 'DJ'
                              : post.authorRole == 'organizer'
                              ? 'Szervező'
                              : 'Bulizó',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      if (post.authorAccessRole == CommunityService.accessAdmin)
                        const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (post.authorAccessRole ==
                          CommunityService.accessModerator)
                        const Text(
                          'Moderátor',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeLabel(post.createdAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (ref.read(communityServiceProvider).isAdmin)
                  IconButton(
                    tooltip: 'Üzenet szerkesztése',
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    onPressed: _edit,
                  ),
                if (ref.read(communityServiceProvider).isAdmin)
                  IconButton(
                    tooltip: 'Üzenet törlése',
                    icon: const Icon(Icons.delete_outline, size: 19),
                    onPressed: _delete,
                  ),
                if (ref.read(communityServiceProvider).isAdmin)
                  IconButton(
                    tooltip: post.pinned
                        ? 'Rögzítés feloldása'
                        : 'Üzenet rögzítése',
                    icon: Icon(
                      post.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 19,
                    ),
                    onPressed: _togglePinned,
                  ),
                if (widget.post.authorId !=
                    ref.read(communityServiceProvider).auth.currentUser?.uid)
                  PopupMenuButton<String>(
                    onSelected: _moderateUser,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'report', child: Text('Jelentés')),
                      PopupMenuItem(value: 'block', child: Text('Blokkolás')),
                    ],
                  ),
              ],
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
              const SizedBox(height: 10),
              Text(post.text),
            ],
            if (post.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(post.imageUrl, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: ['❤️', '🔥', '🙌'].map((emoji) {
                final count = post.reactions[emoji] ?? 0;
                return ActionChip(
                  label: Text('$emoji${count > 0 ? ' $count' : ''}'),
                  backgroundColor: _selectedReaction == emoji
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .25)
                      : null,
                  onPressed: () => _react(emoji),
                );
              }).toList(),
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
  String? _biometricGateUid;
  bool _loadingProfile = false;
  StreamSubscription<User?>? _authSubscription;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    _authSubscription = _service.auth.userChanges().listen((_) {
      _loadedUid = null;
      _biometricGateUid = null;
      _loadProfile();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _email.dispose();
    _password.dispose();
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
      } else {
        await _service.signIn(email: _email.text, password: _password.text);
      }
      _loadedUid = null;
      await _loadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
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
      if (_biometricGateUid != user.uid && await _service.biometricEnabled()) {
        if (!await _service.authenticateBiometric()) {
          if (mounted) _message('A profil feloldása sikertelen.');
          return;
        }
        _biometricGateUid = user.uid;
      }
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
            'displayName': _name.text.trim(),
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
      await user.updateDisplayName(_name.text.trim()).catchError((_) {});
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
      _message('A profil mentése sikertelen: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await _service.signInWithGoogle(
        role: _register ? _role : null,
        socialLinks: _register ? _socialValues() : null,
      );
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

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        child: _ProfileAvatar(
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
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchPlannedEvents(),
        builder: (context, snapshot) {
          final events = snapshot.data?.docs ?? const [];
          if (events.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Tervezett események',
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
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchMyReports(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text('Jelentések: $count'),
            subtitle: const Text('A jelentések állapota megtekinthető.'),
          );
        },
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
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: signedIn
            ? (widget.editing
                  ? [
                      Center(
                        child: _ProfileAvatar(
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
                          leading: Icon(Icons.admin_panel_settings_outlined),
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
                            DropdownMenuItem(value: 'dj', child: Text('DJ')),
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
                              builder: (_) => const CommunityAdminScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
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
                            onScaleStart: (_) => _gestureStartZoom = _zoom,
                            onScaleUpdate: (details) {
                              setState(() {
                                _zoom = (_gestureStartZoom * details.scale)
                                    .clamp(1, 3);
                                _panX =
                                    (_panX + details.focalPointDelta.dx / 260)
                                        .clamp(-1, 1);
                                _panY =
                                    (_panY + details.focalPointDelta.dy / 260)
                                        .clamp(-1, 1);
                              });
                            },
                            child: _ProfileAvatar(
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
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Mégse'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Profil törlése'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !mounted) return;
                                setState(() => _busy = true);
                                try {
                                  await _service.deleteOwnProfile();
                                  ref.invalidate(communityAuthProvider);
                                  ref.invalidate(communityPostsProvider);
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                } catch (error) {
                                  if (mounted) {
                                    _message(
                                      'A profil törlése sikertelen: $error',
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Jelszó',
                    suffixIcon: IconButton(
                      tooltip: _passwordVisible ? 'Elrejtés' : 'Megjelenítés',
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (_register) ...[
                  ..._socialFields(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _suggestPassword,
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: const Text('Erős jelszó ajánlása'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Szerepkör'),
                    items: const [
                      DropdownMenuItem(value: 'dj', child: Text('DJ')),
                      DropdownMenuItem(
                        value: 'organizer',
                        child: Text('Szervező'),
                      ),
                      DropdownMenuItem(
                        value: 'partygoer',
                        child: Text('Bulizó'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _role = value ?? 'partygoer'),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_register ? 'Regisztráció' : 'Bejelentkezés'),
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
                              await _service.sendPasswordReset(_email.text);
                              _message(
                                'A jelszó-visszaállító e-mail elküldve.',
                              );
                            } catch (error) {
                              _message(
                                error.toString().replaceFirst(
                                  'Bad state: ',
                                  '',
                                ),
                              );
                            }
                          },
                    child: const Text('Jelszó visszaállítása'),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register ? 'Már van fiókom' : 'Új fiók létrehozása',
                  ),
                ),
              ],
      ),
    );
  }
}
