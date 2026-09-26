import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/i18n/tr.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/i18n/notification_texts.dart';
import '../../services/notification_content_titles.dart';
import '../../core/navigation/content_target.dart';
import '../../models/app_notification.dart';
import '../../services/notification_selection_plan.dart';
import '../../services/notification_service.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import '../more/community_users_screen.dart';
import '../community/community_screen.dart';
import '../community/private_messages_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  static DateTime? _lastArchiveSweepAt;

  static Future<void> show(BuildContext context) {
    // Read notifications older than 30 days are hidden from the inbox without
    // deleting them. This keeps the list compact while preserving history.
    final now = DateTime.now();
    final shouldSweep =
        _lastArchiveSweepAt == null ||
        now.difference(_lastArchiveSweepAt!) >= const Duration(minutes: 10);
    if (shouldSweep) {
      _lastArchiveSweepAt = now;
      unawaited(
        NotificationService()
            .archiveReadOlderThan(const Duration(days: 30))
            .catchError((_) {}),
      );
    }
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 72),
        backgroundColor: Color(0xFF15171A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: NotificationCenterScreen(),
      ),
    );
  }

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  bool _showArchived = false;
  bool _openingNotification = false;

  /// Kijelölés mód (a tulajdonos kérése, 2026-09-22): így **azt** lehet
  /// törölni, amit kijelölsz — nem az egész fület, és nem is egyenként.
  ///
  /// ⚠️ Az állapot szándékosan a tesztelt `NotificationSelection` osztályban van:
  /// a korábbi képernyő-szintű megoldás (`_selected..clear()..addAll(...)`) a
  /// kaszkád miatt **mindig csak egy** azonosítót tartott meg — éles hiba volt
  /// („egyszerre csak egyet lehet kijelölni").
  bool _selecting = false;
  final NotificationSelection _selection = NotificationSelection();

  /// A **tartalom-címek** a mostani nyelven (kulcs: `nyelv|értesítés-azonosító`).
  ///
  /// A `new_news` / `new_release` / `new_event` / `new_artist` /
  /// `new_organizer` értesítés törzse **maga a cím** (adat), ezért a
  /// sablon-alapú fordítás nem érinti — a régi sorokhoz a címet a tartalomból
  /// kérdezzük vissza a mostani nyelven (lásd
  /// `services/notification_content_titles.dart`).
  final Map<String, String> _contentTitles = <String, String>{};

  /// Az éppen futó feloldások (ne induljon kétszer ugyanarra a sorra).
  final Set<String> _pendingContentTitles = <String>{};

  String _titleKey(AppNotification item) =>
      '${AppStrings.language.name}|${item.id}';

  /// A látható sorok tartalom-címeinek feloldása (egyszer, háttérben).
  void _scheduleContentTitleResolution(List<AppNotification> items) {
    if (items.isEmpty) return;
    for (final item in items) {
      final key = _titleKey(item);
      if (_contentTitles.containsKey(key) ||
          _pendingContentTitles.contains(key)) {
        continue;
      }
      final localized = NotificationTexts.localize(
        type: item.type,
        title: item.title,
        body: item.body,
      );
      if (!NotificationContentTitles.needsResolve(
        type: item.type,
        targetId: item.targetId,
        storedBody: item.body,
        localizedBody: localized.body,
      )) {
        continue;
      }
      _pendingContentTitles.add(key);
      final stored = item.body.trim();
      unawaited(
        NotificationContentTitles.resolve(
          targetType: item.targetType,
          targetId: item.targetId,
        ).then((title) {
          _pendingContentTitles.remove(key);
          if (!mounted) return;
          final resolved = title?.trim() ?? '';
          if (resolved.isEmpty || resolved == stored) return;
          setState(() => _contentTitles[key] = resolved);
        }),
      );
    }
  }

  Future<void> _deleteSelected(List<AppNotification> items) async {
    final ids = deletableNotificationIds(
      items: items,
      selected: _selection.ids,
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
    if (ids.isEmpty) return;
    try {
      final removed = await NotificationService().deleteIds(ids);
      if (!mounted) return;
      setState(() {
        _selection.clear();
        _selecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notificationDeletedLabel(removed))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('A kijelöltek törlése nem sikerült.')),
      );
    }
  }

  void _toggleSelection(String id) {
    setState(() => _selection.toggle(id));
  }

  Future<void> _handleAction(
    BuildContext context,
    AppNotification notification,
    String action,
  ) async {
    final service = NotificationService();
    try {
      if (action == 'read') {
        await service.markRead(notification);
      } else if (action == 'archive') {
        await service.archive(notification);
      } else if (action == 'delete') {
        await service.delete(notification);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('A művelet nem sikerült.')),
        );
      }
    }
  }

  /// Az ÉPP LÁTHATÓ fül értesítéseinek törlése.
  ///
  /// A tulajdonos jelzése: *„ha az aktív fülön nyomok egy összes törlését, töröl
  /// mindent még az archiváltat is, ezt külön kéne választani: aktívban az
  /// aktívat törölje, archivban az archiváltakat"*.
  ///
  /// Ezért a megerősítő szöveg is a fület nevezi meg, hogy senki ne töröljön
  /// véletlenül a másik fülből, és a törlés is a látható fülre szűkül.
  Future<void> _deleteAll(BuildContext context) async {
    final archived = _showArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          // ⚠️ A „archivált" ág eddig NYERS literál volt (a ternary másik ága
          // fordítva) — ezért angol felületen magyarul jelent meg.
          tr(
            context,
            archived
                ? 'Archivált értesítések törlése'
                : 'Aktív értesítések törlése',
          ),
        ),
        content: Text(
          archived
              ? tr(context, 'Biztosan törlöd az összes ARCHIVÁLT értesítést? Az aktív fül értesítései megmaradnak.')
              : tr(context, 'Biztosan törlöd az összes AKTÍV értesítést? Az archivált értesítések megmaradnak.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NotificationService().deleteAll(archived: archived);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Az értesítések törlése nem sikerült.')),
        );
      }
    }
  }

  Future<void> _markAllRead(BuildContext context) async {
    try {
      await NotificationService().markAllRead();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Az értesítések frissítése nem sikerült.'),
          ),
        );
      }
    }
  }

  Future<void> _open(BuildContext context, AppNotification notification) async {
    if (_openingNotification) return;
    _openingNotification = true;
    // Navigation must not wait for a network write. A slow Firestore write
    // previously made the first tap appear to do nothing.
    unawaited(NotificationService().markRead(notification));
    // Keep the parent navigator before closing the dialog. The dialog
    // context is unmounted by pop(), so using it for the target route makes
    // the first tap a no-op and forces a second tap in some cases.
    final navigator = Navigator.of(context);
    navigator.pop();
    // Yield one frame for the dialog removal, but do not add a visible fixed
    // delay. The target should open on the first tap even on a slow network.
    await Future<void>.delayed(Duration.zero);
    if (!navigator.mounted) return;
    final target = notification.targetId;
    try {
      if (notification.targetType == 'profile' && target.isNotEmpty) {
        // A személy-célpont **közös** feloldása (a Chat-`@`hivatkozás
        // ugyanezt hívja) — így a kettő nem tud széthúzni.
        await openContentTarget(
          navigator,
          targetType: notification.targetType,
          targetId: target,
        );
        return;
      }
      if (notification.targetType == 'private_conversation' &&
          target.isNotEmpty) {
        final senderId = notification.senderId.trim();
        // ⚠️ A küldő neve a cím elején áll; a cím utótagja **nyelvfüggő**
        // (magyar: „… üzenetet küldött", angol: „… sent you a message"), ezért
        // mindkettőt levágjuk — különben angol felületen a név elveszne.
        final senderName = notification.title
            .replaceFirst(
              RegExp(r'\s+(üzenetet küldött|sent you a message)\s*$'),
              '',
            )
            .trim();
        if (senderId.isNotEmpty) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => PrivateConversationScreen(
                otherUserId: senderId,
                otherUserName: senderName.isEmpty ? 'HUHS user' : senderName,
              ),
            ),
          );
          return;
        }
        final conversation = await CommunityService().getPrivateConversation(
          target,
        );
        final data = conversation.data() ?? const <String, dynamic>{};
        final participantIds = (data['participantIds'] as List? ?? const [])
            .whereType<String>();
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final otherUserId = participantIds.firstWhere(
          (id) => id != currentUid,
          orElse: () => notification.senderId,
        );
        if (!navigator.mounted || otherUserId.trim().isEmpty) return;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PrivateConversationScreen(
              otherUserId: otherUserId,
              otherUserName: senderName.isEmpty ? 'HUHS user' : senderName,
            ),
          ),
        );
        return;
      }
      if (notification.targetType == 'chat') {
        // A Chat-értesítés (lájk vagy válasz) a **Chat** képernyőt nyitja, és a
        // tulajdonos kérése szerint **arra az üzenetre** görget, amelyről szól
        // (`targetId` a chat-bejegyzés azonosítója).
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => LiveFeedScreen(focusPostId: target),
          ),
        );
        return;
      }
      if (notification.targetType == 'chat_report') {
        // ⚠️ A chatjelentés azonosítója **nem szám** (a `targetId` a jelentés
        // dokumentum-azonosítója), ezért ezt az ágat a szám-feldolgozás ELŐTT
        // kell kezelni — különben a koppintás némán elveszne.
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityReportsScreen(),
          ),
        );
        return;
      }
      if (notification.targetType == 'achievement' && target.isNotEmpty) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: target),
          ),
        );
        return;
      }
      final id = int.tryParse(target);
      if (id == null) return;
      // A tartalom-célpontok (cikk, esemény, kiadvány, DJ, szervező)
      // feloldása **közös** (`openContentTarget`) — ugyanaz, amit a Chat
      // `@`hivatkozása hív. A korábbi, itt másolt ágak pontosan ezek voltak
      // (ugyanazok a képernyők, ugyanaz a sorrend), csak egy helyen.
      if (const {
        'news',
        'article',
        'event',
        'release',
        'artist',
        'organizer',
      }.contains(notification.targetType)) {
        await openContentTarget(
          navigator,
          targetType: notification.targetType,
          targetId: target,
        );
      }
    } catch (_) {
      // The inbox remains usable if a newly-created WP item is not visible yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .66,
        width: double.infinity,
        child: StreamBuilder<List<AppNotification>>(
          stream: NotificationService().watchNotifications(
            includeArchived: _showArchived,
          ),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <AppNotification>[];
            // ⚠️ A tartalom-értesítések TÖRZSE maga a cím (adat), ezért a
            // sablon-fordítás nem érinti — a régi sorokhoz a címet a mostani
            // nyelven, a tartalomból kérdezzük vissza (best-effort, gyorsítótárral).
            _scheduleContentTitleResolution(items);
            final colors = Theme.of(context).colorScheme;
            final actionStyle = IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              backgroundColor: colors.surfaceContainer,
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Kijelölés közben a fejléc megmondja, hány sor van
                          // kijelölve — így nem kell a listát számolgatni.
                          _selecting
                              ? notificationSelectionLabel(
                                  _selection.countWithin(items),
                                )
                              : tr(context, 'Értesítések'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (_selecting) ...[
                        IconButton(
                          style: actionStyle,
                          tooltip: tr(context, 'Összes kijelölése ezen a fülön'),
                          onPressed: items.isEmpty
                              ? null
                              : () => setState(
                                  () => _selection.selectAll(
                                    items.map((item) => item.id),
                                  ),
                                ),
                          icon: const Icon(Icons.select_all_rounded, size: 20),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: actionStyle,
                          tooltip: tr(context, 'Kijelöltek törlése'),
                          onPressed: _selection.countWithin(items) == 0
                              ? null
                              : () => unawaited(_deleteSelected(items)),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: actionStyle,
                          tooltip: tr(context, 'Kijelölés kikapcsolása'),
                          onPressed: () => setState(() {
                            _selection.clear();
                            _selecting = false;
                          }),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ] else ...[
                        IconButton(
                          style: actionStyle,
                          tooltip: tr(context, 'Kijelölés törléshez'),
                          onPressed: items.isEmpty
                              ? null
                              : () => setState(() {
                                  _selecting = true;
                                  _selection.clear();
                                }),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: actionStyle,
                          tooltip: tr(context, 'Összes olvasottra jelölése'),
                          onPressed: items.isEmpty
                              ? null
                              : () => unawaited(_markAllRead(context)),
                          icon: const Icon(Icons.done_all_rounded, size: 20),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: actionStyle,
                          // A tooltip is megmondja, MELYIK fulett töröl — a gomb a
                          // látható fülre vonatkozik, nem mindenre.
                          tooltip: _showArchived
                              ? tr(context, 'Összes archivált törlése')
                              : tr(context, 'Összes aktív törlése'),
                          onPressed: items.isEmpty
                              ? null
                              : () => unawaited(_deleteAll(context)),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: actionStyle,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.notifications_none),
                        label: AppText('Aktív'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.archive_outlined),
                        label: AppText('Archivált'),
                      ),
                    ],
                    selected: {_showArchived},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primaryContainer
                            : colors.surfaceContainer,
                      ),
                      foregroundColor: WidgetStatePropertyAll(colors.onSurface),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: colors.outline),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    onSelectionChanged: (selection) {
                      setState(() {
                        _showArchived = selection.first;
                        // Fület váltva a kijelölés törlődik: a másik fül más
                        // listát mutat, ott a régi kijelölés félrevezetne.
                        _selection.clear();
                        _selecting = false;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: snapshot.hasError
                      ? const Center(
                          child: AppText('Az értesítések nem tölthetők be.'),
                        )
                      : items.isEmpty
                      ? Center(
                          child: Text(
                            _showArchived
                                ? tr(context, 'Nincs archivált értesítés.')
                                : tr(context, 'Nincs új értesítés.'),
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            // A tárolt szöveg a mostani nyelvre fordítva (a
                            // katalógusból; ismeretlen típusnál változatlan).
                            final localized = NotificationTexts.localize(
                              type: item.type,
                              title: item.title,
                              body: item.body,
                            );
                            // A tartalom-cím (cikk/DJ/esemény/…) a mostani
                            // nyelven — ha már megvan a feloldás.
                            final contentTitle = _contentTitles[_titleKey(item)];
                            return Material(
                              color: item.isRead
                                  ? colors.surfaceContainer
                                  : colors.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: colors.outlineVariant),
                              ),
                              child: ListTile(
                                minVerticalPadding: 8,
                                // Kijelölés módban a koppintás **jelöl**, nem
                                // nyit meg — így lehet több sort kijelölni.
                                onTap: _selecting
                                    ? () => _toggleSelection(item.id)
                                    : () => unawaited(_open(context, item)),
                                leading: _selecting
                                    ? Icon(
                                        _selection.contains(item.id)
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: _selection.contains(item.id)
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      )
                                    : Icon(
                                        item.isRead
                                            ? Icons.notifications_none
                                            : Icons.notifications_active,
                                        color: item.isRead
                                            ? colors.onSurfaceVariant
                                            : colors.primary,
                                      ),
                                title: Text(
                                  // ⚠️ A tárolt szöveget a MEGJELENÍTÉS helyén
                                  // fordítjuk a mostani nyelvre (a szerver a
                                  // létrehozáskor renderelte) — ettől a váltás
                                  // azonnal látszik, a régi sorokon is.
                                  localized.title.trim().isEmpty
                                      ? tr(context, 'Értesítés')
                                      : localized.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                subtitle: Text(
                                  contentTitle ?? localized.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!item.isRead)
                                      Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: colors.primary,
                                      ),
                                    // Kijelölés módban nincs soronkénti menü: ott a
                                    // koppintás jelöl, a művelet pedig a fejlécben van.
                                    if (!_selecting)
                                      PopupMenuButton<String>(
                                        tooltip: tr(context, 'Értesítés műveletei'),
                                        onSelected: (action) => unawaited(
                                          _handleAction(context, item, action),
                                        ),
                                        itemBuilder: (_) => [
                                          if (!item.isRead)
                                            const PopupMenuItem(
                                              value: 'read',
                                              child: AppText('Olvasottnak jelölés'),
                                            ),
                                          if (!item.isArchived)
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: AppText('Archiválás'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: AppText('Törlés'),
                                          ),
                                        ],
                                      ),
                                  ],
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
