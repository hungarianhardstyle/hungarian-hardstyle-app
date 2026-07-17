import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/community_post.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../more/favorites_screen.dart';

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
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
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
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityPostsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Feed'),
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined),
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
                  'A Live Feed nem érhető el.\n$error',
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
                const Text(
                  'Emoji a billentyűzetről is használható',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
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

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  child: Icon(Icons.person_outline, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _timeLabel(post.createdAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
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
            const Row(
              children: [
                Icon(Icons.favorite_border, size: 18, color: Colors.white54),
                SizedBox(width: 14),
                Icon(
                  Icons.emoji_emotions_outlined,
                  size: 18,
                  color: Colors.white54,
                ),
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
  String _role = 'partygoer';
  bool _register = true;
  bool _busy = false;
  bool _profileLoaded = false;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void dispose() {
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
    if (user == null || user.isAnonymous || _profileLoaded) return;
    try {
      final snapshot = await _service.profile();
      final data = snapshot.data() ?? const <String, dynamic>{};
      _name.text = data['displayName'] as String? ?? user.displayName ?? '';
      _bio.text = data['bio'] as String? ?? '';
      _social.text = data['socialLinks'] as String? ?? '';
      _profileLoaded = true;
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    setState(() => _busy = true);
    try {
      await _service.firestore.collection('community_profiles').doc(user.uid).set({
        'displayName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'socialLinks': _social.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(_name.text.trim());
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
      await _service.signInWithGoogle();
      if (mounted) setState(() {});
    } catch (error) {
      _message('Google-bejelentkezés nem sikerült: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    if (signedIn) _loadProfile();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: signedIn
            ? [
                CircleAvatar(
                  radius: 42,
                  child: Text(
                    (user.displayName ?? 'HU').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 30),
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
          const SizedBox(height: 20),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Megjelenő név')),
          const SizedBox(height: 12),
          TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bemutatkozás')),
          const SizedBox(height: 12),
          TextField(controller: _social, maxLines: 2, decoration: const InputDecoration(labelText: 'Social linkek')),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _busy ? null : _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('Profil mentése')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FavoritesScreen())), icon: const Icon(Icons.favorite_outline), label: const Text('Kedvencek')),
          const SizedBox(height: 8),
          const Text('Tervezett események az Ott leszek funkcióval jelennek majd meg.'),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _service.signOut();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Kijelentkezés'),
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
                      ? 'A Live Feed névvel és képfeltöltéssel használható.'
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
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Jelszó'),
                ),
                if (_register) ...[
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
