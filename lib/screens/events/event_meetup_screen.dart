import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../models/event.dart';
import '../../providers/community_provider.dart';
import '../../core/errors/user_facing_error.dart';
import '../../widgets/app_text.dart';

class EventMeetupScreen extends ConsumerStatefulWidget {
  final HuhsEvent event;

  const EventMeetupScreen({super.key, required this.event});

  @override
  ConsumerState<EventMeetupScreen> createState() => _EventMeetupScreenState();
}

class _MeetupUserTile extends ConsumerWidget {
  const _MeetupUserTile({
    required this.userId,
    required this.fallbackName,
    required this.fallbackImageUrl,
    required this.subtitle,
    this.trailing,
  });

  final String userId;
  final String fallbackName;
  final String fallbackImageUrl;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<Map<String, dynamic>>(
        stream: ref.read(communityServiceProvider).watchPublicProfile(userId),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final name = (profile['displayName'] as String? ?? '').trim();
          final imageUrl = (profile['profileImageUrl'] as String? ?? '').trim();
          final resolvedImage = imageUrl.isNotEmpty
              ? imageUrl
              : fallbackImageUrl;
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: resolvedImage.isEmpty
                  ? null
                  : NetworkImage(resolvedImage),
              child: resolvedImage.isEmpty
                  ? Text(
                      (name.isNotEmpty ? name : fallbackName).characters.first
                          .toUpperCase(),
                    )
                  : null,
            ),
            title: Text(name.isNotEmpty ? name : fallbackName),
            subtitle: Text(subtitle),
            trailing: trailing,
          );
        },
      );
}

class _EventMeetupScreenState extends ConsumerState<EventMeetupScreen> {
  late Future<String?> _attendanceFuture;
  late Future<bool> _meetupFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(communityServiceProvider);
    _attendanceFuture = service.getMyAttendance(widget.event.id);
    _meetupFuture = service.getMyMeetup(widget.event.id);
  }

  Future<void> _setMeetup(bool enabled) async {
    if (_busy) return;
    if (widget.event.isPast) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Lejárt eseményen már nem módosítható a Meetup.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(communityServiceProvider)
          .setMeetup(
            widget.event.id,
            title: widget.event.title,
            enabled: enabled,
          );
      _meetupFuture = Future.value(enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleInterest(String userId, bool interested) async {
    if (widget.event.isPast) return;
    try {
      await ref
          .read(communityServiceProvider)
          .toggleMeetupInterest(
            eventId: widget.event.id,
            meetupUserId: userId,
            interested: interested,
          );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(communityServiceProvider);
    final user = service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(child: AppText('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const AppText('Meetup')),
      body: FutureBuilder<String?>(
        future: _attendanceFuture,
        builder: (context, attendance) {
          final attending = attendance.data == 'attending';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.event.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const AppText(
                'Azok láthatók itt, akik erre az eseményre Meetupot jeleztek.',
              ),
              const SizedBox(height: 12),
              FutureBuilder<bool>(
                future: _meetupFuture,
                builder: (context, meetup) => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const AppText('Találkoznék ezen az eseményen'),
                  subtitle: Text(
                    attending
                        ? tr(context, 'Ezt minden regisztrált felhasználó láthatja.')
                        : tr(context, 'A bekapcsoláshoz előbb jelöld be: Ott leszek.'),
                  ),
                  value: meetup.data ?? false,
                  onChanged: widget.event.isPast || !attending || _busy
                      ? null
                      : _setMeetup,
                ),
              ),
              const Divider(),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchEventMeetups(widget.event.id),
                builder: (context, snapshot) {
                  final entries = snapshot.data?.docs ?? const [];
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: AppText('Egyelőre senki nem jelzett Meetupot.'),
                    );
                  }
                  return Column(
                    children: entries.map((entry) {
                      final data = entry.data();
                      final interestedBy = Map<String, dynamic>.from(
                        data['interestedBy'] as Map? ?? const {},
                      );
                      final interested = interestedBy[user.uid] == true;
                      final count = interestedBy.values
                          .where((value) => value == true)
                          .length;
                      return _MeetupUserTile(
                        userId: entry.id,
                        fallbackName:
                            (data['displayName'] as String? ?? tr(context, 'HUHS user'))
                                .trim(),
                        fallbackImageUrl: (data['imageUrl'] as String? ?? '')
                            .trim(),
                        subtitle: count == 0
                            ? 'Meetup'
                            : trArgs(context, '{n} érdeklődő', {
                                'n': '$count',
                              }),
                        trailing:
                            !widget.event.isPast &&
                                attending &&
                                entry.id != user.uid
                            ? OutlinedButton.icon(
                                onPressed: () =>
                                    _toggleInterest(entry.id, !interested),
                                icon: Icon(
                                  interested
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                                label: Text(
                                  interested
                                      ? tr(context, 'Visszavonás')
                                      : tr(context, 'Én is'),
                                ),
                              )
                            : null,
                      );
                    }).toList(),
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
