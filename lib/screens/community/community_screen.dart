import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
import '../../models/community_post.dart';
import '../../models/achievement.dart';
import '../../models/event.dart';
import '../../models/submission_image.dart';
import '../../core/navigation/content_target.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/input/sentence_capitalization_formatter.dart';
import '../../providers/community_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/chat_paging.dart';
import '../../services/chat_focus_plan.dart';
import '../../services/chat_mention_plan.dart';
import '../../services/chat_mention_source.dart';
import '../../services/community_service.dart';
import '../../services/chat_display_preferences.dart';
import '../../widgets/app_text.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../../services/referral_link_service.dart';
import '../../widgets/submission_image_picker.dart';
import '../../widgets/achievement_badge_card.dart';
import '../../widgets/chat_mention_overlay.dart';
import '../../widgets/chat_message_text.dart';
import '../../widgets/community_profile_form_fields.dart';
import '../../widgets/chat_emoji_button.dart';
import '../../widgets/keyboard_dismiss_button.dart';
import '../../widgets/profile_content_card.dart';
import '../more/favorites_screen.dart';
import '../more/community_users_screen.dart';
import '../artists/artist_detail_screen.dart';
import '../events/event_detail_screen.dart';
import 'wordpress_admin_screen.dart';
import 'private_messages_screen.dart';

String _chatError(Object error) {
  return userFacingError(error);
}

class ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String initial;
  final double size;
  final double focusX;
  final double focusY;
  final double zoom;
  final double panX;
  final double panY;
  final Uint8List? imageBytes;

  const ProfileAvatar({
    super.key,
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        : CachedNetworkImage(
                            imageUrl: CommunityService.optimizedImageUrl(
                              imageUrl,
                              width: (size * 2).round(),
                            ),
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              (focusX.clamp(0, 100) - 50) / 50,
                              (focusY.clamp(0, 100) - 50) / 50,
                            ),
                            memCacheWidth: (size * 2).round(),
                            maxWidthDiskCache: (size * 2).round(),
                            errorWidget: (_, _, _) => fallback,
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
  final bool compact;

  const _PostAuthorAvatar(this.post, {this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = post.authorName.trim().isEmpty
        ? '?'
        : post.authorName.trim().characters.first.toUpperCase();
    if (post.authorId.isEmpty) {
      return ProfileAvatar(
        imageUrl: post.authorImageUrl,
        initial: initial,
        size: compact ? 30 : 34,
      );
    }
    final service = ref.watch(communityServiceProvider);
    return StreamBuilder<Map<String, dynamic>>(
      stream: service.watchPublicProfile(post.authorId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final currentName = (data['displayName'] as String?)?.trim();
        return ProfileAvatar(
          imageUrl: service.resolveProfileImage(data, post.authorImageUrl),
          initial:
              (currentName?.isNotEmpty == true
                      ? currentName!
                      : post.authorName.trim().isNotEmpty
                      ? post.authorName.trim()
                      : 'H')
                  .characters
                  .first
                  .toUpperCase(),
          size: compact ? 30 : 34,
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
    final fallback = IconButton(
      tooltip: tr(context, 'Profil'),
      onPressed: onPressed,
      icon: const ProfileAvatar(imageUrl: '', initial: 'H', size: 36),
    );
    if (Firebase.apps.isEmpty) return fallback;
    ref.watch(communityAuthProvider);
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
        final rawUrl = service.resolveProfileImage(data);
        final storedName = (data['displayName'] as String? ?? '').trim();
        final name = storedName.isNotEmpty && !storedName.contains('@')
            ? storedName
            : 'HU';
        final initial = name.characters.first.toUpperCase();
        return IconButton(
          tooltip: tr(context, 'Profil'),
          onPressed: onPressed,
          icon: ProfileAvatar(
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
  String _roleFilter = 'all';

  String _roleFilterLabel() => AppStrings.tr(
    const {
      'all': 'Mindenki',
      'admin': 'Admin',
      'dj': 'DJ',
      'organizer': 'Szervező',
      'partygoer': 'Bulizó',
    }[_roleFilter] ??
        AppStrings.tr('Mindenki'),
  );

  Future<String?> _pickAdminRole({
    required String title,
    required List<(String, String)> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: AppText(title)),
            for (final option in options)
              ListTile(
                title: AppText(option.$2),
                trailing: option.$1 == current
                    ? const Icon(Icons.check, color: Colors.redAccent)
                    : null,
                selected: option.$1 == current,
                onTap: () => Navigator.pop(sheetContext, option.$1),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAdminAccountRole(
    CommunityService service,
    String uid,
    String current,
  ) async {
    final value = await _pickAdminRole(
      title: tr(context, 'Fiók-szerepkör'),
      current: current,
      options: const [
        ('dj', 'DJ'),
        ('organizer', 'Szervező'),
        ('partygoer', 'Bulizó'),
      ],
    );
    if (value == null || value == current || !mounted) return;
    try {
      await service.setAccountRole(uid, value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _changeAdminAccessRole(
    CommunityService service,
    String uid,
    String current,
  ) async {
    final value = await _pickAdminRole(
      title: tr(context, 'Hozzáférési jog'),
      current: current,
      options: const [
        (CommunityService.accessNone, 'Nincs jogosultság'),
        (CommunityService.accessModerator, 'Moderátor'),
        (CommunityService.accessAdmin, 'Admin'),
      ],
    );
    if (value == null || value == current || !mounted) return;
    try {
      await service.setAccessRole(uid, value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _changeAdminDisplayName(
    CommunityService service,
    String uid,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Felhasználónév módosítása'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: tr(context, 'Új nyilvános név')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const AppText('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim() == current.trim() || !mounted) return;
    try {
      await service.adminSetDisplayName(uid, value);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_chatError(error))));
      }
    }
  }

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
      appBar: AppBar(title: const AppText('Közösségi adminisztráció')),
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
          final filteredProfiles = profiles.where((doc) {
            if (_roleFilter == 'all') return true;
            final data = doc.data();
            if (_roleFilter == 'admin') {
              return data['accessRole'] == CommunityService.accessAdmin ||
                  data['role'] == CommunityService.accessAdmin;
            }
            return service.accountRole(data['role'] as String?) == _roleFilter;
          }).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 220),
            children: [
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const AppText('HUHS Vezérlőközpont'),
                subtitle: const AppText('WordPress Mobile API adminisztráció'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WordPressAdminScreen(),
                  ),
                ),
              ),
              if (profiles.isEmpty)
                const Center(child: AppText('Még nincs regisztrált profil.')),
              if (profiles.isNotEmpty)
                const ListTile(
                  leading: Icon(Icons.people_outline),
                  title: AppText('Felhasználók'),
                  subtitle: AppText('Regisztrált felhasználók és jogosultságok'),
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
                            decoration: InputDecoration(
                              labelText: tr(context, 'Rögzített Chat-üzenet'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: tr(context, 'Küldés és rögzítés'),
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
                  decoration: InputDecoration(
                    labelText: tr(context, 'Felhasználó keresése'),
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
                  label: const AppText('Jelentések kezelése'),
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
                        title: AppText(
                          trArgs(context, 'Jelentések ({n})', {
                            'n': '${reports.length}',
                          }),
                        ),
                        children: [
                          for (final report in reports)
                            ListTile(
                              dense: true,
                              title: Text(
                                'Bejegyzés: ${report.data()['postId'] ?? '-'}',
                              ),
                              subtitle: Text(
                                'Ok: ${report.data()['reason'] ?? 'egyéb'}',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              */
              ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.people_outline),
                title: Text(
                  'Regisztrált felhasználók (${filteredProfiles.length})',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: PopupMenuButton<String>(
                      tooltip: tr(context, 'Szerepkör szűrése'),
                      offset: const Offset(0, 58),
                      color: const Color(0xFF171717),
                      onSelected: (value) =>
                          setState(() => _roleFilter = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'all', child: AppText('Mindenki')),
                        PopupMenuItem(value: 'admin', child: AppText('Admin')),
                        PopupMenuItem(value: 'dj', child: Text('DJ')),
                        PopupMenuItem(
                          value: 'organizer',
                          child: AppText('Szervező'),
                        ),
                        PopupMenuItem(
                          value: 'partygoer',
                          child: AppText('Bulizó'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF21B1B1B),
                          border: Border.all(color: const Color(0xFF5A2424)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const AppText('Szerepkör szűrése'),
                            const Spacer(),
                            Text(_roleFilterLabel()),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      final doc = filteredProfiles[index];
                      final data = doc.data();
                      final role = service.accountRole(data['role'] as String?);
                      final email = (data['email'] as String? ?? '').trim();
                      return Card(
                        child: ListTile(
                          leading: IconButton(
                            tooltip: tr(context, 'Felhasználó törlése'),
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: doc.id == service.auth.currentUser?.uid
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const AppText(
                                          'Felhasználó törlése',
                                        ),
                                        content: const AppText(
                                          'A profil, a Chat-üzenetek és a bejelentkezés is törlődik. Folytatod?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const AppText('Mégse'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: const AppText('Törlés'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !context.mounted) {
                                      return;
                                    }
                                    try {
                                      final cleanupStatus = await service
                                          .deleteUser(doc.id);
                                      if (!context.mounted) return;
                                      // A tulajdonos jelzése: *„adminként nem törli az
                                      // usert"*. A törlés a szerveren valóban lefutott,
                                      // ezért mostantól VISSZA IS ELLENŐRIZZÜK (szerverről,
                                      // nem cache-ből) — így a válasz egyértelmű.
                                      bool? stillThere;
                                      try {
                                        final snapshot = await service.firestore
                                            .collection('community_profiles')
                                            .doc(doc.id)
                                            .get(
                                              const GetOptions(
                                                source: Source.server,
                                              ),
                                            );
                                        stillThere = snapshot.exists;
                                      } catch (_) {
                                        // Hálózati hiba: nem állítjuk, hogy sikerült, de
                                        // nem is kiabálunk feleslegesen hibát.
                                        stillThere = null;
                                      }
                                      if (!context.mounted) return;
                                      final message = stillThere == true
                                          ? tr(context, 'A fiók törlése nem fejeződött be a szerveren. Próbáld újra.')
                                          : cleanupStatus == 'cleanup_pending'
                                          ? tr(context, 'A felhasználó törölve; a képek háttértakarítása folyamatban van.')
                                          : tr(context, 'A felhasználó törlése sikerült.');
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(_chatError(error)),
                                            ),
                                          );
                                    }
                                  },
                          ),
                          title: TextButton(
                            onPressed: () => _changeAdminDisplayName(
                              service,
                              doc.id,
                              data['displayName'] as String? ?? tr(context, 'HUHS user'),
                            ),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.zero,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                data['displayName'] as String? ?? tr(context, 'HUHS user'),
                              ),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                email.isEmpty
                                    ? tr(context, 'E-mail-cím nem érhető el')
                                    : email,
                              ),
                              TextButton(
                                onPressed:
                                    doc.id == service.auth.currentUser?.uid
                                    ? null
                                    : () => _changeAdminAccessRole(
                                        service,
                                        doc.id,
                                        data['accessRole'] as String? ??
                                            CommunityService.accessNone,
                                      ),
                                child: Text(
                                  'Jog: ${data['accessRole'] ?? (data['role'] == 'admin' ? 'admin' : 'none')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: doc.id == service.auth.currentUser?.uid
                                ? null
                                : () => _changeAdminAccountRole(
                                    service,
                                    doc.id,
                                    data['role'] as String? ?? 'partygoer',
                                  ),
                            child: Text(
                              {
                                    'dj': 'DJ',
                                    'organizer': tr(context, 'Szervező'),
                                    'partygoer': tr(context, 'Bulizó'),
                                  }[role] ??
                                  role,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class LiveFeedScreen extends ConsumerStatefulWidget {
  final VoidCallback? onProfileDeleted;

  /// Az értesítésből érkező üzenet-azonosító.
  ///
  /// A tulajdonos kérése (2026-09-24): *„a chatnél meg odaugorhatna arra az
  /// üzenetre amit lájkoltak, ha a notifyre nyomok"* — ezért a Chat-értesítés
  /// koppintásakor a képernyő **erre az üzenetre** görget és rövid ideig
  /// kiemeli. Üresen a szokásos chat nyílik (a legfrissebb üzenetekkel).
  final String? focusPostId;

  const LiveFeedScreen({super.key, this.onProfileDeleted, this.focusPostId});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  static const _profileRefreshInterval = Duration(minutes: 2);
  final _textController = TextEditingController();
  final _composerFocusNode = FocusNode();
  Uint8List? _image;
  bool _sending = false;
  String? _replyToText;
  String? _replyToName;

  /// KINEK válaszolunk (a válaszolt üzenet szerzőjének UID-ja).
  ///
  /// A szerző neve és a szöveg csak a megjelenítéshez kell; az **értesítéshez**
  /// (a tulajdonos kérése: *„Ha valaki válaszol neked a chaten legyen róla
  /// notify"*) a szerver a szerző UID-ját kapja ebben a mezőben.
  String? _replyToAuthorId;
  bool _anonymous = true;

  /// A `@`hivatkozás javaslatainak **adatforrása** (hálózat + cache).
  ///
  /// ⚠️ Lustán jön létre: a képernyő létrehozásakor még **nem** szabad Firebase-t
  /// (Auth/Firestore) érinteni — a widget-tesztek provider-felülírással, Firebase
  /// nélkül futtatják ezt a képernyőt, és egy mező-inicializáló ott elhasalna.
  /// Ráadásul így a hálózat is csak az első `@`-ra indul.
  ChatMentionSource? _mentionSourceLazy;
  ChatMentionSource get _mentionSource =>
      _mentionSourceLazy ??= ChatMentionSource(community: _service);

  /// Az éppen gépelt `@`-token (`null` = nincs aktív hivatkozás).
  MentionQuery? _mentionQuery;

  /// A kurzor, amikor a [mentionQuery] keletkezett — a beszúrás ezt használja.
  int _mentionCaret = 0;

  /// A listában látszó javaslatok (a tiszta szűrő eredménye).
  List<MentionSuggestion> _mentionSuggestions = const <MentionSuggestion>[];

  /// A már betöltött **személy**-javaslatok (egyszer, lustán, cache-elve).
  List<MentionSuggestion>? _mentionUsers;

  /// A már betöltött **tartalom**-javaslatok (csak admin/moderátornak).
  Map<String, List<MentionSuggestion>> _mentionContent =
      const <String, List<MentionSuggestion>>{};

  /// A kiválasztott hivatkozások (a szövegbe beírt célpontok).
  ///
  /// ⚠️ Ez csak **jelölt**: a küldésnél a szövegben **ténylegesen benne lévő**
  /// hivatkozások mennek át (`mentionSpans`), ezért egy visszatörölt `@név`
  /// nem küld magával felesleges hivatkozást.
  final List<ChatMentionTarget> _mentions = <ChatMentionTarget>[];

  /// Indult-e már a javaslatok betöltése (a hálózat csak **egyszer** fut).
  bool _mentionDataRequested = false;

  /// A bejelentkezett fiók hivatkozás-jogosultsága (`accessRole`).
  String? _mentionAccessRole;
  String _avatarUrl = '';
  String _avatarLetter = 'H';
  double _avatarFocusX = 50;
  double _avatarFocusY = 25;
  double _avatarZoom = 1;
  double _avatarPanX = 0;
  double _avatarPanY = 0;
  StreamSubscription<User?>? _authSubscription;
  late final VoidCallback _achievementRefreshListener;
  Timer? _profileRefreshTimer;
  int _profileRefreshGeneration = 0;

  /// A chat görgetése (a lapozáshoz).
  final _chatScrollController = ScrollController();

  /// Látszik-e a „a legfrissebbhez" gomb (ha a felhasználó mélyen visszagörgetett).
  final _showJumpToNewest = ValueNotifier<bool>(false);

  /// A már betöltött RÉGEBBI üzenetek (a legfrissebb 60 élő ablakon kívül).
  final List<CommunityPost> _olderPosts = [];
  bool _loadingOlder = false;
  bool _reachedChatStart = false;

  /// Az értesítésből megjelölt üzenet (a notify koppintásakor).
  String? _focusTarget;

  /// A megjelölt üzenet kártyájának kulcsa — ezzel görgetünk pontosan oda.
  final GlobalKey _focusKey = GlobalKey();

  /// Épp kiemelt üzenet (rövid ideig látszik, hogy megtalálja a felhasználó).
  String? _highlightedPostId;

  /// Hány régebbi lapot töltöttünk be **az odaugráshoz** (a lap-korlát ehhez van).
  int _focusPagesLoaded = 0;

  /// A megjelölt üzenet **indexe** a megjelenített listában (a tervből). Ebből
  /// becsüljük a görgetési pozíciót, mert a kártya gyakran még nincs felépítve.
  int? _focusIndex;

  /// Hányszor próbáljuk meg a becsült pozícióra ugrani (a `maxScrollExtent`
  /// maga is becslés, ezért lehet, hogy az első ugrás nem elég pontos).
  static const int _focusScrollAttempts = 4;

  /// A megjelenített lista hossza (élő ablak + betöltött régebbiek + a láb sor).
  int get _focusItemCount =>
      (ref.read(communityPostsProvider).valueOrNull?.length ?? 0) +
      _olderPosts.length +
      1;

  /// Végeztünk-e az odaugrással (megtaláltuk, vagy feladtuk).
  bool _focusFinished = false;

  Timer? _highlightTimer;

  /// A régebbi lap mérete. 30 üzenet laponként: ennyi olvasás, és a felhasználó
  /// hamarabb lát eredményt, mintha 100-at kérnénk egyszerre.
  static const int _olderPageSize = 30;

  /// Ennyi pixelen belül kezdjük tölteni a régebbi üzeneteket (nem kell a
  /// legvégéig görgetni).
  static const double _loadOlderThreshold = 600;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    _achievementRefreshListener = _onAchievementRefreshSignal;
    CommunityService.publicProfileRefreshGeneration.addListener(
      _achievementRefreshListener,
    );
    _authSubscription = _service.auth.userChanges().listen((user) {
      if (!mounted) return;
      CommunityService.clearPublicProfileCache();
      setState(() {
        _profileRefreshGeneration++;
        _anonymous = user == null || user.isAnonymous;
        if (_anonymous) {
          _avatarUrl = '';
          _avatarLetter = 'H';
        }
      });
      unawaited(_refreshAvatar());
    });
    _profileRefreshTimer = Timer.periodic(
      _profileRefreshInterval,
      (_) => _refreshPublicProfiles(),
    );
    _chatScrollController.addListener(_maybeLoadOlderPosts);
    // A `@`javaslatlista a beviteli mező **változásaira** épül (gépelés ÉS
    // kurzormozgatás is jelzést ad) — ezért itt egy listener, nem `onChanged`.
    _textController.addListener(_onComposerChanged);
    _prepareAnonymousUser();
    final target = widget.focusPostId?.trim() ?? '';
    if (target.isNotEmpty) {
      _focusTarget = target;
      // Az első képkocka után: ekkor van értelme a listáról dönteni.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resolveFocus(ref.read(communityPostsProvider).valueOrNull ?? const []);
        }
      });
    } else {
      _focusFinished = true;
    }
  }

  @override
  void dispose() {
    _chatScrollController.removeListener(_maybeLoadOlderPosts);
    _textController.removeListener(_onComposerChanged);
    _highlightTimer?.cancel();
    _chatScrollController.dispose();
    _showJumpToNewest.dispose();
    _authSubscription?.cancel();
    CommunityService.publicProfileRefreshGeneration.removeListener(
      _achievementRefreshListener,
    );
    _profileRefreshTimer?.cancel();
    _textController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  /// A chat a LEGFRISSESEBB üzenettel kezdődik, ezért **lefelé** görgetve haladunk
  /// visszafelé az időben — a tulajdonos kérése pontosan ez: *„lefele
  /// scrollozáskor töltsön be"*.
  void _maybeLoadOlderPosts() {
    if (!mounted) return;
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    _showJumpToNewest.value = position.pixels > 900;
    if (_loadingOlder || _reachedChatStart) return;
    if (position.extentAfter > _loadOlderThreshold) return;
    unawaited(_loadOlderPosts());
  }

  /// A régebbi üzenetek betöltése. Egyszeri lekérdezés, ezért 5000 üzenetnél sem
  /// lassul le a chat: mindig csak a következő 30-at kérjük.
  ///
  /// Visszatérés: **történt-e valódi lapozás** (indult-e kérés és megjött-e a
  /// válasz). Az odaugrás ebből tudja, hogy elhasznált-e egy lapot a keretből —
  /// a „nincs mit lapozni" és a hálózati hiba **nem** fogyaszt lapot.
  Future<bool> _loadOlderPosts() async {
    final newest = ref.read(communityPostsProvider).valueOrNull;
    if (newest == null) return false;
    final boundary = ChatPaging.oldestBoundary(<CommunityPost>[
      ...newest,
      ..._olderPosts,
    ]);
    if (boundary == null) return false;
    setState(() => _loadingOlder = true);
    try {
      final incoming = await _service.loadOlderPosts(
        before: boundary,
        limit: _olderPageSize,
      );
      if (!mounted) return false;
      final fresh = ChatPaging.newOlderPosts(
        incoming: incoming,
        newest: newest,
        alreadyOlder: _olderPosts,
      );
      setState(() {
        _olderPosts.addAll(fresh);
        _loadingOlder = false;
        _reachedChatStart = ChatPaging.reachedStart(
          received: incoming.length,
          pageSize: _olderPageSize,
        );
      });
      return true;
    } catch (_) {
      // Hálózati hiba: nem jelöljük „nincs több"-nek, hogy a következő
      // görgetésnél újra lehessen próbálni.
      if (mounted) setState(() => _loadingOlder = false);
      return false;
    }
  }

  void _jumpToNewest() {
    if (!_chatScrollController.hasClients) return;
    _chatScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Eldönti, hogy a megjelölt üzenet a betöltött listában van-e; ha nincs,
  /// lapoz tovább (a döntés a tiszta `chat_focus_plan.dart`-ban van).
  ///
  /// ⚠️ Ez a metódus `setState`-et NEM hív közvetlenül a `build` alatt: minden
  /// tényleges munka (görgetés, lapozás) **post-frame** callbackben fut, ezért
  /// a hívó a `build`-ből és a lapozás befejezése után is hívhatja.
  void _resolveFocus(List<CommunityPost> newest) {
    if (_focusFinished || !mounted) return;
    final target = _focusTarget;
    if (target == null || target.isEmpty) {
      _focusFinished = true;
      return;
    }
    final plan = chatFocusPlan(
      focusId: target,
      newestIds: newest.map((post) => post.id).toList(growable: false),
      olderIds: _olderPosts.map((post) => post.id).toList(growable: false),
      reachedStart: _reachedChatStart,
      loadedPages: _focusPagesLoaded,
    );
    switch (plan.status) {
      case ChatFocusStatus.found:
        _focusFinished = true;
        _focusIndex = plan.index;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_scrollToFocusedPost());
        });
      case ChatFocusStatus.waiting:
        // ⚠️ Az élő ablak még nem érkezett meg: NEM lapozunk és nem fogyasztjuk
        // a lap-keretet. A `communityPostsProvider` figyelője (lásd `build`)
        // úgyis újrahív minket, amint megjön az első adat — így a 10 lapos keret
        // nem ég el a betöltés alatt (ez volt a „néha nem ugrik oda" gyökere).
        return;
      case ChatFocusStatus.keepLoading:
        if (_loadingOlder) return;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // ⚠️ Közben megérkezhetett az adat (és a `found` ág már lefutott):
          // ilyenkor nem indítunk fölösleges lapozást.
          if (!mounted || _focusFinished) return;
          final loaded = await _loadOlderPosts();
          if (!mounted || _focusFinished) return;
          if (!loaded) {
            // Nem volt mit lapozni vagy hálózati hiba: nincs értelme tovább
            // pörögni (a chat a szokásos módon nyílik).
            _focusFinished = true;
            return;
          }
          _focusPagesLoaded++;
          _resolveFocus(
            ref.read(communityPostsProvider).valueOrNull ?? const [],
          );
        });
      case ChatFocusStatus.giveUp:
        // Az üzenet nincs a betölthető ablakban (nagyon régi, vagy törölték):
        // ilyenkor a chat a szokásos módon nyílik, nem görgetünk találomra.
        _focusFinished = true;
    }
  }

  /// Odagörget a megjelölt üzenethez, és rövid ideig kiemeli.
  ///
  /// ⚠️ A `ListView` **csak a látható** elemeket építi fel, ezért a megjelölt
  /// kártya kontextusa (amit a `Scrollable.ensureVisible` kér) gyakran **nincs
  /// meg**. A korábbi kód ilyenkor a lista **végére** ugrott — az a legrégebbi
  /// üzeneteket mutatja, nem a megjelöltet (a tulajdonos jelzése: *„régebbi chat
  /// üzivel nem megy, újabba igen"*). Mostantól a cél **indexéből becsült**
  /// pozícióra ugrunk (`chatScrollEstimateForIndex`), és néhányszor ismétlünk,
  /// mert a `maxScrollExtent` maga is a felépített gyerekekből számolt becslés.
  Future<void> _scrollToFocusedPost() async {
    final target = _focusTarget;
    if (!mounted || target == null || target.isEmpty) return;
    setState(() => _highlightedPostId = target);
    // Egy képkockát adunk a kártyának, hogy felépüljön.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    for (var attempt = 0; attempt < _focusScrollAttempts; attempt++) {
      final current = _focusKey.currentContext;
      if (current != null && current.mounted) break;
      final index = _focusIndex;
      if (index == null || !_chatScrollController.hasClients) break;
      final offset = chatScrollEstimateForIndex(
        index: index,
        itemCount: _focusItemCount,
        maxScrollExtent: _chatScrollController.position.maxScrollExtent,
      );
      await _chatScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }
    final targetContext = _focusKey.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _highlightedPostId = null);
    });
  }

  /// A megjelölt üzenet kártyáját kiemelő keret (csak az érintett kártyára).
  Widget _withFocusHighlight(Widget card, String postId) {
    if (_highlightedPostId != postId) return card;
    return Container(
      key: _focusKey,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: card,
    );
  }

  void _refreshPublicProfiles() {
    CommunityService.clearPublicProfileCache();
    if (mounted) setState(() => _profileRefreshGeneration++);
  }

  void _onAchievementRefreshSignal() {
    if (mounted) setState(() => _profileRefreshGeneration++);
  }

  Future<void> _refreshChat() async {
    _refreshPublicProfiles();
    // A frissítés a legfrissebb állapotot mutatja: a betöltött régebbi lapokat
    // eldobjuk, különben a képernyőn maradna egy régi szelet.
    if (_olderPosts.isNotEmpty || _reachedChatStart) {
      setState(() {
        _olderPosts.clear();
        _reachedChatStart = false;
      });
    }
    ref.invalidate(communityPostsProvider);
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
        _avatarUrl = _service.resolveProfileImage(data);
        _avatarFocusX = (data['profileFocusX'] as num?)?.toDouble() ?? 50;
        _avatarFocusY = (data['profileFocusY'] as num?)?.toDouble() ?? 25;
        _avatarZoom = (data['profileZoom'] as num?)?.toDouble() ?? 1;
        _avatarPanX = (data['profilePanX'] as num?)?.toDouble() ?? 0;
        _avatarPanY = (data['profilePanY'] as num?)?.toDouble() ?? 0;
        final name = data['displayName'] as String? ?? '';
        _avatarLetter = name.trim().isEmpty
            ? 'H'
            : name.trim()[0].toUpperCase();
      });
    } catch (_) {}
  }

  Future<void> _pickImage({required ImageSource source}) async {
    if (_anonymous) {
      _showMessage(AppStrings.tr('Kép feltöltéséhez regisztráció szükséges.'));
      return;
    }
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage(AppStrings.tr('A kép legfeljebb 5 MB lehet.'));
      return;
    }
    if (mounted) setState(() => _image = bytes);
  }

  Future<void> _send() async {
    if (_textController.text.trim().isEmpty && _image == null) {
      _showMessage(AppStrings.tr('Írj egy üzenetet vagy válassz képet.'));
      return;
    }
    setState(() => _sending = true);
    try {
      // Csak azok a hivatkozások mennek ki, amelyek a szövegben **tényleg
      // benne vannak** — a szerver ezt még egyszer szűri (jogosultság, korlát).
      final mentions = _activeMentions();
      final dropped = await _service.publishPost(
        text: _textController.text,
        imageBytes: _image,
        replyToText: _replyToText,
        replyToName: _replyToName,
        replyToAuthorId: _replyToAuthorId,
        mentions: mentions
            .map((target) => target.toMap())
            .toList(growable: false),
      );
      _textController.clear();
      if (mounted) {
        setState(() {
          _image = null;
          _replyToText = null;
          _replyToName = null;
          _replyToAuthorId = null;
          // A kiválasztott hivatkozások az üzenettel elmentek — a következő
          // üzenetbe nem szivárognak át.
          _mentions.clear();
          _mentionQuery = null;
          _mentionSuggestions = const <MentionSuggestion>[];
        });
      }
      if (dropped > 0) {
        // A szerver jelezte, hogy néhány hivatkozás kiesett (nem
        // admin/moderátor tartalom-hivatkozás): a szöveg olvasható maradt, de
        // a koppintás nem lesz ott — ezt röviden meg kell mondani.
        _showMessage(
          'Néhány hivatkozás nem kattintható (csak adminnak/moderátornak jár).',
        );
      }
    } catch (error) {
      _showMessage(_chatError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  void _replyTo(CommunityPost post) {
    setState(() {
      _replyToText = post.text.trim();
      _replyToName = post.authorName.trim();
      _replyToAuthorId = post.authorId.trim();
    });
    _composerFocusNode.requestFocus();
  }

  /// Az idézet megnyitása: az **eredeti üzenet teljes szövege**.
  ///
  /// ⚠️ MIÉRT (a tulajdonos jelzése, 2026-09-26): *„Chatben ha valakinek a
  /// válaszára jön válasz, akkor ha arra rákattintok, nem történik semmi."* A
  /// válasz-idézet eddig csak **3 sorig** mutatta a hivatkozott üzenetet, és nem
  /// volt koppintható. A tulajdonos két lehetőséget ajánlott: *„vagy az eredeti
  /// üzenetre ugorjon, vagy jelenítse meg az eredeti üzit teljes egészében"* —
  /// ez a dialógus a **második** utat járja, mert az **minden** esetben működik:
  /// akkor is, ha a hivatkozott üzenet nincs a betöltött ablakban (nagyon régi),
  /// és akkor is, ha az maga is egy válasz volt (a teljes szöveg látszik).
  ///
  /// ⚠️ Az ugráshoz az eredeti üzenet **azonosítója** kellene, de a tárolt
  /// idézet csak szöveget és nevet hordoz (`replyToText`/`replyToName`) — az
  /// azonosító bevezetése adatmódosítás (a régi üzeneteknél nem lenne meg),
  /// ezért az ugrás külön kör.
  Future<void> _showOriginalMessage(CommunityPost post) async {
    final text = post.replyToText.trim();
    if (text.isEmpty) return;
    final name = post.replyToName.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name.isEmpty ? AppStrings.tr('Eredeti üzenet') : name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(child: Text(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: AppText(AppStrings.tr('Bezárás')),
          ),
        ],
      ),
    );
  }

  /// A beviteli mező változott: van-e épp aktív `@`-token, és mi az.
  ///
  /// A tulajdonos kérése: *„Elkezdem irni a betűket és dobja fel a
  /// lehetőségeket."* A token felismerése a tiszta
  /// [activeMentionQuery]-ben van (a kurzor előtti `@`, egy szóközig).
  void _onComposerChanged() {
    final selection = _textController.selection;
    final caret = selection.isValid
        ? selection.baseOffset
        : _textController.text.length;
    final query = activeMentionQuery(_textController.text, caret);
    if (query == null) {
      if (_mentionQuery == null && _mentionSuggestions.isEmpty) return;
      setState(() {
        _mentionQuery = null;
        _mentionSuggestions = const <MentionSuggestion>[];
      });
      return;
    }
    _mentionCaret = caret;
    setState(() => _mentionQuery = query);
    unawaited(_refreshMentionSuggestions());
  }

  /// A javaslatok (újra)számolása az éppen aktív tokenhez.
  ///
  /// Az adat **egyszer** töltődik le ([_ensureMentionData]) — a szűrés minden
  /// további betűnél abból a cache-ből megy, hálózat nélkül.
  Future<void> _refreshMentionSuggestions() async {
    await _ensureMentionData();
    if (!mounted) return;
    final query = _mentionQuery;
    if (query == null) return;
    setState(() {
      _mentionSuggestions = mentionSuggestions(
        query: query.query,
        users: _mentionUsers ?? const <MentionSuggestion>[],
        content: _mentionContent,
        privileged: mentionPrivileged(_mentionAccessRole),
      );
    });
  }

  /// A javaslatok adatforrásának betöltése — **lustán, egyszer**.
  ///
  /// A személyek mindenkinek járnak; a tartalom **csak** adminnak/moderátornak
  /// ([mentionPrivileged]) — ez a tulajdonos döntése. A jogosultságot a
  /// **szerver** kényszeríti, ez a kapu csak UX.
  Future<void> _ensureMentionData() async {
    if (_mentionDataRequested) return;
    _mentionDataRequested = true;
    try {
      _mentionAccessRole = await _loadMentionAccessRole();
      _mentionUsers = await _mentionSource.mentionUserSuggestions();
      if (!mentionPrivileged(_mentionAccessRole)) return;
      _mentionContent = await _mentionSource.mentionContentSuggestions();
    } catch (_) {
      // A javaslatlista **soha** nem törheti el a Chatet: hiba esetén marad az
      // ami van (vagy üres lista), a beviteli mező és a küldés változatlanul
      // működik. A `@` kézzel beírva is elmegy, csak nem lesz kattintható.
      _mentionUsers ??= const <MentionSuggestion>[];
      _mentionContent = const <String, List<MentionSuggestion>>{};
    }
  }

  /// A hivatkozás-jogosultság a profilból (`accessRole`).
  ///
  /// A tulajdonos e-mail-címe a szerverhez hasonlóan **admin** akkor is, ha a
  /// profil `accessRole` mezője még nem állt be.
  Future<String?> _loadMentionAccessRole() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return CommunityService.accessNone;
    if (CommunityService.isOwnerEmail(user.email)) {
      return CommunityService.accessAdmin;
    }
    try {
      final data = (await _service.profile()).data() ?? const <String, dynamic>{};
      return data['accessRole'] as String?;
    } catch (_) {
      // Hálózati hiba: nem találgatunk — tartalom-javaslat nélkül is működik
      // a személy-hivatkozás.
      return null;
    }
  }

  /// Egy javaslat kiválasztása: a `@token` helyére a név kerül, a kurzor a név
  /// UTÁ, és a célpont bekerül a küldendő hivatkozások közé.
  ///
  /// Ugyanaz a `type:id` **nem** kerülhet be kétszer (a szerver is összevonja).
  void _selectMention(MentionSuggestion suggestion) {
    final query = _mentionQuery;
    if (query == null) return;
    final insertion = insertMention(
      text: _textController.text,
      query: query,
      caret: _mentionCaret,
      label: suggestion.label,
    );
    _textController.value = TextEditingValue(
      text: insertion.text,
      selection: TextSelection.collapsed(offset: insertion.caret),
    );
    setState(() {
      _mentionQuery = null;
      _mentionSuggestions = const <MentionSuggestion>[];
      final target = suggestion.toTarget();
      final key = '${target.type}:${target.id}';
      final already = _mentions.any(
        (item) => '${item.type}:${item.id}' == key,
      );
      if (!already) _mentions.add(target);
    });
  }

  /// A **szövegben ténylegesen benne lévő** hivatkozások (a küldéshez).
  ///
  /// ⚠️ MIÉRT nem a `_mentions` megy ki nyersen: a felhasználó visszatörölheti
  /// a `@nevet` a szövegből, ilyenkor a célpontról nem tudhatunk semmit — a
  /// tiszta [mentionSpans] adja meg, mi van valóban ott.
  List<ChatMentionTarget> _activeMentions() {
    final spans = mentionSpans(_textController.text, _mentions);
    return List<ChatMentionTarget>.unmodifiable(
      spans.map((span) => span.target),
    );
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

  /// A chat alján látszó sor: „töltés…", „ez a beszélgetés eleje", vagy egy
  /// gomb, amivel a felhasználó kérheti a régebbi üzeneteket.
  ///
  /// A lapozás görgetésre magától is elindul (`_maybeLoadOlderPosts`), ez a sor
  /// akkor is működik, ha valaki nem görget (például egérrel).
  Widget _chatPagingFooter() {
    if (_loadingOlder) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: BrandLoadingIndicator()),
      );
    }
    if (_reachedChatStart) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: AppText(
            'Ez a beszélgetés eleje.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          key: const Key('chat-load-older'),
          onPressed: () => unawaited(_loadOlderPosts()),
          child: const AppText('Régebbi üzenetek betöltése'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityPostsProvider);
    // Az értesítésből megjelölt üzenet megkeresése: az élő ablak **megérkezésekor**
    // egyszer lefut (nem minden buildben), a tényleges munka post-frame.
    ref.listen<AsyncValue<List<CommunityPost>>>(communityPostsProvider, (_, next) {
      final loaded = next.valueOrNull;
      if (loaded != null && !_focusFinished) _resolveFocus(loaded);
    });
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope<void>(
      // The IME should consume the first Android back press while typing.
      // Keep normal route popping unchanged once the keyboard is closed.
      canPop: !keyboardVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && keyboardVisible) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Chat'),
          actions: [
            // iOS-en nincs rendszer-vissza gomb, amivel a billentyűzetet be
            // lehetne zárni — ezért itt van a fejlécben (csak nyitott
            // billentyűzetnél látszik).
            const KeyboardDismissButton(),
            IconButton(
              tooltip: tr(context, 'Privát üzenetek'),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivateMessagesScreen(),
                ),
              ),
              icon: const Icon(Icons.mail_outline_rounded),
            ),
            IconButton(
              onPressed: _openProfile,
              icon: _anonymous
                  ? const ProfileAvatar(imageUrl: '', initial: 'H', size: 36)
                  : ProfileAvatar(
                      imageUrl: _avatarUrl,
                      initial: _avatarLetter,
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            // A keyboard opening reduces the available height.  Deriving the
            // orientation from the LayoutBuilder constraints therefore flips a
            // portrait phone into the landscape branch while typing, which
            // moves the composer and drops its focus.  Use the device
            // orientation instead; it remains stable while insets change.
            final landscape =
                MediaQuery.orientationOf(context) == Orientation.landscape;
            final composer = _Composer(
              controller: _textController,
              focusNode: _composerFocusNode,
              image: _image,
              anonymous: _anonymous,
              sending: _sending,
              onTakePhoto: () => _pickImage(source: ImageSource.camera),
              onPickGallery: () => _pickImage(source: ImageSource.gallery),
              onSend: _send,
              onRemoveImage: () => setState(() => _image = null),
              replyToText: _replyToText,
              replyToName: _replyToName,
              onClearReply: () => setState(() {
                _replyToText = null;
                _replyToName = null;
                _replyToAuthorId = null;
              }),
              suggestions: _mentionSuggestions,
              onSuggestionTap: _selectMention,
            );
            final postList = Expanded(
              child: posts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'A Chat nem érhető el.\\n${_chatError(error)}',
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(child: AppText('Még nincs bejegyzés.'))
                    : RefreshIndicator(
                        onRefresh: _refreshChat,
                        child: ListView.builder(
                          controller: _chatScrollController,
                          // A lista húzásával is eltűnjön a billentyűzet
                          // (iOS-en ez a megszokott gesztus).
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          // A végére kerül a „töltés"/„ez a beszélgetés eleje"
                          // sor, ezért +1.
                          itemCount: items.length + _olderPosts.length + 1,
                          itemBuilder: (_, index) {
                            if (index < items.length) {
                              return _withFocusHighlight(
                                _PostCard(
                                  post: items[index],
                                  compact: !landscape,
                                  profileRefreshGeneration:
                                      _profileRefreshGeneration,
                                  onReply: () => _replyTo(items[index]),
                                  onOpenReply: () =>
                                      _showOriginalMessage(items[index]),
                                ),
                                items[index].id,
                              );
                            }
                            final olderIndex = index - items.length;
                            if (olderIndex < _olderPosts.length) {
                              final post = _olderPosts[olderIndex];
                              return _withFocusHighlight(
                                _PostCard(
                                  post: post,
                                  compact: !landscape,
                                  profileRefreshGeneration:
                                      _profileRefreshGeneration,
                                  onReply: () => _replyTo(post),
                                  onOpenReply: () => _showOriginalMessage(post),
                                ),
                                post.id,
                              );
                            }
                            return _chatPagingFooter();
                          },
                        ),
                      ),
              ),
            );
            return Flex(
              direction: landscape ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (landscape)
                  SizedBox(
                    width: constraints.maxWidth < 700
                        ? 240
                        : constraints.maxWidth < 1000
                        ? 280
                        : 360,
                    child: composer,
                  )
                else
                  composer,
                postList,
              ],
            );
          },
        ),
        // Ha valaki mélyen visszagörgetett a régebbi üzenetek között, egy
        // koppintással visszakerül a legfrissebbhez (nem kell visszatekerni).
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _showJumpToNewest,
          builder: (context, show, _) => show
              ? FloatingActionButton.small(
                  key: const Key('chat-jump-newest'),
                  tooltip: tr(context, 'Ugrás a legfrissebb üzenethez'),
                  onPressed: _jumpToNewest,
                  child: const Icon(Icons.arrow_upward_rounded),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Uint8List? image;
  final bool anonymous;
  final bool sending;
  final String? replyToText;
  final String? replyToName;
  final VoidCallback onClearReply;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onSend;
  final VoidCallback onRemoveImage;

  /// Az éppen látszó `@`javaslatok (üresen a lista **semmit** nem rajzol).
  final List<MentionSuggestion> suggestions;

  /// Egy javaslat kiválasztása (a szövegbeszúrás a képernyő dolga).
  final ValueChanged<MentionSuggestion> onSuggestionTap;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.image,
    required this.anonymous,
    required this.sending,
    required this.replyToText,
    required this.replyToName,
    required this.onClearReply,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onSend,
    required this.onRemoveImage,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (replyToText?.isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(
                    replyToName?.isNotEmpty == true
                        ? 'Válasz $replyToName üzenetére: $replyToText'
                        : 'Válasz erre: $replyToText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: onClearReply,
                ),
              ),
            // A javaslatlista a beviteli sor **fölött**: így nem takarja a
            // gépelt szöveget, és a válasz- illetve kép-előnézet helyén sem
            // változtat. Üresen ez a widget semmit nem rajzol.
            ChatMentionOverlay(
              suggestions: suggestions,
              onSelected: onSuggestionTap,
            ),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: const [SentenceCapitalizationFormatter()],
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: tr(context, 'Írj valamit a közösségnek…'),
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
                  tooltip: tr(context, 'Kamera'),
                  onPressed: onTakePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr(context, 'Kép kiválasztása'),
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                // ⚠️ iOS-en a rendszerbillentyűzeten NINCS emoji-kulcs (Androidon
                // van), ezért itt kap egy gombot — Androidon ez a widget semmit
                // nem rajzol (lásd `chat_emoji_button.dart`).
                ChatEmojiButton(controller: controller, focusNode: focusNode),
                // ⚠️ A fejléc gombja MESSZE van attól, ahova írás közben nézünk
                // (a tulajdonos jelzése szerint „nincs" — pedig ott volt).
                // Ezért ugyanaz a widget itt is ott van, közvetlenül a Küldés
                // fölött; zárva magától eltűnik, így nem foglal helyet.
                const Spacer(),
                const KeyboardDismissButton(),
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
                label: const AppText('Küldés'),
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
  final bool compact;
  final int profileRefreshGeneration;
  final VoidCallback onReply;

  /// Az **idézet** megnyitása (a hivatkozott üzenet teljes szövege).
  ///
  /// ⚠️ A tulajdonos jelzése (2026-09-26): *„Chatben ha valakinek a válaszára
  /// jön válasz, akkor ha arra rákattintok, nem történik semmi."* Az idézet
  /// eddig egy **koppintás nélküli** `Container` volt — mostantól megnyitja az
  /// eredeti (teljes) üzenetet.
  final VoidCallback? onOpenReply;
  const _PostCard({
    required this.post,
    required this.compact,
    required this.profileRefreshGeneration,
    required this.onReply,
    this.onOpenReply,
  });

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  /// A helyi (optimista) reakció, amíg a Firestore-kép meg nem erősíti.
  ///
  /// MIÉRT kell: a `toggleChatReaction` egy Firebase callable, hideg
  /// indulásnál **1–3 s** (Cloud Function + WordPress kör). A koppintásnak
  /// viszont **azonnal** látszania kell — ezért a helyi állapot előbb íródik,
  /// és a szerver csak utána igazol. A minta a privát üzenet szíve
  /// (`private_messages_screen.dart` `_toggleHeart`: helyi felülírás +
  /// `setState` a `await` ELŐTT, hiba esetén visszaállás + SnackBar).
  bool _optimisticActive = false;
  String _optimisticReaction = '';

  /// Busy-kapu: ugyanarra az üzenetre nem indulhat két párhuzamos
  /// `toggleReaction`. Enélkül a gyors koppintások két callable-t indítanának,
  /// és a lassabb válasz felülírná a gyorsabbat (a szerveroldali toggle
  /// kiszámíthatatlan sorrendben írna).
  bool _reactionBusy = false;

  /// A saját reakcióm a szerver-kép szerint (üres, ha nincs / nem vagyok be).
  String get _snapshotReaction {
    final uid = ref.watch(communityAuthProvider).valueOrNull?.uid;
    return widget.post.myReaction(uid);
  }

  /// A darabszám helyi korrekciója (delta) a szerver-képhez képest.
  ///
  /// MIÉRT: a `post.reactions[emoji]` a Firestore-képből jön, az pedig csak a
  /// szerveroldali írás (1–3 s) után érkezik meg — a szám enélkül másodpercekig
  /// a régit mutatná. Ez pontosan ugyanaz a delta-minta, mint a privát üzenet
  /// szívénél (`heartCount + (liked == currentLiked ? 0 : liked ? 1 : -1)`).
  ///
  /// A delta **magától eltűnik**, amint a kép beéri az optimista értéket
  /// (`didUpdateWidget`), ezért nem tud tartósan hazudni; emoji-váltásnál pedig
  /// a régi emojinál −1, az újnál +1 lesz.
  int _reactionDelta(String emoji) {
    final before = _snapshotReaction;
    final after = _optimisticActive ? _optimisticReaction : _snapshotReaction;
    if (before == after) return 0;
    var delta = 0;
    if (before == emoji) delta -= 1;
    if (after == emoji) delta += 1;
    return delta;
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Beért a kép: az optimista érték már felesleges (a szerver az úr), így a
    // delta is 0-ra esik vissza.
    if (_optimisticActive && _snapshotReaction == _optimisticReaction) {
      _optimisticActive = false;
    }
  }

  Future<void> _react(String emoji) async {
    if (_reactionBusy) return;
    final previousActive = _optimisticActive;
    final previousReaction = _optimisticReaction;
    // A koppintás pillanatában látható állapot: ha van helyi érték, az az úr,
    // különben a szerver-kép. Ugyanarra az emojira koppintva visszavonjuk.
    final current = previousActive ? previousReaction : _snapshotReaction;
    final optimistic = current == emoji ? '' : emoji;
    // Optimista írás még a szolgáltatás-hívás előtt: a chip és a darabszám
    // azonnal mozdul, nem a callable visszaérkezésére vár.
    setState(() {
      _reactionBusy = true;
      _optimisticActive = true;
      _optimisticReaction = optimistic;
    });
    try {
      final selected = await ref
          .read(communityServiceProvider)
          .toggleReaction(postId: widget.post.id, emoji: emoji);
      if (!mounted) return;
      // A szerver válasza az igazság (nem tipp) — pontosan ezt fogja hozni a
      // következő Firestore-kép is.
      setState(() {
        _optimisticActive = true;
        _optimisticReaction = selected;
      });
    } catch (error) {
      if (!mounted) return;
      // Hiba: visszaállunk a koppintás előtti állapotra ÉS szólunk — a korábbi
      // néma hibaelnyelés elrejtette a hibát a felhasználó elől.
      setState(() {
        _optimisticActive = previousActive;
        _optimisticReaction = previousReaction;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    } finally {
      if (mounted) setState(() => _reactionBusy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Üzenet törlése'),
        content: const AppText('Biztosan törlöd ezt a Chat-üzenetet?'),
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(communityServiceProvider).deletePost(widget.post.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _edit() async {
    var editedText = widget.post.text;
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Üzenet szerkesztése'),
        content: TextFormField(
          initialValue: editedText,
          autofocus: true,
          maxLines: 5,
          onChanged: (value) => editedText = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedText),
            child: const AppText('Mentés'),
          ),
        ],
      ),
    );
    if (updated == null || !mounted) return;
    try {
      await ref
          .read(communityServiceProvider)
          .updatePostText(
            postId: widget.post.id,
            text: updated,
            // A szerzo-ellenorzeshez: admin barkit, a szerzo csak a sajatjat.
            authorId: widget.post.authorId,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _togglePinned() async {
    try {
      await ref
          .read(communityServiceProvider)
          .setPostPinned(widget.post.id, !widget.post.pinned);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
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
                ? AppStrings.tr('Jelentés elküldve.')
                : AppStrings.tr('Felhasználó blokkolva.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_chatError(error))));
    }
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        await _edit();
      case 'delete':
        await _delete();
      case 'pin':
        await _togglePinned();
      case 'report':
      case 'block':
        await _moderateUser(action);
    }
  }

  Future<void> _openAuthorProfile() async {
    if (widget.post.authorId.isEmpty ||
        widget.post.authorName.startsWith('Unknown User ')) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CommunityPublicProfileScreen(userId: widget.post.authorId),
      ),
    );
  }

  /// Egy `@`hivatkozás koppintása → a **közös** célpont-feloldó.
  ///
  /// ⚠️ MIÉRT közös (`openContentTarget`): az értesítés-központ ugyanezt hívja,
  /// így a hivatkozás és az értesítés **nem tud széthúzni** (a 351-es tanulság).
  Future<void> _openMention(ChatMentionTarget target) async {
    // A `@mindenki` **nem adatlap**: nincs hova navigálni (az értesítést a
    // szerver küldi mindenkinek). A szövegben kiemelve látszik, de nem
    // kattintható — ez itt csak biztonsági háló, hogy semmilyen úton ne
    // induljon el a feloldás és ne villanjon fel a „nem elérhető" üzenet.
    if (target.type == mentionTypeEveryone) return;
    final opened = await openContentTarget(
      Navigator.of(context),
      targetType: target.type,
      targetId: target.id,
    );
    if (opened || !mounted) return;
    // Eltűnt célpont (törölt cikk/DJ) vagy hálózati hiba: szólunk, nem
    // omlunk össze — a hivatkozás nem tudja magát megjavítani.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: AppText('A hivatkozott tartalom nem érhető el.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final service = ref.read(communityServiceProvider);
    final currentUser = service.auth.currentUser;
    final isRegisteredUser = currentUser != null && !currentUser.isAnonymous;
    // A tulajdonos keresere: „a chaten a felhasználó tudja szerkeszteni a saját
    // üzenetét … Admin természetesen mindenkiét, + admin törölni is tudjon".
    //
    //  - SZERKESZTÉS: a szerző a sajátját, admin bárkiét;
    //  - TÖRLÉS:     csak admin (a szerző nem törölheti a sajátját sem);
    //  - RÖGZÍTÉS:   csak admin.
    final isOwnPost =
        isRegisteredUser &&
        post.authorId.isNotEmpty &&
        post.authorId == currentUser.uid;
    final canEditPost = isRegisteredUser && (service.isAdmin || isOwnPost);
    final canDeletePost = isRegisteredUser && service.isAdmin;
    final canPinPost = isRegisteredUser && service.isAdmin;
    final canModeratePosts = canEditPost || canDeletePost || canPinPost;
    final canReportOrBlock =
        isRegisteredUser &&
        post.authorId.isNotEmpty &&
        post.authorId != currentUser.uid;
    final canOpenProfile =
        post.authorId.isNotEmpty &&
        !post.authorName.startsWith(tr(context, 'Unknown User '));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canOpenProfile ? _openAuthorProfile : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  _PostAuthorAvatar(post, compact: widget.compact),
                  SizedBox(width: widget.compact ? 7 : 9),
                  Expanded(
                    child: _PostAuthorLabels(
                      post: post,
                      service: ref.read(communityServiceProvider),
                      refreshGeneration: widget.profileRefreshGeneration,
                    ),
                  ),
                  Text(
                    _timeLabel(post.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  // A szerkesztes jelzese: a tulajdonos keresere a felhasznalo
                  // szerkesztheti a sajat uzenetet, ezert latszania kell, hogy
                  // a szoveg mar nem az eredeti.
                  if (post.editedAt != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        'szerkesztve',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (canModeratePosts || canReportOrBlock)
                    PopupMenuButton<String>(
                      tooltip: tr(context, 'Üzenetműveletek'),
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => [
                        if (canEditPost)
                          const PopupMenuItem(
                            value: 'edit',
                            child: AppText('Szerkesztés'),
                          ),
                        if (canDeletePost)
                          const PopupMenuItem(
                            value: 'delete',
                            child: AppText('Törlés'),
                          ),
                        if (canPinPost)
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(
                              post.pinned
                                  ? tr(context, 'Rögzítés feloldása')
                                  : tr(context, 'Üzenet rögzítése'),
                            ),
                          ),
                        if (canReportOrBlock) ...[
                          const PopupMenuItem(
                            value: 'report',
                            child: AppText('Jelentés'),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: AppText('Blokkolás'),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            if (post.pinned)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: AppText(
                  'Rögzített üzenet',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            if (post.text.isNotEmpty) ...[
              SizedBox(height: widget.compact ? 7 : 10),
              // A `@`hivatkozások **kattinthatók** — a tárolt célpontok
              // (`mentions`) alapján, nem szöveg-parse-szal. Hivatkozás nélkül
              // ez bitre ugyanaz, mint a korábbi sima szöveg-megjelenítés.
              ChatMessageText(
                text: post.text,
                mentions: post.mentions,
                onTap: _openMention,
              ),
            ],
            if (post.imageUrl.isNotEmpty) ...[
              SizedBox(height: widget.compact ? 7 : 10),
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          minScale: .8,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: post.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            tooltip: tr(context, 'Bezárás'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 720,
                    maxWidthDiskCache: 720,
                  ),
                ),
              ),
            ],
            SizedBox(height: widget.compact ? 3 : 6),
            if (widget.post.replyToText.isNotEmpty)
              // ⚠️ Koppintható idézet: megnyitja az eredeti üzenetet TELJES
              // egészében (a tulajdonos kérése). Az `InkWell` a kártya stílusát
              // követi, ezért nem kell külön gomb.
              InkWell(
                onTap: widget.onOpenReply,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (widget.post.replyToName.isNotEmpty) ...[
                          TextSpan(
                            text: widget.post.replyToName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: tr(context, ' üzenetére: ')),
                        ] else
                          TextSpan(text: tr(context, 'Válasz: ')),
                        TextSpan(text: widget.post.replyToText),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: widget.compact ? 0 : 6,
              children: [
                ActionChip(
                  visualDensity: widget.compact ? VisualDensity.compact : null,
                  avatar: const Icon(Icons.reply, size: 16),
                  label: const AppText('Válasz'),
                  onPressed: widget.onReply,
                ),
                ...['❤️', '🔥', '🙌'].map((emoji) {
                  // A szerver-kép + a helyi delta: a szám a koppintásra azonnal
                  // mozdul, a képre nem vár (lásd `_reactionDelta`).
                  final count =
                      (post.reactions[emoji] ?? 0) + _reactionDelta(emoji);
                  final safeCount = count < 0 ? 0 : count;
                  // A SAJÁT reakció egyértelmű jelzése — **név nélkül**.
                  final isMine =
                      (_optimisticActive
                          ? _optimisticReaction
                          : _snapshotReaction) ==
                      emoji;
                  final scheme = Theme.of(context).colorScheme;
                  return ActionChip(
                    visualDensity: widget.compact
                        ? VisualDensity.compact
                        : null,
                    avatar: isMine
                        ? Icon(
                            Icons.check_circle,
                            size: 16,
                            color: scheme.primary,
                          )
                        : null,
                    label: Text(
                      '$emoji${safeCount > 0 ? ' $safeCount' : ''}',
                      style: isMine
                          ? TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            )
                          : null,
                    ),
                    backgroundColor: isMine ? scheme.primaryContainer : null,
                    side: isMine ? BorderSide(color: scheme.primary) : null,
                    tooltip: isMine ? 'Te reagáltál erre' : null,
                    onPressed: () => _react(emoji),
                  );
                }),
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

class _PostAuthorLabels extends StatefulWidget {
  final CommunityPost post;
  final CommunityService service;
  final int refreshGeneration;

  const _PostAuthorLabels({
    required this.post,
    required this.service,
    required this.refreshGeneration,
  });

  @override
  State<_PostAuthorLabels> createState() => _PostAuthorLabelsState();
}

class _PostAuthorLabelsState extends State<_PostAuthorLabels> {
  Stream<Map<String, dynamic>>? _profileStream;
  Future<AchievementSummary>? _achievementFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.post.isAnonymous) _loadAuthor(widget.post.authorId);
  }

  @override
  void didUpdateWidget(covariant _PostAuthorLabels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.authorId != widget.post.authorId ||
        oldWidget.post.isAnonymous != widget.post.isAnonymous) {
      _loadAuthor(widget.post.authorId);
    } else if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      // The live feed periodically invalidates public profile caches. Force
      // this row to fetch the current badge/rank after that invalidation;
      // otherwise its stable Future could keep the previous rank visible.
      _loadAuthor(widget.post.authorId);
    }
  }

  void _loadAuthor(String authorId) {
    if (widget.post.isAnonymous || authorId.trim().isEmpty) {
      _profileStream = null;
      _achievementFuture = null;
      return;
    }
    // Keep one stable Future for this row. CommunityService still owns the
    // shared UID cache and in-flight deduplication across all rows/screens.
    _profileStream = widget.service.watchPublicProfile(authorId);
    // The profile response normally contains the current public badge. Keep
    // the fallback lazy so every chat row does not create a second callable.
    _achievementFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ChatDisplayPreferences.achievementInChat,
      builder: (context, showAchievement, child) {
        return _buildLabels(showAchievement);
      },
    );
  }

  Widget _buildLabels(bool showAchievement) {
    final post = widget.post;
    if (post.isAnonymous) {
      return _labels(
        post.authorRole,
        post.authorAccessRole,
        AchievementSummary.empty,
        false,
        post.authorName,
      );
    }
    if (post.authorId.isEmpty || _profileStream == null) {
      return _labels(
        post.authorRole,
        post.authorAccessRole,
        AchievementSummary.empty,
        showAchievement,
        post.authorName,
      );
    }
    return StreamBuilder<Map<String, dynamic>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final localAchievement = data == null
            ? AchievementSummary.empty
            : AchievementSummary.fromProfile(data);
        final role = data?['role'] as String? ?? post.authorRole;
        final accessRole =
            data?['accessRole'] as String? ?? CommunityService.accessNone;
        final profileName = (data?['displayName'] as String?)?.trim();
        final userNumber = data?['huhsUserNumber'];
        final numberedName = userNumber is num
            ? 'HUHS user ${userNumber.toInt()}'
            : '';
        final displayName =
            profileName?.isNotEmpty == true && profileName != 'HUHS user'
            ? profileName!
            : numberedName.isNotEmpty
            ? numberedName
            : post.authorName.trim().isNotEmpty
            ? post.authorName.trim()
            : tr(context, 'HUHS user');
        final badgeData = data?['achievementBadge'];
        final hasAchievementData =
            badgeData is Map &&
            (badgeData['name'] as String? ?? '').trim().isNotEmpty &&
            (badgeData['slug'] as String? ?? '').trim().isNotEmpty &&
            (badgeData['imageUrl'] as String? ?? '').trim().isNotEmpty;
        if (showAchievement &&
            (snapshot.hasError || data != null) &&
            !hasAchievementData &&
            _achievementFuture == null) {
          _achievementFuture = widget.service.getPublicAchievement(
            post.authorId,
            forceRefresh: snapshot.hasError,
          );
        }
        return FutureBuilder<AchievementSummary>(
          future: showAchievement && _achievementFuture != null
              ? _achievementFuture
              : null,
          initialData: localAchievement,
          builder: (context, achievementSnapshot) {
            final fallback = achievementSnapshot.data;
            final achievement =
                fallback == null ||
                    (fallback.badgeImageUrl.isEmpty &&
                        localAchievement.badgeImageUrl.isNotEmpty)
                ? localAchievement
                : fallback;
            return _labels(
              role,
              accessRole,
              achievement,
              showAchievement,
              displayName,
            );
          },
        );
      },
    );
  }

  Widget _labels(
    String role,
    String accessRole,
    AchievementSummary achievement,
    bool showAchievement,
    String displayName,
  ) {
    final roleLabel = role == 'dj'
        ? 'DJ'
        : role == 'organizer'
        ? tr(context, 'Szervező')
        : role.isNotEmpty
        ? tr(context, 'Bulizó')
        : '';
    final accessLabel = accessRole == CommunityService.accessAdmin
        ? tr(context, 'Admin')
        : accessRole == CommunityService.accessModerator
        ? tr(context, 'Moderátor')
        : '';

    final badgeImage = achievement.badgeImageUrl.trim();
    return Text.rich(
      TextSpan(
        children: [
          if (showAchievement)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: badgeImage.isEmpty
                    ? const Icon(
                        Icons.workspace_premium_outlined,
                        size: 14,
                        color: Colors.amberAccent,
                      )
                    : ClipOval(
                        child: CachedNetworkImage(
                          // Keep the original badge URL: do not trade image
                          // quality for a thumbnail in any chat surface.
                          imageUrl: badgeImage,
                          width: 18,
                          height: 18,
                          fit: BoxFit.cover,
                          memCacheWidth: 54,
                          errorWidget: (_, _, error) {
                            return const Icon(
                              Icons.workspace_premium_outlined,
                              size: 14,
                              color: Colors.amberAccent,
                            );
                          },
                        ),
                      ),
              ),
            ),
          if (showAchievement)
            TextSpan(
              // ⚠️ A jelvény-név a SZERVERRŐL jön (magyarul), ezért a
              // megjelenítés helyén fordítjuk — enélkül angol módban magyar
              // jelvénynév maradt volna a közösségi lista soraiban.
              text: '${tr(context, achievement.badgeName)} • ',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          TextSpan(
            text: displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (roleLabel.isNotEmpty)
            TextSpan(
              text: ' • $roleLabel',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          if (accessLabel.isNotEmpty)
            TextSpan(
              text: ' • $accessLabel',
              style: TextStyle(
                color: accessRole == CommunityService.accessAdmin
                    ? Colors.redAccent
                    : Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class CommunityProfileScreen extends ConsumerStatefulWidget {
  final bool editing;
  final VoidCallback? onProfileDeleted;

  const CommunityProfileScreen({
    super.key,
    this.editing = false,
    this.onProfileDeleted,
  });

  @override
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends ConsumerState<CommunityProfileScreen>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _referralCode = TextEditingController();
  final _profileDraft = CommunityProfileTextDraft();
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
  AchievementSummary _achievement = AchievementSummary.empty;
  String? _loadedUid;
  bool _loadingProfile = false;
  String? _profileError;
  String? _profileDataUid;
  bool _roleMissing = false;
  bool _applyingProfileData = false;
  final Set<String> _dirtyFields = <String>{};
  String? _formUid;
  String _savedProfileName = '';
  DateTime? _memberSince;
  int _profileSaveAttempt = 0;
  Future<void>? _profileLoadRequest;
  int _usernameChangesUsed = 0;
  int _emailChangesUsed = 0;
  StreamSubscription<User?>? _authSubscription;
  Timer? _nameAvailabilityTimer;
  String? _registrationNameError;

  CommunityService get _service => ref.read(communityServiceProvider);
  TextEditingController get _name => _profileDraft.name;
  TextEditingController get _bio => _profileDraft.bio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _formUid = _service.auth.currentUser?.uid;
    _profileDraft.bindUid(_formUid);
    for (final entry in _social.entries) {
      entry.value.addListener(() => _markFieldEdited(entry.key));
    }
    _authSubscription = _service.auth.userChanges().listen((user) {
      if (!mounted) return;
      final nextUid = user?.uid;
      final uidChanged = _formUid != nextUid;
      if (uidChanged) {
        final keepUnboundFieldEdits =
            _formUid == null && nextUid != null && _dirtyFields.isNotEmpty;
        setState(() {
          _formUid = nextUid;
          _loadedUid = null;
          _profileDataUid = null;
          if (!keepUnboundFieldEdits) _dirtyFields.clear();
          _profileDraft.bindUid(nextUid);
        });
        unawaited(_loadProfile());
        return;
      }
      // updateDisplayName()/reload() emit the same user.  Reloading the
      // profile here used to replace the active editor with a loading view.
      // The editor already owns its draft; repaint Auth-derived hints only.
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
    unawaited(_refreshVerificationStatus());
    _loadPendingReferralCode();
  }

  Future<void> _loadPendingReferralCode() async {
    final code = await ReferralLinkService.pendingCode();
    if (!mounted || code == null || _referralCode.text.isNotEmpty) return;
    setState(() => _referralCode.text = code);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _nameAvailabilityTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    _referralCode.dispose();
    _profileDraft.dispose();
    for (final controller in _social.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshVerificationStatus());
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final result = await _service.refreshCurrentSession();
    if (!mounted || _service.auth.currentUser?.uid != user.uid) return;
    if (result['emailVerifiedChanged'] == true) {
      _message(AppStrings.tr('Az e-mail-címed megerősítve.'));
    }
    setState(() {});
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
      _message(AppStrings.tr('Töltsd ki a mezőket; a jelszó legalább 6 karakter legyen.'));
      return;
    }
    if (_register &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      _message(AppStrings.tr('Adj meg érvényes e-mail-címet.'));
      return;
    }
    if (_register && _password.text != _passwordConfirmation.text) {
      _message(AppStrings.tr('A két jelszó nem egyezik.'));
      return;
    }
    if (_register) {
      try {
        await _service.checkDisplayNameAvailability(_name.text);
      } catch (error) {
        if (mounted) {
          setState(
            () => _registrationNameError = _registrationNameMessage(error),
          );
        }
        return;
      }
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
        if (_referralCode.text.trim().isNotEmpty) {
          // A bad/expired code must never turn a successful registration into
          // a false registration error.
          try {
            final claimed = await _service.claimReferralCode(
              _referralCode.text,
            );
            if (claimed) await ReferralLinkService.clearPendingCode();
          } catch (_) {
            // The account was created; the referral can simply be omitted.
          }
        }
        // Keep the newly created account signed in while it is unverified. The
        // profile shows the verification warning and resend action, so signing
        // out here only makes a successful registration look like a failure.
        _message(
          AppStrings.tr('Megerősítő e-mailt küldtünk. A profil használatához erősítsd meg a címedet.'),
        );
      } else {
        await _service.signIn(email: _email.text, password: _password.text);
        if (_service.auth.currentUser?.emailVerified != true && mounted) {
          _message(
            AppStrings.tr('Erősítsd meg az e-mail-címedet. A profilban újra elküldheted a levelet.'),
          );
        }
      }
      _loadedUid = null;
      await _loadProfile(force: true);
      if (mounted) setState(() {});
    } catch (error) {
      if (_register && _registrationNameMessage(error) != null && mounted) {
        setState(
          () => _registrationNameError = _registrationNameMessage(error),
        );
      }
      _message(_chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _registrationNameMessage(Object error) {
    final message = _chatError(error).toLowerCase();
    return message.contains('felhasználónév már foglalt') ||
            message.contains('display-name-already-in-use')
        ? AppStrings.tr('Ez a felhasználónév már foglalt. Válassz másikat.')
        : null;
  }

  void _checkRegistrationName(String value) {
    _nameAvailabilityTimer?.cancel();
    if (!_register) return;
    setState(() => _registrationNameError = null);
    final candidate = value.trim();
    if (candidate.length < 2) return;
    _nameAvailabilityTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        await _service.checkDisplayNameAvailability(candidate);
      } catch (error) {
        final message = _registrationNameMessage(error);
        if (mounted && _name.text.trim() == candidate && message != null) {
          setState(() => _registrationNameError = message);
        }
      }
    });
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (force) {
      final running = _profileLoadRequest;
      if (running != null) await running;
      _loadedUid = null;
    } else if (_profileLoadRequest != null) {
      return _profileLoadRequest!;
    }
    final request = _loadProfileInternal(forceServer: force);
    _profileLoadRequest = request;
    try {
      await request;
    } finally {
      if (identical(_profileLoadRequest, request)) _profileLoadRequest = null;
    }
  }

  Future<void> _loadProfileInternal({bool forceServer = false}) async {
    if (_loadingProfile) return;
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous || _loadedUid == user.uid) return;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      if (!await _unlockProfile(user)) {
        throw StateError('Profile unlock cancelled');
      }
      // Paint the profile as soon as the local Firestore snapshot is ready.
      // Claimed artists are unrelated and must not hold the first paint.
      final snapshot = await _service.profile(forceServer: forceServer);
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (!mounted || _service.auth.currentUser?.uid != user.uid) return;
      setState(() {
        _applyProfileData(data, user);
        _loadedUid = user.uid;
        _profileDataUid = user.uid;
      });
      unawaited(_refreshOwnProfileAfterPaint(user.uid));
      // ⚠️ A claimelt DJ-adatlapok **a mentett válaszból azonnal** jönnek (a
      // bejelentkezés utáni előtöltés ezt is melegíti), és a szerver a
      // háttérben egyeztet — eddig minden profilnyitásnál külön callable körút
      // futott, ezért a jelzés csak később jelent meg.
      final claimed = ref.read(claimedArtistsOfUserProvider(user.uid));
      final claimedNow = claimed.valueOrNull;
      if (claimedNow != null && claimedNow.isNotEmpty) {
        setState(() => _claimedArtistIds = claimedNow);
      }
      unawaited(
        ref
            .read(claimedArtistsOfUserProvider(user.uid).future)
            .then((claimedArtistIds) {
              if (mounted && _service.auth.currentUser?.uid == user.uid) {
                setState(() => _claimedArtistIds = claimedArtistIds);
              }
            })
            .catchError((_) {}),
      );
      unawaited(_refreshOwnAchievementInBackground(user.uid));
    } catch (_) {
      if (mounted && _service.auth.currentUser?.uid == user.uid) {
        setState(
          () =>
              _profileError = 'A profil betöltése nem sikerült. Próbáld újra.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _applyProfileData(Map<String, dynamic> data, User user) {
    final storedName = (data['displayName'] as String? ?? '').trim();
    final newUid = _formUid != user.uid;
    if (newUid) _dirtyFields.clear();
    _applyingProfileData = true;
    try {
      _profileDraft.hydrate(
        uid: user.uid,
        nameValue: storedName,
        bioValue: data['bio'] as String? ?? '',
      );
      _roleMissing = !const {
        'dj',
        'organizer',
        'partygoer',
      }.contains(data['role']);
      _loadSocialValues(data['socialLinks']);
    } finally {
      _applyingProfileData = false;
    }
    _formUid = user.uid;
    _savedProfileName = storedName;
    final createdAt = data['createdAt'];
    _memberSince = createdAt is Timestamp ? createdAt.toDate() : null;
    _profileImageUrl = _service.resolveProfileImage(data);
    _focusX = (data['profileFocusX'] as num?)?.toDouble() ?? 50;
    _focusY = (data['profileFocusY'] as num?)?.toDouble() ?? 25;
    _zoom = (data['profileZoom'] as num?)?.toDouble() ?? 1;
    _panX = (data['profilePanX'] as num?)?.toDouble() ?? 0;
    _panY = (data['profilePanY'] as num?)?.toDouble() ?? 0;
    _role = _service.isOwner
        ? 'organizer'
        : _service.accountRole(data['role'] as String?);
    _achievement = AchievementSummary.fromProfile(data);
    final currentYear = DateTime.now().year;
    _usernameChangesUsed =
        !_service.isOwner &&
            ((data['usernameChangeCount'] as num?)?.toInt() ?? 0) > 0 &&
            (data['usernameChangeYear'] as num?)?.toInt() == currentYear
        ? 1
        : 0;
    _emailChangesUsed =
        !_service.isOwner &&
            ((data['emailChangeCount'] as num?)?.toInt() ?? 0) > 0 &&
            (data['emailChangeYear'] as num?)?.toInt() == currentYear
        ? 1
        : 0;
  }

  void _markFieldEdited(String field) {
    if (!_applyingProfileData) _dirtyFields.add(field);
  }

  void _setFormValue(
    String field,
    TextEditingController controller,
    String value,
  ) {
    if (_dirtyFields.contains(field)) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _refreshOwnProfileAfterPaint(String uid) async {
    try {
      final snapshot = await _service.refreshOwnProfile();
      final user = _service.auth.currentUser;
      if (!mounted || user == null || user.uid != uid) return;
      // Cache-first refreshes are display data, never editor input. A delayed
      // server snapshot must wait until the user saves or discards this draft.
      if (_profileDraft.hasUnsavedEdits || _dirtyFields.isNotEmpty) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      setState(() => _applyProfileData(data, user));
    } catch (_) {
      // The cached profile remains visible when the network is unavailable.
    }
  }

  Future<void> _refreshOwnAchievementInBackground(String uid) async {
    try {
      await _service.refreshMyAchievementBadge();
      final snapshot = await _service.profile();
      if (!mounted || _service.auth.currentUser?.uid != uid) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      setState(() => _achievement = AchievementSummary.fromProfile(data));
    } catch (_) {
      // The already-rendered profile remains usable if recalculation is
      // temporarily unavailable.
    }
  }

  Future<bool> _unlockProfile(User user) async {
    final passwordAccount = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    final biometric = await _service.biometricEnabled();
    final deviceCode = await _service.deviceCodeEnabled();
    final authenticator =
        passwordAccount && await _service.authenticatorEnabled();
    if (!biometric && !deviceCode && !authenticator) return true;
    return _service.unlockProfileSession(user.uid, () async {
      if (biometric && !await _service.authenticateBiometric()) return false;
      if (!biometric &&
          deviceCode &&
          !await _service.authenticateDeviceCode()) {
        return false;
      }
      if (authenticator) {
        if (!mounted) return false;
        final controller = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const AppText('Authenticator-kód'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, '6 számjegyű kód')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const AppText('Mégse'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const AppText('Feloldás'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (code == null || !await _service.verifyAuthenticatorCode(code)) {
          if (mounted) _message(AppStrings.tr('Az authenticator-kód hibás.'));
          return false;
        }
      }
      return true;
    });
  }

  Future<void> _saveProfile() async {
    final user = _service.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    setState(() => _busy = true);
    final attempt = ++_profileSaveAttempt;
    try {
      final uploadedImage = _profileImage == null
          ? null
          : await _service.uploadImageWithMetadata(
              _profileImage!.bytes,
              filename: _profileImage!.name,
              userScoped: true,
            );
      // Auth/Google photo URLs are not app-owned Cloudinary assets and must
      // never be persisted as a community profile image.
      final sourceImageUrl =
          uploadedImage?.url ??
          (CommunityService.isSafeCloudinaryImageUrl(_profileImageUrl)
              ? _profileImageUrl
              : '');
      final uploadedImageUrl = sourceImageUrl;
      final savedFocusX = _focusX.clamp(0, 100).toDouble();
      final savedFocusY = _focusY.clamp(0, 100).toDouble();
      final displayName = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final bio = _bio.text.trim();
      final socialLinks = _socialValues();
      if (kDebugMode) {
        debugPrint(
          'Profile save attempt=$attempt stage=validation nameLength=${displayName.length}',
        );
      }
      final savedProfile = await persistCommunityProfileDraft(
        displayName: displayName,
        claimDisplayName: (value) async {
          if (kDebugMode) debugPrint('Profile save attempt=$attempt stage=claim_started');
          await _service.claimDisplayName(value);
          if (kDebugMode) debugPrint('Profile save attempt=$attempt stage=claim_succeeded');
        },
        writeProfile: () => _service.firestore
            .collection('community_profiles')
            .doc(user.uid)
            .set({
              if (_roleMissing) 'role': _role,
              'bio': bio,
              'socialLinks': socialLinks,
              'profileFocusX': savedFocusX,
              'profileFocusY': savedFocusY,
              'profileZoom': _zoom,
              'profilePanX': _panX,
              'profilePanY': _panY,
              'profileImageUrl': sourceImageUrl,
              'profileSourceImageUrl': sourceImageUrl,
              if (uploadedImage?.publicId.isNotEmpty == true)
                'profileImagePublicId': uploadedImage!.publicId,
              if (uploadedImage?.publicId.isNotEmpty == true)
                'profileSourceImagePublicId': uploadedImage!.publicId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
        readProfileFromServer: () async {
          final snapshot = await _service.refreshOwnProfile();
          return snapshot.data() ?? const <String, dynamic>{};
        },
      );
      if (kDebugMode) debugPrint('Profile save attempt=$attempt stage=server_confirmed');
      // Firestore has confirmed the server-owned name and role at this point.
      // Paint that result before optional Auth mirroring/reload work so a
      // successful save is visible immediately.
      if (mounted) {
        setState(() {
          _loadedUid = user.uid;
          _profileDataUid = user.uid;
          _savedProfileName =
              (savedProfile['displayName'] as String? ?? displayName).trim();
          _roleMissing = false;
          _profileDraft.acceptSaved(
            uid: user.uid,
            nameValue: _savedProfileName,
            bioValue: savedProfile['bio'] as String? ?? bio,
          );
          _profileImageUrl = sourceImageUrl;
          _focusX = savedFocusX.toDouble();
          _focusY = savedFocusY.toDouble();
          _profileImage = null;
        });
      }
      // Firestore is the source of truth; an Auth refresh must not turn a saved profile into a failure.
      await user.updateDisplayName(displayName).catchError((_) {});
      if (uploadedImageUrl.isNotEmpty) {
        await user.updatePhotoURL(uploadedImageUrl).catchError((_) {});
      }
      await user.reload().catchError((_) {});
      // A nyitott chat- és profilnézetek is azonnal lássák a mentett publikus
      // adatokat; csak ennek a UID-nak a cache-e érvénytelenedik.
      CommunityService.clearPublicProfileCache(user.uid);
      CommunityService.clearProfileCache(user.uid);
      if (mounted) _message(AppStrings.tr('Profil mentve.'));
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Profile save attempt=$attempt stage=failed errorType=${error.runtimeType}',
        );
      }
      if (mounted) {
        _message('A profil mentése sikertelen: ${_chatError(error)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('E-mail-cím módosítása'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: tr(context, 'Új e-mail-cím')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const AppText('Küldés'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || email == null || email.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.requestEmailChange(email);
      _message(
        AppStrings.tr('Megerősítő linket küldtünk az új e-mail-címre. 24 órád van a megerősítésre.'),
      );
    } catch (error) {
      _message(_chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      // A Google-fiók automatikus neve külön folyamat; a korábbi e-mailes
      // űrlap aszinkron ellenőrzésének hibája nem tartozhat hozzá.
      _registrationNameError = null;
    });
    try {
      final signedIn = await _service.signInWithGoogle(
        role: _register ? _role : null,
        displayName: _register ? _name.text.trim() : null,
        socialLinks: _register ? _socialValues() : null,
      );
      if (!signedIn) return;
      if (_register && _referralCode.text.trim().isNotEmpty) {
        try {
          final claimed = await _service.claimReferralCode(_referralCode.text);
          if (claimed) await ReferralLinkService.clearPendingCode();
        } catch (_) {
          // Google registration remains successful if the optional code fails.
        }
      }
      _loadedUid = null;
      await _loadProfile(force: true);
      final completionNotice = _service.googleProfileCompletionNotice;
      if (completionNotice != null) _message(completionNotice);
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

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var currentVisible = false;
    var nextVisible = false;
    var confirmVisible = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const AppText('Jelszó módosítása'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: !currentVisible,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Jelenlegi jelszó'),
                    suffixIcon: IconButton(
                      tooltip: currentVisible ? 'Elrejtés' : AppStrings.tr('Megjelenítés'),
                      icon: Icon(
                        currentVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => currentVisible = !currentVisible,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: next,
                  obscureText: !nextVisible,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Új jelszó'),
                    suffixIcon: IconButton(
                      tooltip: nextVisible ? 'Elrejtés' : AppStrings.tr('Megjelenítés'),
                      icon: Icon(
                        nextVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => nextVisible = !nextVisible),
                    ),
                  ),
                ),
                TextField(
                  controller: confirm,
                  obscureText: !confirmVisible,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Új jelszó megerősítése'),
                    suffixIcon: IconButton(
                      tooltip: confirmVisible ? 'Elrejtés' : AppStrings.tr('Megjelenítés'),
                      icon: Icon(
                        confirmVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => confirmVisible = !confirmVisible,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Mentés'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      current.dispose();
      next.dispose();
      confirm.dispose();
      return;
    }
    if (next.text.length < 6 || next.text != confirm.text) {
      _message(
        AppStrings.tr('Az új jelszó legalább 6 karakter legyen, és a két mező egyezzen.'),
      );
    } else {
      try {
        await _service.changePassword(
          currentPassword: current.text,
          newPassword: next.text,
        );
        _message(AppStrings.tr('A jelszó módosítása sikerült.'));
      } catch (error) {
        _message(_chatError(error));
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<bool> _reauthenticateBeforeDeletion() async {
    final user = _service.auth.currentUser;
    final usesPassword =
        user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
    if (!usesPassword) return true;

    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Újrahitelesítés'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: tr(context, 'Jelenlegi jelszó')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Ellenőrzés'),
          ),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (confirmed != true || !mounted) return false;
    try {
      await _service.reauthenticateWithPassword(value);
      return true;
    } catch (error) {
      _message(_chatError(error));
      return false;
    }
  }

  Map<String, String> _socialValues() => {
    for (final entry in _social.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };

  void _loadSocialValues(Object? raw) {
    if (raw is Map) {
      for (final entry in _social.entries) {
        _setFormValue(entry.key, entry.value, raw[entry.key]?.toString() ?? '');
      }
      return;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      _setFormValue('facebook', _social['facebook']!, raw.trim());
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
          key: ValueKey('community-profile-social-${entry.key}'),
          controller: _social[entry.key],
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: AppStrings.tr(entry.value)),
        ),
      ),
  ];

  String _roleLabel(String role) => AppStrings.tr(
    const <String, String>{
      'dj': 'DJ',
      'organizer': 'Szervező',
      'partygoer': 'Bulizó',
    }[role] ??
        AppStrings.tr('Bulizó'),
  );

  Future<void> _chooseRole() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const AppText('Szerepkör'),
        children: [
          for (final option in const {
            'dj': 'DJ',
            'organizer': 'Szervező',
            'partygoer': 'Bulizó',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AppText(option.value),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) setState(() => _role = selected);
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
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
          const SnackBar(content: AppText('Az esemény már nem érhető el.')),
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
          const SnackBar(content: AppText('Az esemény nem tölthető be.')),
        );
      }
    }
  }

  List<Widget> _readOnlyProfileWidgets(User user, String initial) {
    final socialLabels = {
      'facebook': tr(context, 'Facebook'),
      'instagram': tr(context, 'Instagram'),
      'tiktok': 'TikTok',
      'youtube': 'YouTube',
      'spotify': tr(context, 'Spotify'),
    };
    final profileFavorites = ref
        .watch(favoritesProvider)
        .entries
        .where((entry) => entry.kind != FavoriteKind.news)
        .toList(growable: false);
    return [
      Center(
        child: ProfileAvatar(
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
          _savedProfileName.isEmpty
              ? tr(context, 'Profil befejezése szükséges')
              : _savedProfileName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 20),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.badge_outlined),
        title: const AppText('Szerepkör'),
        subtitle: Text(
          _service.isAdmin
              ? '${_roleLabel(_service.isOwner ? 'organizer' : _role)} / Admin'
              : _roleLabel(_role),
        ),
      ),
      if (_memberSince != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: const AppText('A közösség tagja'),
          subtitle: Text(
            MaterialLocalizations.of(context)
                .formatMediumDate(_memberSince!.toLocal()),
          ),
        ),
      AchievementBadgeCard(achievement: _achievement),
      const SizedBox(height: 12),
      if (_bio.text.trim().isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes_outlined),
          title: const AppText('Bemutatkozás'),
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
          label: const AppText('Saját DJ-adatlap megnyitása'),
        ),
      if (_claimedArtistIds.isNotEmpty) const SizedBox(height: 8),
      if (profileFavorites.isNotEmpty) ...[
        const SizedBox(height: 16),
        const AppText(
          'Kedvelt tartalmak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final entry in profileFavorites)
          ProfileContentCard(
            icon: switch (entry.kind) {
              FavoriteKind.event => Icons.event_outlined,
              FavoriteKind.artist => Icons.album_outlined,
              FavoriteKind.organizer => Icons.groups_outlined,
              FavoriteKind.news => Icons.article_outlined,
            },
            title: entry.title,
            subtitle: switch (entry.kind) {
              FavoriteKind.event => tr(context, 'Esemény'),
              FavoriteKind.artist => 'DJ',
              FavoriteKind.organizer => tr(context, 'Szervező'),
              FavoriteKind.news => tr(context, 'Hír'),
            },
            onTap: () => FavoritesScreen.openEntry(context, ref, entry),
          ),
      ],
      StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _service.watchActivePlannedEvents(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const [];
          if (events.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const AppText(
                'Események, ahol ott leszek',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (final event in events)
                ProfileContentCard(
                  icon: Icons.event_outlined,
                  title: event.data()['title'] as String? ?? tr(context, 'Esemény'),
                  subtitle: tr(context, 'Esemény, ahol ott leszek'),
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
              builder: (_) => CommunityProfileScreen(
                editing: true,
                onProfileDeleted: widget.onProfileDeleted,
              ),
            ),
          );
          _loadedUid = null;
          await _loadProfile();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const AppText('Profil szerkesztése'),
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
          label: const AppText('Közösségi adminisztráció'),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
        ),
        icon: const Icon(Icons.favorite_outline),
        label: const AppText('Kedvencek'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityConnectionsScreen(),
          ),
        ),
        icon: const Icon(Icons.people_outline),
        label: const AppText('Ismerősök'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CommunityBlockedUsersScreen(),
          ),
        ),
        icon: const Icon(Icons.block_outlined),
        label: const AppText('Blokkolt felhasználók'),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () async {
          await _service.signOut();
        },
        icon: const Icon(Icons.logout),
        label: const AppText('Kijelentkezés'),
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
    final profileName = _savedProfileName.isNotEmpty
        ? _savedProfileName
        : tr(context, 'HUHS user');
    final profileInitial = profileName.isEmpty
        ? 'H'
        : profileName.characters.first.toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Profil szerkesztése' : tr(context, 'Profil')),
      ),
      body: signedIn && _profileDataUid != user.uid
          ? Center(
              child: _profileError == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        AppText('Betöltés…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_profileError!),
                        TextButton(
                          onPressed: () => _loadProfile(force: true),
                          child: const AppText('Újrapróbálás'),
                        ),
                      ],
                    ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 900 : double.infinity,
                    ),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        18 +
                            MediaQuery.viewPaddingOf(context).bottom +
                            MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      children: signedIn
                          ? (widget.editing
                                ? [
                                    Center(
                                      child: ProfileAvatar(
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
                                        _savedProfileName.isNotEmpty
                                            ? _savedProfileName
                                            : tr(context, 'Profil befejezése szükséges'),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    if (user.email == null ||
                                        user.email!.trim().isEmpty ||
                                        user.emailVerified != true ||
                                        _name.text.trim().isEmpty ||
                                        _name.text.trim().toLowerCase() ==
                                            'huhs user') ...[
                                      Card(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: DefaultTextStyle.merge(
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onError,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (_name.text.trim().isEmpty)
                                                  const AppText(
                                                    'A felhasználónév megadása kötelező.',
                                                  ),
                                                if (user.email == null ||
                                                    user.email!.trim().isEmpty)
                                                  const AppText(
                                                    'Adj meg e-mail-címet és erősítsd meg 24 órán belül.',
                                                  )
                                                else if (user.emailVerified !=
                                                    true) ...[
                                                  const AppText(
                                                    'Erősítsd meg az e-mail-címedet 24 órán belül.',
                                                  ),
                                                  OutlinedButton.icon(
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onError,
                                                          side: BorderSide(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onError,
                                                          ),
                                                        ),
                                                    onPressed: _busy
                                                        ? null
                                                        : () async {
                                                            try {
                                                              final outcome =
                                                                  await _service
                                                                      .resendEmailVerification();
                                                              _message(
                                                                outcome == 'already_sent'
                                                                    ? AppStrings.tr('A megerősítő e-mailt már elküldtük.')
                                                                    : outcome == 'in_flight'
                                                                    ? AppStrings.tr('A megerősítő e-mail küldése folyamatban van.')
                                                                    : AppStrings.tr('A megerősítő e-mailt újraküldtük.'),
                                                              );
                                                            } catch (error) {
                                                              _message(
                                                                _chatError(
                                                                  error,
                                                                ),
                                                              );
                                                            }
                                                          },
                                                    icon: const Icon(
                                                      Icons
                                                          .mark_email_read_outlined,
                                                    ),
                                                    label: const AppText(
                                                      'Megerősítő e-mail újraküldése',
                                                    ),
                                                  ),
                                                ] else
                                                  const AppText(
                                                    'Adj meg egy megjelenési nevet.',
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (_service.isAdmin)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.admin_panel_settings_outlined,
                                        ),
                                        title: AppText('Szerepkör'),
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
                                        decoration: InputDecoration(
                                          labelText: tr(context, 'Szerepkör'),
                                          helperText: tr(context, 'Válaszd ki, hogyan használod az appot.'),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'dj',
                                            child: Text('DJ'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'organizer',
                                            child: AppText('Szervező'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'partygoer',
                                            child: AppText('Bulizó'),
                                          ),
                                        ],
                                        onChanged: _roleMissing
                                            ? (value) => setState(
                                                () => _role = value ?? _role,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    if (_service.isAdmin)
                                      OutlinedButton.icon(
                                        onPressed: () => Navigator.of(context)
                                            .push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const CommunityAdminScreen(),
                                              ),
                                            ),
                                        icon: const Icon(
                                          Icons.admin_panel_settings_outlined,
                                        ),
                                        label: const AppText(
                                          'Közösségi adminisztráció',
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    SubmissionImagePicker(
                                      image: _profileImage,
                                      title: tr(context, 'Profilkép'),
                                      helperText: tr(context, 'Opcionális kép; monogram jelenik meg, ha nincs feltöltve.'),
                                      onChanged: (image) => setState(() {
                                        _profileImage = image;
                                        if (image != null) {
                                          _resetImageTransform();
                                        }
                                      }),
                                    ),
                                    if (_profileImage != null ||
                                        _profileImageUrl.isNotEmpty) ...[
                                      const AppText(
                                        'Kép igazítása (húzás és nagyítás)',
                                      ),
                                      Center(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onScaleStart: (_) =>
                                              _gestureStartZoom = _zoom,
                                          onScaleUpdate: (details) {
                                            setState(() {
                                              _zoom =
                                                  (_gestureStartZoom *
                                                          details.scale)
                                                      .clamp(1, 3);
                                              _panX =
                                                  (_panX +
                                                          details
                                                                  .focalPointDelta
                                                                  .dx /
                                                              260)
                                                      .clamp(-1, 1);
                                              _panY =
                                                  (_panY +
                                                          details
                                                                  .focalPointDelta
                                                                  .dy /
                                                              260)
                                                      .clamp(-1, 1);
                                            });
                                          },
                                          child: ProfileAvatar(
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
                                    CommunityProfileFormFields(
                                      key: ValueKey(
                                        'community-profile-form-$_formUid',
                                      ),
                                      draft: _profileDraft,
                                      nameHelperText:
                                          _roleMissing ||
                                              _savedProfileName.isEmpty
                                          ? tr(context, 'Ez lesz a nyilvános profilneved.')
                                          : _service.isOwner
                                          ? tr(context, 'Adminisztrátorként korlátlan névmódosítás')
                                          : 'Éves névmódosítási lehetőség: ${1 - _usernameChangesUsed} maradt',
                                    ),
                                    const SizedBox(height: 12),
                                    ..._socialFields(),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: _busy ? null : _saveProfile,
                                      icon: const Icon(Icons.save_outlined),
                                      label: const AppText('Profil mentése'),
                                    ),
                                    if (user.providerData.any(
                                      (provider) =>
                                          provider.providerId == 'password',
                                    )) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : _changePassword,
                                        icon: const Icon(
                                          Icons.password_outlined,
                                        ),
                                        label: const AppText('Jelszó módosítása'),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _busy ? null : _changeEmail,
                                      icon: const Icon(
                                        Icons.alternate_email_outlined,
                                      ),
                                      label: const AppText(
                                        'E-mail-cím módosítása',
                                      ),
                                    ),
                                    Text(
                                      'Éves e-mail-módosítási lehetőség: ${1 - _emailChangesUsed} maradt',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.of(context)
                                          .push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const FavoritesScreen(),
                                            ),
                                          ),
                                      icon: const Icon(Icons.favorite_outline),
                                      label: const AppText('Kedvencek'),
                                    ),
                                    const SizedBox(height: 8),
                                    const AppText(
                                      'Tervezett események az Ott leszek funkcióval jelennek majd meg.',
                                    ),
                                    const SizedBox(height: 18),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await _service.signOut();
                                      },
                                      icon: const Icon(Icons.logout),
                                      label: const AppText('Kijelentkezés'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              final confirmed =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogContext) =>
                                                        AlertDialog(
                                                          title: const AppText(
                                                            'Profil törlése',
                                                          ),
                                                          content: const AppText(
                                                            'A profilod, a Chat-üzeneteid és a bejelentkezésed is törlődik. Folytatod?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    dialogContext,
                                                                    false,
                                                                  ),
                                                              child: const AppText(
                                                                'Mégse',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    dialogContext,
                                                                    true,
                                                                  ),
                                                              child: const AppText(
                                                                'Profil törlése',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                              if (confirmed != true) return;
                                              if (!context.mounted) return;
                                              if (!await _reauthenticateBeforeDeletion()) {
                                                return;
                                              }
                                              if (!context.mounted) return;
                                              final typedConfirmation =
                                                  TextEditingController();
                                              final verified = await showDialog<bool>(
                                                context: context,
                                                builder: (dialogContext) =>
                                                    AlertDialog(
                                                      title: const AppText(
                                                        'Végső megerősítés',
                                                      ),
                                                      content: TextField(
                                                        controller:
                                                            typedConfirmation,
                                                        autofocus: true,
                                                        decoration:
                                                            InputDecoration(
                                                              labelText: tr(context, 'Írd be: TÖRLÉS'),
                                                            ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogContext,
                                                                false,
                                                              ),
                                                          child: const AppText(
                                                            'Mégse',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogContext,
                                                                typedConfirmation
                                                                        .text
                                                                        .trim() ==
                                                                    'TÖRLÉS',
                                                              ),
                                                          child: const AppText(
                                                            'Törlés megerősítése',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                              typedConfirmation.dispose();
                                              if (verified != true ||
                                                  !mounted) {
                                                return;
                                              }
                                              setState(() => _busy = true);
                                              try {
                                                final cleanupStatus =
                                                    await _service
                                                        .deleteOwnProfile();
                                                await ref
                                                    .read(favoritesProvider)
                                                    .clearLocalCache();
                                                ref.invalidate(
                                                  communityAuthProvider,
                                                );
                                                ref.invalidate(
                                                  communityPostsProvider,
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                  ..hideCurrentSnackBar()
                                                  ..showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        cleanupStatus == 'cleanup_pending'
                                                            ? tr(context, 'A fiók törölve; a képek háttértakarítása folyamatban van.')
                                                            : tr(context, 'A profil törlése sikerült.'),
                                                      ),
                                                    ),
                                                  );
                                                Navigator.of(context).popUntil(
                                                  (route) => route.isFirst,
                                                );
                                                widget.onProfileDeleted?.call();
                                              } catch (error) {
                                                if (mounted) {
                                                  _message(
                                                    'A profil törlése sikertelen: ${_chatError(error)}',
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() => _busy = false);
                                                }
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.delete_forever_outlined,
                                      ),
                                      label: const AppText('Profil törlése'),
                                    ),
                                  ]
                                : _readOnlyProfileWidgets(user, profileInitial))
                          : [
                              const AppText(
                                'Regisztráció és bejelentkezés',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _register
                                    ? tr(context, 'A Chat névvel és képfeltöltéssel használható.')
                                    : tr(context, 'Jelentkezz be a közösségi profilodhoz.'),
                              ),
                              const SizedBox(height: 18),
                              if (_register)
                                TextField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: _checkRegistrationName,
                                  decoration: InputDecoration(
                                    labelText: tr(context, 'Megjelenő név'),
                                    errorText: _registrationNameError,
                                  ),
                                ),
                              if (_register) const SizedBox(height: 12),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                obscureText: !_passwordVisible,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Jelszó'),
                                  suffixIcon: IconButton(
                                    tooltip: _passwordVisible
                                        ? tr(context, 'Elrejtés')
                                        : tr(context, 'Megjelenítés'),
                                    onPressed: () => setState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    ),
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
                                    icon: const Icon(
                                      Icons.auto_fix_high_outlined,
                                    ),
                                    label: const AppText('Erős jelszó ajánlása'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordConfirmation,
                                  obscureText: !_passwordVisible,
                                  decoration: InputDecoration(
                                    labelText: tr(context, 'Jelszó megerősítése'),
                                  ),
                                ),
                                const AppText(
                                  'A regisztráció után megerősítő e-mailt küldünk. '
                                  'A profil használatához erősítsd meg a címedet.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                ..._socialFields(),
                                const SizedBox(height: 6),
                                const AppText(
                                  'A profil védelméhez a regisztráció után opcionális kétfaktoros védelem kapcsolható be a Beállításokban.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _busy ? null : _chooseRole,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: tr(context, 'Szerepkör'),
                                      suffixIcon: Icon(Icons.arrow_drop_down),
                                    ),
                                    child: Text(_roleLabel(_role)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _referralCode,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp('[A-Za-z0-9]'),
                                    ),
                                    LengthLimitingTextInputFormatter(16),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: tr(context, 'Ajánlókód (opcionális)'),
                                    helperText: tr(context, 'Ha kaptál kódot egy HUHS-felhasználótól.'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: Text(
                                  _register ? 'Regisztráció' : tr(context, 'Bejelentkezés'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _google,
                                icon: const Icon(Icons.login),
                                label: const AppText('Folytatás Google-fiókkal'),
                              ),
                              if (!_register)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          if (_email.text.trim().isEmpty) {
                                            _message(
                                              tr(context, 'Add meg az e-mail-címedet.'),
                                            );
                                            return;
                                          }
                                          try {
                                            await _service.sendPasswordReset(
                                              _email.text,
                                            );
                                            _message(
                                              AppStrings.tr('A jelszó-visszaállító e-mail elküldve.'),
                                            );
                                          } catch (error) {
                                            _message(_chatError(error));
                                          }
                                        },
                                  child: const AppText('Jelszó visszaállítása'),
                                ),
                              if (!_register)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          if (_email.text.trim().isEmpty ||
                                              _password.text.isEmpty) {
                                            _message(
                                              tr(context, 'Add meg az e-mail-címet és a jelszót.'),
                                            );
                                            return;
                                          }
                                          try {
                                            await _service
                                                .resendEmailVerificationForCredentials(
                                                  email: _email.text,
                                                  password: _password.text,
                                                );
                                            _message(
                                              AppStrings.tr('Az ellenőrző e-mailt újraküldtük.'),
                                            );
                                          } catch (error) {
                                            _message(_chatError(error));
                                          }
                                        },
                                  child: const AppText(
                                    'Ellenőrző e-mail újraküldése',
                                  ),
                                ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _register = !_register,
                                      ),
                                child: Text(
                                  _register
                                      ? tr(context, 'Már van fiókom')
                                      : tr(context, 'Új fiók létrehozása'),
                                ),
                              ),
                            ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
