import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/tr.dart';
import '../../models/artist.dart';
import '../../models/submission_image.dart';
import '../../providers/artists_provider.dart';
import '../../providers/community_provider.dart';
import '../../services/artist_profile_form.dart';
import '../../services/wordpress_service.dart';
import '../../widgets/app_text.dart';
import '../../widgets/submission_image_picker.dart';

/// Az **átvett** DJ-adatlap szerkesztése.
///
/// A tulajdonos kérése (2026-09-22): *„Aki claimelte a dj adatlapját, tudja
/// szerkeszteni is."* A kérdező ablakban: **szövegek + közösségi linkek +
/// képcsere**.
///
/// ⚠️ Ez a képernyő **csak** akkor nyílik meg, ha a szerver szerint az adatlap a
/// hívóé (`ArtistClaimStatus.mine`) — a döntést nem itt hozzuk. A mentést a
/// szerver is ellenőrzi (`updateClaimedArtistProfile`), és a mezőket is ő szűri.
///
/// ⚠️ Amit a DJ **nem** szerkeszthet (szándékosan): a foglalási e-mail (ez
/// igazolja az átvételt), a privát cím, a mûfajok és a ház döntései (láthatóság,
/// kiemelés). Ezt a képernyő meg is mondja, hogy ne keresse.
class ArtistEditScreen extends ConsumerStatefulWidget {
  const ArtistEditScreen({super.key, required this.artist});

  final Artist artist;

  @override
  ConsumerState<ArtistEditScreen> createState() => _ArtistEditScreenState();
}

class _ArtistEditScreenState extends ConsumerState<ArtistEditScreen> {
  late final Map<String, String> _initial;
  late final Map<String, TextEditingController> _controllers;
  SubmissionImage? _profileImage;
  SubmissionImage? _coverImage;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initial = artistProfileFormInitial(widget.artist);
    _controllers = {
      for (final entry in _initial.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {
    for (final entry in _controllers.entries) entry.key: entry.value.text,
  };

  Future<void> _save() async {
    if (_saving) return;
    final values = _values;
    final errors = artistProfileFormErrors(values);
    if (errors.isNotEmpty) {
      setState(() => _message = errors.values.first);
      return;
    }

    setState(() {
      _saving = true;
      _message = 'Mentés…';
    });

    try {
      // 1. A kiválasztott képek feltöltése (ugyanaz az út, mint a beküldésnél).
      String? profileUrl;
      String? coverUrl;
      if (_profileImage != null) {
        profileUrl = await WordpressService().uploadProfileImage(_profileImage!);
      }
      if (_coverImage != null) {
        coverUrl = await WordpressService().uploadProfileImage(_coverImage!);
      }

      // 2. Csak a MEGVÁLTOZOTT mezők (a tiltott kulcsok kiszűrve).
      final fields = changedArtistProfileFields(
        initial: _initial,
        values: values,
        profileImageUrl: profileUrl,
        coverImageUrl: coverUrl,
      );
      if (fields.isEmpty) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _message = artistProfileNothingToSave;
        });
        return;
      }

      // 3. A szerver ellenőrzi az átvételt, szűri a mezőket, és ír a WordPressbe.
      final updated = await ref
          .read(communityServiceProvider)
          .updateClaimedArtistProfile(widget.artist.id, fields);

      // 4. A nyilvános adatlap és a lista újratöltése, hogy a változás látszódjon.
      ref.invalidate(artistDetailProvider(widget.artist.id));
      ref.invalidate(artistsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(artistProfileSavedLabel(updated.length))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = userFacingError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Adatlap szerkesztése'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: const AppText('Mentés'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.title.isEmpty ? 'DJ-adatlap' : artist.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const AppText(
                    'Ez az átvett adatlapod. A fényképet, a bemutatkozást és a '
                    'linkeket szerkesztheted — a foglalási e-mail cím és a '
                    'mûfajok a Hungarian Hardstyle kezében maradnak.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SubmissionImagePicker(
            image: _profileImage,
            title: tr(context, 'Profilkép'),
            helperText: tr(context, 'Ez a kép jelenik meg a DJ-adatlapod tetején.'),
            onChanged: (image) => setState(() => _profileImage = image),
          ),
          SubmissionImagePicker(
            image: _coverImage,
            title: tr(context, 'Borítókép'),
            helperText: tr(context, 'A borítókép a profil mögött látszik.'),
            onChanged: (image) => setState(() => _coverImage = image),
          ),
          for (final entry in artistTextFieldLabels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[entry.key],
                maxLength: entry.key == 'title'
                    ? artistTitleMaxLength
                    : artistShortFieldMaxLength,
                decoration: InputDecoration(
                  labelText: entry.value,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _controllers['biography'],
              maxLines: 6,
              maxLength: artistBiographyMaxLength,
              decoration: InputDecoration(
                labelText: tr(context, 'Bemutatkozás'),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const Divider(height: 28),
          const AppText(
            'Közösségi linkek',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Teljes címet adj meg (https://…). Ha kiüríted, a link eltűnik.',
            style: TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final key in artistSocialKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[key],
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: artistSocialLabels[key] ?? key,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : () => unawaited(_save()),
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Mentés…' : tr(context, 'Mentés')),
          ),
        ],
      ),
    );
  }
}
