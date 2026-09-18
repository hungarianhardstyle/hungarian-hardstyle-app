import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/errors/user_facing_error.dart';
import '../core/firebase/firebase_callable.dart';
import '../core/input/sentence_capitalization_formatter.dart';
import '../services/community_service.dart';
import 'resized_network_image.dart';

class ArticleComments extends StatefulWidget {
  final int postId;
  const ArticleComments({super.key, required this.postId});
  @override
  State<ArticleComments> createState() => _ArticleCommentsState();
}

class _ArticleCommentsState extends State<ArticleComments> {
  final _input = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  StreamSubscription<User?>? _auth;
  bool _loading = false, _sending = false, _more = false, _moderator = false;
  String? _error, _pendingId, _pendingText;
  String? _replyToId, _replyToName, _replyToText;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (!_sending) {
        _input.clear();
        _pendingId = null;
        _pendingText = null;
      }
      _load();
    });
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final result = await callFirebaseCallable<dynamic>(
      'articleComments',
      parameters: {'postId': widget.postId, ...data},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _load({bool next = false}) async {
    if (next && _loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!next) _items.clear();
    });
    try {
      final result = await _call({
        'action': 'list',
        if (next && _items.isNotEmpty) 'cursor': _items.last['id'],
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _items.map((item) => item['id']).toSet();
        _items.addAll(
          (result['items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((item) => ids.add(item['id'])),
        );
        _more = result['hasMore'] == true;
        _moderator = result['moderator'] == true;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = userFacingError(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final text = CommunityService.maskProfanity(_input.text.trim());
    if (_sending || text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A hozzászóláshoz jelentkezz be.')),
        );
      }
      return;
    }
    if (_pendingText != text) {
      _pendingText = text;
      _pendingId = FirebaseFirestore.instance.collection('unused').doc().id;
    }
    setState(() => _sending = true);
    try {
      await _call({
        'action': 'create',
        'id': _pendingId,
        'text': text,
        if (_replyToId != null) 'replyToCommentId': _replyToId,
      });
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return;
      }
      _input.clear();
      _pendingId = null;
      _pendingText = null;
      _replyToId = null;
      _replyToName = null;
      _replyToText = null;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replyTo(Map<String, dynamic> item) {
    setState(() {
      _replyToId = item['id'] as String?;
      _replyToName = (item['authorName'] as String? ?? '').trim();
      _replyToText = (item['text'] as String? ?? '').trim();
    });
  }

  /// A hozzászólás szerkesztése — a szerző a sajátját, moderátor bárkiét.
  ///
  /// A tulajdonos kérése: *„a chaten a felhasználó tudja szerkeszteni a saját
  /// üzenetét, ugyanezt a cikkek alatti kommenteknél is. Admin természetesen
  /// mindenkiét"*. A jogosultságot a `articleComments` callable ellenőrzi a
  /// szerveren (ugyanaz a szabály, mint a törlésnél), a felület csak a saját
  /// soron kínálja fel a lehetőséget.
  Future<void> _edit(Map<String, dynamic> item) async {
    var text = (item['text'] as String? ?? '').trim();
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hozzászólás szerkesztése'),
        content: TextFormField(
          initialValue: text,
          autofocus: true,
          maxLines: 5,
          maxLength: 2000,
          onChanged: (value) => text = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    if (updated == null || !mounted) return;
    final trimmed = CommunityService.maskProfanity(updated.trim());
    if (trimmed.isEmpty) return;
    try {
      await _call({'action': 'edit', 'id': item['id'], 'text': trimmed});
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    }
  }

  Future<void> _action(Map<String, dynamic> item, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'delete'
              ? 'Törlöd a hozzászólást?'
              : 'Jelented a hozzászólást?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Megerősítés'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _call({'action': action, 'id': item['id']});
      if (!mounted) return;
      if (action == 'delete') {
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Köszönjük, a jelentést elküldtük.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final registered = user != null && !user.isAnonymous;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hozzászólások',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Hozzászólások frissítése',
                onPressed: _loading ? null : () => _load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(),
              child: const Text('Újrapróbálás'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const Text(
              'Még nincs hozzászólás. Mondd el elsőként a véleményed!',
            ),
          ..._items.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: ClipOval(
                            child: ResizedNetworkImage(
                              url: item['imageUrl'] as String? ?? '',
                              physicalWidth:
                                  (40 * MediaQuery.devicePixelRatioOf(context))
                                      .round()
                                      .clamp(96, 240),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (_, error, stack) =>
                                  const Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['authorName'] as String? ?? 'HUHS tag',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (registered)
                          PopupMenuButton<String>(
                            onSelected: (action) => switch (action) {
                              'reply' => _replyTo(item),
                              'edit' => _edit(item),
                              _ => _action(item, action),
                            },
                            itemBuilder: (_) => [
                              if (item['authorId'] != user.uid)
                                const PopupMenuItem(
                                  value: 'reply',
                                  child: Text('Válasz'),
                                ),
                              // A szerző a sajátját, moderátor bárkiét — ez a
                              // szerveren is ugyanígy van kikényszerítve.
                              if (item['authorId'] == user.uid || _moderator)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Szerkesztés'),
                                ),
                              if (item['authorId'] == user.uid || _moderator)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Törlés'),
                                ),
                              if (item['authorId'] != user.uid)
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('Jelentés'),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if ((item['replyToName'] as String? ?? '').trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: (item['replyToName'] as String).trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' hozzászólására: '),
                              TextSpan(
                                text: (item['replyToText'] as String? ?? '')
                                    .trim(),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(item['text'] as String? ?? ''),
                    // A szerkesztes jelzese: a szerzo (es a moderator) utolag
                    // atirhatja a szoveget, ezert latszania kell, hogy a
                    // hozzaszolas mar nem az eredeti.
                    if ((item['editedAt'] as num?)?.toInt() != null &&
                        (item['editedAt'] as num).toInt() > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'szerkesztve',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_more)
            TextButton(
              onPressed: _loading ? null : () => _load(next: true),
              child: const Text('Korábbi hozzászólások'),
            ),
          const SizedBox(height: 12),
          ...[
            if (_replyToText != null && _replyToText!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(
                    _replyToName?.isNotEmpty == true
                        ? 'Válasz $_replyToName hozzászólására: $_replyToText'
                        : 'Válasz erre: $_replyToText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () => setState(() {
                    _replyToId = null;
                    _replyToName = null;
                    _replyToText = null;
                  }),
                ),
              ),
            TextField(
              controller: _input,
              enabled: !_sending,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: const [SentenceCapitalizationFormatter()],
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Írd meg a véleményed…',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: Text(_sending ? 'Küldés…' : 'Hozzászólok'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
