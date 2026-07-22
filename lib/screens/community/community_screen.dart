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
import '../../models/submission_image.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/submission_image_picker.dart';
import '../more/favorites_screen.dart';

String _chatError(Object error) {
  final raw = error.toString();
  if (raw.contains('admin-restricted-operation')) {
    return 'A névtelen Chat-hozzáférés nincs engedélyezve a Firebase-ben.';
  }
  if (raw.contains('permission-denied')) {
    return 'A Chat Firebase-szabályai még nincsenek telepítve.';
  }
  if (raw.contains('failed-precondition') || raw.contains('unavailable')) {
    return 'A Chat az alapértelmezett Firestore-adatbázist nem éri el. Ellenőrizd, hogy a `(default)` adatbázis létre van-e hozva.';
  }
  return raw.replaceFirst('Exception: ', '');
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
    final service = ref.watch(communityServiceProvider);
    final user = service.auth.currentUser;
    if (user == null || user.isAnonymous) return fallback;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.firestore
          .collection('community_profiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final url = data['profileImageUrl'] as String? ?? '';
        final name =
            (data['displayName'] as String? ?? user.displayName ?? 'HU').trim();
        return IconButton(
          tooltip: 'Profil',
          onPressed: onPressed,
          icon: CircleAvatar(
            radius: 18,
            backgroundImage: url.isEmpty ? null : NetworkImage(url),
            child: url.isEmpty
                ? Text(name.isEmpty ? 'H' : name[0].toUpperCase())
                : null,
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

  @override
  void dispose() {
    _search.dispose();
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
          if (profiles.isEmpty) {
            return const Center(child: Text('Még nincs regisztrált profil.'));
          }
          return Column(
            children: [
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
              Expanded(
                child: ListView.builder(
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
                            if (confirmed != true || !context.mounted) return;
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
                  title: Text(data['displayName'] as String? ?? 'HUHS user'),
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
                                  await service.setAccessRole(doc.id, value);
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_chatError(error))),
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
                    value: const {'dj', 'organizer', 'partygoer'}.contains(role)
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

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
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
    if (user == null || user.isAnonymous) return;
    try {
      final data =
          (await _service.profile()).data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _avatarUrl = data['profileImageUrl'] as String? ?? '';
        final name = data['displayName'] as String? ?? user.displayName ?? '';
        _avatarLetter = name.trim().isEmpty
            ? 'H'
            : name.trim()[0].toUpperCase();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
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
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: _avatarUrl.isEmpty
                  ? null
                  : NetworkImage(_avatarUrl),
              child: _avatarUrl.isEmpty
                  ? Text(_anonymous ? '?' : _avatarLetter)
                  : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  'A Chat nem érhető el.\n${_chatError(error)}',
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
                  onPressed: onPickImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                const Expanded(
                  child: Text(
                    'Emoji a billentyűzetről is használható',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                FilledButton.icon(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Küldés'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                anonymous
                    ? 'Névtelenül: Unknown User ####'
                    : 'Regisztrált felhasználóként',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
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
                CircleAvatar(
                  radius: 17,
                  backgroundImage: post.authorImageUrl.isEmpty
                      ? null
                      : NetworkImage(post.authorImageUrl),
                  child: post.authorImageUrl.isEmpty
                      ? Text(
                          post.authorName.trim().isEmpty
                              ? '?'
                              : post.authorName.trim()[0].toUpperCase(),
                        )
                      : null,
                ),
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
                if (ref.read(communityServiceProvider).canModerate)
                  IconButton(
                    tooltip: 'Üzenet törlése',
                    icon: const Icon(Icons.delete_outline, size: 19),
                    onPressed: _delete,
                  ),
              ],
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
  const CommunityProfileScreen({super.key});

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
  final _social = TextEditingController();
  SubmissionImage? _profileImage;
  String _profileImageUrl = '';
  String _role = 'partygoer';
  bool _register = true;
  bool _busy = false;
  bool _passwordVisible = false;
  String? _loadedUid;
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
    _name.dispose();
    _bio.dispose();
    _social.dispose();
    super.dispose();
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
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous || _loadedUid == user.uid) return;
    try {
      final snapshot = await _service.profile();
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _name.text = data['displayName'] as String? ?? user.displayName ?? '';
        _bio.text = data['bio'] as String? ?? '';
        _social.text = data['socialLinks'] as String? ?? '';
        _profileImageUrl = data['profileImageUrl'] as String? ?? '';
        _role = _service.accountRole(data['role'] as String?);
        _loadedUid = user.uid;
      });
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    setState(() => _busy = true);
    try {
      final uploadedImageUrl = _profileImage == null
          ? _profileImageUrl
          : await _service.uploadImage(_profileImage!.bytes, faceFocus: true);
      await _service.firestore
          .collection('community_profiles')
          .doc(user.uid)
          .set({
            'displayName': _name.text.trim(),
            'bio': _bio.text.trim(),
            'socialLinks': _social.text.trim(),
            'role': _role,
            'profileImageUrl': uploadedImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await user.updateDisplayName(_name.text.trim());
      if (uploadedImageUrl.isNotEmpty) {
        await user.updatePhotoURL(uploadedImageUrl);
      }
      if (mounted) {
        setState(() {
          _profileImageUrl = uploadedImageUrl;
          _profileImage = null;
        });
      }
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
      await _service.signInWithGoogle(role: _register ? _role : null);
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

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.auth.currentUser;
    final signedIn = user != null && !user.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: signedIn
            ? [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: _profileImageUrl.isNotEmpty
                      ? NetworkImage(_profileImageUrl)
                      : null,
                  child: _profileImageUrl.isEmpty
                      ? Text(
                          (user.displayName ?? 'HU')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(fontSize: 30),
                        )
                      : null,
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
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Szerepkör'),
                    subtitle: Text('Szervező · Admin'),
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
                      helperText: 'Válaszd ki, hogyan használod az appot.',
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
                  onChanged: (image) => setState(() => _profileImage = image),
                ),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Megjelenő név'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bemutatkozás'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _social,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Social linkek'),
                ),
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
                            if (mounted) Navigator.of(context).pop();
                          } catch (error) {
                            if (mounted) {
                              _message('A profil törlése sikertelen: $error');
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Profil törlése'),
                ),
              ]
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
