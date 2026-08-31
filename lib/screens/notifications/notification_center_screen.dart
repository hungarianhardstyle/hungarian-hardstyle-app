import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/wordpress_service.dart';
import '../more/community_users_screen.dart';
import '../community/private_messages_screen.dart';
import '../events/event_detail_screen.dart';
import '../news/news_detail_screen.dart';
import '../releases/release_detail_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        backgroundColor: Color(0xFF17090B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
        child: NotificationCenterScreen(),
      ),
    );
  }

  Future<void> _open(BuildContext context, AppNotification notification) async {
    await NotificationService().markRead(notification);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final target = notification.targetId;
    try {
      if (notification.targetType == 'profile' && target.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: target),
          ),
        );
        return;
      }
      if (notification.targetType == 'private_conversation' &&
          target.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PrivateMessagesScreen(),
          ),
        );
        return;
      }
      final id = int.tryParse(target);
      if (id == null) return;
      if (notification.targetType == 'news') {
        final post = await WordpressService().getPost(id);
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NewsDetailScreen(post: post),
            ),
          );
        }
      } else if (notification.targetType == 'event') {
        final event = (await WordpressService().getEvents()).firstWhere(
          (item) => item.id == id,
          orElse: () => throw StateError('Event not found'),
        );
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailScreen(event: event),
            ),
          );
        }
      } else if (notification.targetType == 'release') {
        final release = (await WordpressService().getReleases()).firstWhere(
          (item) => item.id == id,
          orElse: () => throw StateError('Release not found'),
        );
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReleaseDetailScreen(release: release),
            ),
          );
        }
      }
    } catch (_) {
      // The inbox remains usable if a newly-created WP item is not visible yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        width: double.infinity,
        child: StreamBuilder<List<AppNotification>>(
          stream: NotificationService().watchNotifications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint(
                'Értesítések Firestore-lekérdezési hiba: '
                '${snapshot.error}',
              );
              debugPrintStack(stackTrace: snapshot.stackTrace);
            }
            final items = snapshot.data ?? const <AppNotification>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Értesítések',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: snapshot.hasError
                      ? const Center(
                          child: Text('Az értesítések nem tölthetők be.'),
                        )
                      : items.isEmpty
                      ? const Center(
                          child: Text(
                            'Nincs új értesítés.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Material(
                              color: item.isRead
                                  ? const Color(0xFF211416)
                                  : const Color(0xFF321519),
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                onTap: () => unawaited(_open(context, item)),
                                leading: Icon(
                                  item.isRead
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                  color: Colors.redAccent,
                                ),
                                title: Text(
                                  item.title.isEmpty ? 'Értesítés' : item.title,
                                ),
                                subtitle: Text(
                                  item.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: item.isRead
                                    ? null
                                    : const Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: Colors.redAccent,
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
      ),
    );
  }
}
