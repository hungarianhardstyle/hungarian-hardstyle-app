import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/tr.dart';
import '../../core/input/sentence_capitalization_formatter.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import '../more/community_users_screen.dart';
import '../../widgets/keyboard_dismiss_button.dart';

const _privateMessageEmojis = [
  '🙂',
  '😂',
  '🤣',
  '😭',
  '😡',
  '😢',
  '😮',
  '😍',
  '😎',
  '🤔',
  '❤️',
  '🔥',
  '👍',
  '🙌',
  '🎉',
];

class PrivateMessagesScreen extends StatefulWidget {
  const PrivateMessagesScreen({super.key});

  @override
  State<PrivateMessagesScreen> createState() => _PrivateMessagesScreenState();
}

class _PrivateMessagesScreenState extends State<PrivateMessagesScreen> {
  final _service = CommunityService();

  Future<Map<String, dynamic>> _profile(String id) async {
    return _service.getPublicProfile(id);
  }

  Future<void> _deleteConversation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Beszélgetés törlése'),
        content: const AppText('Törlöd ezt a privát beszélgetést?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePrivateConversation(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Privát üzenetek')),
        body: const Center(
          child: AppText('Privát üzenetekhez regisztráció szükséges.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Privát üzenetek'),
        actions: [
          IconButton(
            tooltip: tr(context, 'Új privát üzenet'),
            icon: const Icon(Icons.add),
            onPressed: _startConversation,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchPrivateConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: AppText('A beszélgetések nem tölthetők be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aTime =
                  (a.data()['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  (b.data()['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
          if (conversations.isEmpty) {
            return const Center(child: AppText('Még nincs privát beszélgetés.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final document = conversations[index];
              final data = document.data();
              final ids = List<String>.from(
                data['participantIds'] as List? ?? const [],
              );
              final otherId = ids.firstWhere(
                (id) => id != user.uid,
                orElse: () => '',
              );
              if (otherId.isEmpty) return const SizedBox.shrink();
              final names = Map<String, dynamic>.from(
                data['participantNames'] as Map? ?? const {},
              );
              final fallbackName = names[otherId]?.toString().trim();
              return FutureBuilder<Map<String, dynamic>>(
                future: _profile(otherId),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data ?? const {};
                  final profileName = profile['displayName']?.toString().trim();
                  final name = profileName?.isNotEmpty == true
                      ? profileName!
                      : (fallbackName?.isNotEmpty == true
                            ? fallbackName!
                            : tr(context, 'HUHS user'));
                  return Card(
                    child: ListTile(
                      leading: _Avatar(data: profile, name: name),
                      title: Text(name),
                      subtitle: Text(
                        data['lastMessage']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PrivateConversationScreen(
                            otherUserId: otherId,
                            otherUserName: name,
                          ),
                        ),
                      ),
                      onLongPress: () => _deleteConversation(document.id),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteConversation(document.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: AppText('Beszélgetés törlése'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startConversation() async {
    final selected = await Navigator.of(context).push<_SelectedUser>(
      MaterialPageRoute<_SelectedUser>(
        builder: (_) => const PrivateMessageUserSearchScreen(),
      ),
    );
    if (selected == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrivateConversationScreen(
          otherUserId: selected.id,
          otherUserName: selected.name,
        ),
      ),
    );
  }
}

class _SelectedUser {
  final String id;
  final String name;

  const _SelectedUser(this.id, this.name);
}

class PrivateMessageUserSearchScreen extends StatefulWidget {
  const PrivateMessageUserSearchScreen({super.key});

  @override
  State<PrivateMessageUserSearchScreen> createState() =>
      _PrivateMessageUserSearchScreenState();
}

class _PrivateMessageUserSearchScreenState
    extends State<PrivateMessageUserSearchScreen> {
  final _service = CommunityService();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _service.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Új privát üzenet'),
        // iOS-en nincs rendszer-vissza gomb, amivel a billentyűzetet be lehetne
        // zárni — nyitott billentyűzetnél ez a gomb jelenik meg a fejlécben.
        actions: const [KeyboardDismissButton()],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getRegisteredPublicProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: AppText('A felhasználók nem tölthetők be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _search.text.trim().toLowerCase();
          final profiles =
              snapshot.data!.where((profile) {
                if (profile['userId'] == currentUid) return false;
                final name = (profile['displayName'] as String? ?? '')
                    .trim()
                    .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList()..sort((a, b) {
                final aName = (a['displayName'] as String? ?? '').toLowerCase();
                final bName = (b['displayName'] as String? ?? '').toLowerCase();
                return aName.compareTo(bName);
              });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Kinek szeretnél írni?'),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final data = profile;
                    final name = (data['displayName'] as String? ?? '').trim();
                    final safeName = name.isEmpty ? 'HUHS user' : name;
                    return ListTile(
                      leading: _Avatar(data: data, name: safeName),
                      title: Text(safeName),
                      onTap: () => Navigator.pop(
                        context,
                        _SelectedUser(
                          data['userId'] as String? ?? '',
                          safeName,
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

class PrivateConversationScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const PrivateConversationScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<PrivateConversationScreen> createState() =>
      _PrivateConversationScreenState();
}

class _PrivateConversationScreenState extends State<PrivateConversationScreen> {
  final _service = CommunityService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _sending = false;
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  String? _replyMessageId;
  String? _replyText;
  final Map<String, bool> _heartOverrides = {};
  final Set<String> _heartBusy = {};

  String get _conversationId => _service.privateConversationId(
    _service.auth.currentUser!.uid,
    widget.otherUserId,
  );

  Future<Map<String, dynamic>> get _partnerProfile async {
    return _service.getPublicProfile(widget.otherUserId);
  }

  String _partnerName(Map<String, dynamic> profile) {
    final name = profile['displayName']?.toString().trim();
    return name?.isNotEmpty == true ? name! : widget.otherUserName;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending ||
        (_controller.text.trim().isEmpty && _pendingImageBytes == null)) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.sendPrivateMessage(
        otherUserId: widget.otherUserId,
        text: _controller.text,
        replyToMessageId: _replyMessageId,
        replyToText: _replyText,
        imageBytes: _pendingImageBytes,
        imageFilename: _pendingImageName,
      );
      _controller.clear();
      if (mounted) {
        setState(() {
          _replyMessageId = null;
          _replyText = null;
          _pendingImageBytes = null;
          _pendingImageName = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > CommunityService.maxUploadBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('A kép legfeljebb 5 MB lehet.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _pendingImageBytes = bytes;
          _pendingImageName = file.name;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  void _showImageLightbox(String imageUrl) {
    if (!CommunityService.isSafeCloudinaryImageUrl(imageUrl)) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: CachedNetworkImage(imageUrl: imageUrl)),
            IconButton(
              tooltip: tr(context, 'Bezárás'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('Igen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _block() async {
    if (!await _confirm(
      'Felhasználó blokkolása',
      'Nem tudtok majd egymásnak privát üzenetet küldeni.',
    )) {
      return;
    }
    try {
      await _service.blockUser(widget.otherUserId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Future<void> _deleteConversation() async {
    if (!await _confirm(
      'Beszélgetés törlése',
      'Törlöd ezt a privát beszélgetést?',
    )) {
      return;
    }
    try {
      await _service.deletePrivateConversation(_conversationId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Future<void> _deleteMessage(String id) async {
    if (!await _confirm('Üzenet törlése', 'Törlöd ezt az üzenetet?')) return;
    try {
      await _service.deletePrivateMessage(
        conversationId: _conversationId,
        messageId: id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Future<void> _messageActions(
    String id,
    String text,
    bool currentLiked,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const AppText('Válasz'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const AppText('Szívecske'),
              onTap: () => Navigator.pop(context, 'heart'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const AppText('Üzenet szerkesztése'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const AppText('Üzenet törlése'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await _deleteMessage(id);
    } else if (action == 'edit') {
      await _editMessage(id, text);
    } else if (action == 'reply') {
      setState(() {
        _replyMessageId = id;
        _replyText = text;
      });
      _focusNode.requestFocus();
    } else if (action == 'heart') {
      await _toggleHeart(id, currentLiked: currentLiked);
    }
  }

  Future<void> _toggleHeart(String id, {bool? currentLiked}) async {
    if (_heartBusy.contains(id)) return;
    final previous = _heartOverrides[id] ?? currentLiked ?? false;
    final optimistic = !previous;
    if (mounted) {
      setState(() {
        _heartBusy.add(id);
        _heartOverrides[id] = optimistic;
      });
    }
    try {
      await _service.togglePrivateMessageReaction(
        conversationId: _conversationId,
        messageId: id,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _heartBusy.remove(id);
          _heartOverrides.remove(id);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _heartBusy.remove(id));
    }
  }

  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final text = value.text;
    final start = value.selection.start < 0
        ? text.length
        : value.selection.start;
    final end = value.selection.end < 0 ? text.length : value.selection.end;
    _controller.value = value.copyWith(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _privateMessageEmojis.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final emoji = _privateMessageEmojis[index];
              return Semantics(
                button: true,
                label: emoji,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, emoji),
                  child: Center(
                    // FittedBox keeps platform emoji glyphs inside their
                    // square cell; some Android emoji fonts have a larger
                    // ascent/descent than their visual artwork.
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26, height: 1),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (emoji != null && mounted) _insertEmoji(emoji);
  }

  Future<void> _editMessage(String id, String text) async {
    final controller = TextEditingController(text: text);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Üzenet szerkesztése'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const AppText('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || edited.trim() == text.trim()) return;
    try {
      await _service.editPrivateMessage(
        conversationId: _conversationId,
        messageId: id,
        text: edited,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Widget _messages(User user) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _service.getPrivateConversation(_conversationId),
      builder: (context, conversationSnapshot) {
        if (conversationSnapshot.hasError) {
          return Center(
            child: Text(userFacingError(conversationSnapshot.error)),
          );
        }
        if (!conversationSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!conversationSnapshot.data!.exists) {
          return const Center(child: AppText('Írj egy üzenetet.'));
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.watchPrivateMessages(_conversationId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(userFacingError(snapshot.error)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final messages = snapshot.data!.docs;
            if (messages.isEmpty) {
              return const Center(child: AppText('Írj egy üzenetet.'));
            }
            return FutureBuilder<Map<String, dynamic>>(
              future: _partnerProfile,
              builder: (context, profileSnapshot) => ListView.builder(
                reverse: true,
                // A lista húzásával is eltűnjön a billentyűzet (iOS-szokás).
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final document = messages[messages.length - 1 - index];
                  final data = document.data();
                  final mine = data['senderId'] == user.uid;
                  final replyText =
                      data['replyToText']?.toString().trim() ?? '';
                  final heartCount =
                      ((data['reactions'] as Map?)?['❤️'] as num?)?.toInt() ??
                      0;
                  final currentLiked =
                      ((data['reactionBy'] as Map?)?[user.uid]) == '❤️';
                  final liked = _heartOverrides[document.id] ?? currentLiked;
                  final visibleHeartCount =
                      heartCount +
                      (liked == currentLiked
                          ? 0
                          : liked
                          ? 1
                          : -1);
                  final rawImageUrl = data['imageUrl']?.toString().trim() ?? '';
                  final imageUrl =
                      CommunityService.isSafeCloudinaryImageUrl(rawImageUrl)
                      ? rawImageUrl
                      : '';
                  final messageText = data['text']?.toString().trim() ?? '';
                  final content = Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _Avatar(
                            data: profileSnapshot.data ?? const {},
                            name: _partnerName(
                              profileSnapshot.data ?? const {},
                            ),
                            radius: 16,
                          ),
                        ),
                      Flexible(
                        child: Card(
                          // Keep outgoing bubbles on the same dark surface as the
                          // rest of the chat. `primaryContainer` resolves to a
                          // saturated red in the dark theme, which makes the
                          // light Rajdhani text difficult to read.
                          color: mine ? const Color(0xFF2B1717) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (replyText.isNotEmpty)
                                  Text(
                                    '↪ $replyText',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: GestureDetector(
                                      onTap: () => _showImageLightbox(imageUrl),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: 240,
                                        memCacheWidth:
                                            (240 *
                                                    MediaQuery.devicePixelRatioOf(
                                                      context,
                                                    ))
                                                .round(),
                                        maxWidthDiskCache:
                                            (240 *
                                                    MediaQuery.devicePixelRatioOf(
                                                      context,
                                                    ))
                                                .round(),
                                        fit: BoxFit.contain,
                                        placeholder: (_, _) => const SizedBox(
                                          width: 240,
                                          height: 160,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (_, _, _) =>
                                            const SizedBox(
                                              width: 240,
                                              height: 80,
                                              child: Center(
                                                child: Icon(Icons.broken_image),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                if (imageUrl.isNotEmpty &&
                                    messageText.isNotEmpty)
                                  const SizedBox(height: 6),
                                if (messageText.isNotEmpty)
                                  Text(
                                    messageText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                if (visibleHeartCount > 0)
                                  Text(
                                    '❤️ $visibleHeartCount',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: GestureDetector(
                      onDoubleTap: () =>
                          _toggleHeart(document.id, currentLiked: currentLiked),
                      onLongPress: () => _messageActions(
                        document.id,
                        data['text']?.toString() ?? '',
                        currentLiked,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: content,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUserName)),
        body: const Center(child: AppText('Bejelentkezés szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _partnerProfile,
          builder: (context, snapshot) => InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    CommunityPublicProfileScreen(userId: widget.otherUserId),
              ),
            ),
            child: Row(
              children: [
                _Avatar(
                  data: snapshot.data ?? const {},
                  name: _partnerName(snapshot.data ?? const {}),
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _partnerName(snapshot.data ?? const {}),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // iOS-en nincs rendszer-vissza gomb a billentyűzethez — nyitott
          // billentyűzetnél ez jelenik meg a fejlécben.
          const KeyboardDismissButton(),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _block();
              if (value == 'delete') _deleteConversation();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'block',
                child: AppText('Felhasználó blokkolása'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: AppText('Beszélgetés törlése'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _messages(user)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyText != null)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.reply, size: 18),
                            title: Text(
                              'Válasz: $_replyText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              onPressed: () => setState(() {
                                _replyMessageId = null;
                                _replyText = null;
                              }),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        if (_pendingImageBytes != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      _pendingImageBytes!,
                                      width: 88,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: IconButton(
                                      tooltip: tr(context, 'Kép eltávolítása'),
                                      onPressed: () => setState(() {
                                        _pendingImageBytes = null;
                                        _pendingImageName = null;
                                      }),
                                      icon: const Icon(Icons.cancel, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: const [
                            SentenceCapitalizationFormatter(),
                          ],
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: tr(context, 'Üzenet…'),
                            hintStyle: TextStyle(fontSize: 16),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: tr(context, 'Kép küldése'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    tooltip: tr(context, 'Emotikon'),
                    onPressed: _showEmojiPicker,
                  ),
                  // ⚠️ Ugyanaz a gomb, mint a fejlécben — ide is, a Küldés mellé,
                  // mert írás közben ide nézünk. Zárva magától eltűnik.
                  const KeyboardDismissButton(),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Map<String, dynamic> data;
  final String name;
  final double radius;

  const _Avatar({required this.data, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final imageUrl = CommunityService().resolveProfileImage(data);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundImage: imageUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(
              CommunityService.optimizedImageUrl(
                imageUrl,
                width: (radius * 2).round(),
              ),
            ),
      child: imageUrl.isEmpty ? Text(initial) : null,
    );
  }
}
