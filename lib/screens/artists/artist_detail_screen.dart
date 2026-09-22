import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/html_linkifier.dart';
import '../../core/layout/scroll_bottom_inset.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../core/errors/user_facing_error.dart';
import '../../models/artist.dart';
import '../../models/artist_claim_status.dart';
import '../../widgets/genre_chip.dart';
import '../../providers/artists_provider.dart';
import '../../widgets/event_card.dart';
import '../../providers/community_provider.dart';
import 'artist_edit_screen.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final int artistId;
  final String fallbackName;

  const ArtistDetailScreen({
    super.key,
    required this.artistId,
    this.fallbackName = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (artistId <= 0) {
      return _MissingArtist(name: fallbackName);
    }

    final artist = ref.watch(artistDetailProvider(artistId));
    final title = artist.when(
      data: (value) => value.title.trim().isEmpty ? fallbackName : value.title,
      loading: () => fallbackName,
      error: (error, stack) => fallbackName,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.trim().isEmpty ? 'DJ adatlap' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: artist.when(
        // ⚠️ Háttér-frissítésnél a korábbi adatlap marad (nem villan spinner).
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fallbackName.isEmpty
                      ? 'Nem sikerült betölteni a DJ-adatlapot.'
                      : '$fallbackName adatlapját nem sikerült betölteni.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(artistDetailProvider(artistId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálás'),
                ),
              ],
            ),
          ),
        ),
        data: (value) => _ArtistContent(artist: value),
      ),
    );
  }
}

class _ArtistContent extends ConsumerWidget {
  final Artist artist;

  const _ArtistContent({required this.artist});

  String _biographyHtml() {
    final value = artist.biography.trim();
    if (value.isEmpty) return '';

    final hasHtml = RegExp(
      r'</?[a-z][\s\S]*>',
      caseSensitive: false,
    ).hasMatch(value);
    if (hasHtml) return linkifyPlainUrls(value);

    return linkifyPlainUrls(
      value
          .split(RegExp(r'\n\s*\n'))
          .map((paragraph) => '<p>${_escapeHtml(paragraph.trim())}</p>')
          .join(),
    );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;')
        .replaceAll('\n', '<br>');
  }

  /// Az adatlap **átvétele** (a felületen ez a szó áll a „claim" helyén).
  ///
  /// ⚠️ A gomb **csak** akkor látszik, ha a szerver szerint egyezik valamelyik
  /// e-mail cím (booking vagy privát) — a döntés a szerveré, ezért itt nincs
  /// „találgatás", és a hibaüzenetet is a szerver adja (magyarul). A korábbi
  /// verzió a `permission-denied`-re egy **beégetett** szöveget írt ki, ami a
  /// valódi okot (nincs megadva cím / nem egyezik) elrejtette.
  Future<void> _claimArtist(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(communityServiceProvider).claimArtist(artist.id);
      ref.invalidate(artistClaimStatusProvider(artist.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Az adatlap átvétele sikerült.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  /// Az átvétel **visszavonása** (a sajátját bárki, a hibásat az admin).
  ///
  /// Azért van rá szükség, mert élesben egy idegen DJ-adatlap került a
  /// tulajdonos fiókjára, és eddig **semmilyen** úton nem lehetett levenni.
  Future<void> _releaseArtistClaim(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(communityServiceProvider).releaseArtistClaim(artist.id);
      ref.invalidate(artistClaimStatusProvider(artist.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Az átvétel visszavonva.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biography = _biographyHtml();
    final claimStatus = ref.watch(artistClaimStatusProvider(artist.id));
    // Ismeretlen/hibás állapotban **nem** kínálunk claim gombot: nem tudjuk,
    // hogy szabad-e, és a tulajdonos kérése szerint a gomb csak egyező e-mail
    // címnél jelenhet meg (azt a szerver dönti el).
    final claim = claimStatus.valueOrNull ?? ArtistClaimStatus.unknown;
    final bookingEmail = artist.effectiveBookingEmail;
    final imageUrl = artist.profileImageUrl.isNotEmpty
        ? artist.profileImageUrl
        : artist.logoUrl;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final heroCacheWidth =
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(1080, 1600);
          final logoCacheWidth = (76 * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(152, 304);
          return SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: landscape ? 1100 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Hero(
                        tag: 'artist_${artist.id}',
                        child: AspectRatio(
                          aspectRatio: 16 / 11,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: heroCacheWidth,
                                maxWidthDiskCache: heroCacheWidth,
                                alignment: const Alignment(0, -0.5),
                              ),
                              if (artist.logoUrl.isNotEmpty &&
                                  artist.profileImageUrl.isNotEmpty)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.72,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: artist.logoUrl,
                                      fit: BoxFit.contain,
                                      memCacheWidth: logoCacheWidth,
                                      maxWidthDiskCache: logoCacheWidth,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artist.title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (artist.realName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              artist.realName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                              ),
                            ),
                          ],
                          if (artist.location.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 7),
                                Expanded(child: Text(artist.location)),
                              ],
                            ),
                          ],
                          if (artist.categories.isNotEmpty ||
                              artist.genres.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...artist.categories.map(
                                    (category) =>
                                        Chip(label: Text(category.name)),
                                  ),
                                  ...artist.genres.map(
                                    (genre) => GenreChip(genre: genre),
                                  ),
                                ],
                              ),
                            ),
                          if (artist.socialLinks.isNotEmpty ||
                              artist.webUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ...artist.socialLinks.entries.map(
                                    (entry) => OutlinedButton.icon(
                                      onPressed: () => openSocialLink(
                                        context,
                                        entry.value,
                                        title: _socialLabel(entry.key),
                                      ),
                                      icon: Icon(_socialIcon(entry.key)),
                                      label: Text(_socialLabel(entry.key)),
                                    ),
                                  ),
                                  if (artist.webUrl.isNotEmpty &&
                                      !claim.claimed)
                                    OutlinedButton.icon(
                                      onPressed: () => openInAppBrowser(
                                        context,
                                        artist.webUrl,
                                      ),
                                      icon: const Icon(Icons.language),
                                      label: const Text('Webes adatlap'),
                                    ),
                                ],
                              ),
                            ),
                          if (claim.mine)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  8,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.greenAccent.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user,
                                      size: 20,
                                      color: Colors.greenAccent,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Ez a te DJ-adatlapod.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _releaseArtistClaim(context, ref),
                                      child: const Text('Átvétel visszavonása'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Aki átvette az adatlapot, az **szerkesztheti** is
                          // (a tulajdonos kérése, 2026-09-22). A jogosultságot a
                          // szerver dönti el (`claim.mine`), és a mentést is ő
                          // ellenőrzi.
                          if (claim.mine)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ArtistEditScreen(artist: artist),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Adatlap szerkesztése'),
                              ),
                            )
                          else if (claim.canClaim)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: OutlinedButton.icon(
                                onPressed: () => _claimArtist(context, ref),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Adatlap átvétele'),
                              ),
                            )
                          else if (claim.claimed)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text(
                                'Ezt a DJ-adatlapot már átvette egy fiók.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          if (bookingEmail.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF171717),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Booking',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    if (artist.bookingViaHuhs) ...[
                                      const Text(
                                        'A fellépés a Hungarian Hardstyle-on keresztül szervezhető.',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    SelectableText(
                                      bookingEmail,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _openBookingEmail(context),
                                      icon: const Icon(Icons.email_outlined),
                                      label: Text(
                                        artist.bookingViaHuhs
                                            ? 'Szervezés a Hungarian Hardstyle-on keresztül'
                                            : 'Fellépés lekötése e-mailben',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (biography.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Text(
                          'Bemutatkozás',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Html(
                        data: biography,
                        onLinkTap: (url, attributes, element) =>
                            openInAppBrowser(
                              context,
                              resolveHtmlLinkTarget(
                                callbackUrl: url,
                                attributes: attributes,
                                visibleText: element?.text,
                              ),
                            ),
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.all(20),
                            fontSize: FontSize(17),
                            lineHeight: const LineHeight(1.65),
                            color: Colors.white,
                          ),
                          'p': Style(margin: Margins.only(bottom: 16)),
                          'a': Style(
                            color: Colors.redAccent,
                            textDecoration: TextDecoration.none,
                          ),
                        },
                      ),
                    ],
                    if (artist.upcomingEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Közelgő események',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...artist.upcomingEvents.map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: EventCard(event: event),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // A rendszer alsó sávja + levegő (egy szabály, egy helyen).
                    const ScrollBottomInset(extra: 28),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _socialIcon(String key) {
    return switch (key) {
      'spotify' => Icons.music_note,
      'soundcloud' => Icons.cloud,
      'youtube' => Icons.play_circle_outline,
      'website' => Icons.language,
      'facebook' || 'instagram' || 'tiktok' => Icons.alternate_email,
      _ => Icons.link,
    };
  }

  Future<void> _openBookingEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: artist.effectiveBookingEmail,
      queryParameters: {'subject': 'Fellépés kérése – ${artist.title}'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem sikerült megnyitni a levelezőt.')),
      );
    }
  }

  String _socialLabel(String key) {
    return switch (key) {
      'facebook' => 'Facebook',
      'instagram' => 'Instagram',
      'tiktok' => 'TikTok',
      'spotify' => 'Spotify',
      'soundcloud' => 'SoundCloud',
      'youtube' => 'YouTube',
      'website' => 'Weboldal',
      _ => key,
    };
  }
}

class _MissingArtist extends StatelessWidget {
  final String name;

  const _MissingArtist({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DJ adatlap')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            name.isEmpty
                ? 'Ehhez a fellépőhöz még nincs összekapcsolt DJ-adatlap.'
                : '$name még nincs összekapcsolva egy DJ-adatlappal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 17),
          ),
        ),
      ),
    );
  }
}
