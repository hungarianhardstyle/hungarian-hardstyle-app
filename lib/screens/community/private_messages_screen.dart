import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/community_service.dart';

class PrivateMessagesScreen extends StatefulWidget {
  const PrivateMessagesScreen({super.key});

  @override
  State<PrivateMessagesScreen> createState() => _PrivateMessagesScreenState();
}

class _PrivateMessagesScreenState extends State<PrivateMessagesScreen> {
  final CommunityService _service = CommunityService();

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
      appBar: AppBar(title: const Text('Privát üzenetek')),
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
              final data = conversations[index].data();
              final ids = List<String>.from(
                data['participantIds'] as List? ?? const [],
              );
              final otherId = ids.firstWhere(
                (id) => id != user.uid,
                orElse: () => '',
              );
              final names = Map<String, dynamic>.from(
                data['participantNames'] as Map? ?? const {},
              );
              final name = names[otherId]?.toString().trim();
              if (otherId.isEmpty) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(name?.isNotEmpty == true ? name! : 'HUHS user'),
                  subtitle: Text(
                    data['lastMessage']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PrivateConversationScreen(
                        otherUserId: otherId,
                        otherUserName: name?.isNotEmpty == true
                            ? name!
                            : 'HUHS user',
                      ),
                    ),
                  ),
                ),
              );
            },
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
  final CommunityService _service = CommunityService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    final conversationId = _service.privateConversationId(
      user.uid,
      widget.otherUserId,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.watchPrivateMessages(conversationId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Az üzenetek nem tölthetők be.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(child: Text('Írj egy üzenetet.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[messages.length - 1 - index].data();
                    final mine = data['senderId'] == user.uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 6),
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
                    );
                  },
                );
              },
            ),
          ),
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
                      onTap: _focusNode.requestFocus,
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
