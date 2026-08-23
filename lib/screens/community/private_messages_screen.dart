import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/input/sentence_capitalization_formatter.dart';
import '../../services/community_service.dart';
import '../more/community_users_screen.dart';

class PrivateMessagesScreen extends StatefulWidget {
  const PrivateMessagesScreen({super.key});

  @override
  State<PrivateMessagesScreen> createState() => _PrivateMessagesScreenState();
}

class _PrivateMessagesScreenState extends State<PrivateMessagesScreen> {
  final _service = CommunityService();

  Future<Map<String, dynamic>> _profile(String id) async {
    final snapshot = await _service.firestore
        .collection('community_profiles')
        .doc(id)
        .get();
    return snapshot.data() ?? const {};
  }

  Future<void> _deleteConversation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beszélgetés törlése'),
        content: const Text('Törlöd ezt a privát beszélgetést?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePrivateConversation(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privát üzenetek')),
        body: const Center(
          child: Text('Privát üzenetekhez regisztráció szükséges.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privát üzenetek'),
        actions: [
          IconButton(
            tooltip: 'Új privát üzenet',
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
              child: Text('A beszélgetések nem tölthetők be.'),
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
            return const Center(child: Text('Még nincs privát beszélgetés.'));
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
                            : 'HUHS user');
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
                            child: Text('Beszélgetés törlése'),
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
      appBar: AppBar(title: const Text('Új privát üzenet')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchRegisteredProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('A felhasználók nem tölthetők be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _search.text.trim().toLowerCase();
          final profiles =
              snapshot.data!.docs.where((profile) {
                if (profile.id == currentUid) return false;
                final name = (profile.data()['displayName'] as String? ?? '')
                    .trim()
                    .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList()..sort((a, b) {
                final aName = (a.data()['displayName'] as String? ?? '')
                    .toLowerCase();
                final bName = (b.data()['displayName'] as String? ?? '')
                    .toLowerCase();
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
                  decoration: const InputDecoration(
                    labelText: 'Kinek szeretnél írni?',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final data = profile.data();
                    final name = (data['displayName'] as String? ?? '').trim();
                    final safeName = name.isEmpty ? 'HUHS user' : name;
                    return ListTile(
                      leading: _Avatar(data: data, name: safeName),
                      title: Text(safeName),
                      onTap: () => Navigator.pop(
                        context,
                        _SelectedUser(profile.id, safeName),
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
  bool _sending = false;

  String get _conversationId => _service.privateConversationId(
    _service.auth.currentUser!.uid,
    widget.otherUserId,
  );

  Future<Map<String, dynamic>> get _partnerProfile async {
    final snapshot = await _service.firestore
        .collection('community_profiles')
        .doc(widget.otherUserId)
        .get();
    return snapshot.data() ?? const {};
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendPrivateMessage(
        otherUserId: widget.otherUserId,
        text: _controller.text,
      );
      _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Igen'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  Future<void> _messageActions(String id, String text) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Üzenet szerkesztése'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Üzenet törlése'),
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
    }
  }

  Future<void> _editMessage(String id, String text) async {
    final controller = TextEditingController(text: text);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üzenet szerkesztése'),
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
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Mentés'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
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
          return const Center(child: Text('Írj egy üzenetet.'));
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
              return const Center(child: Text('Írj egy üzenetet.'));
            }
            return FutureBuilder<Map<String, dynamic>>(
              future: _partnerProfile,
              builder: (context, profileSnapshot) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final document = messages[messages.length - 1 - index];
                  final data = document.data();
                  final mine = data['senderId'] == user.uid;
                  final content = Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _Avatar(
                            data: profileSnapshot.data ?? const {},
                            name: widget.otherUserName,
                            radius: 16,
                          ),
                        ),
                      Flexible(
                        child: Card(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Text(data['text']?.toString() ?? ''),
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
                      onLongPress: mine
                          ? () => _messageActions(
                              document.id,
                              data['text']?.toString() ?? '',
                            )
                          : null,
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
        body: const Center(child: Text('Bejelentkezés szükséges.')),
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
                  name: widget.otherUserName,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _block();
              if (value == 'delete') _deleteConversation();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'block',
                child: Text('Felhasználó blokkolása'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Beszélgetés törlése'),
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
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: const [SentenceCapitalizationFormatter()],
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Üzenet…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
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
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.isEmpty ? Text(initial) : null,
    );
  }
}
