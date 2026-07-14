import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile_submission.dart';
import '../../models/submission_image.dart';
import '../../providers/news_provider.dart';
import '../../providers/profile_submission_provider.dart';
import '../../widgets/submission_image_picker.dart';

class ArtistSubmissionScreen extends ConsumerStatefulWidget {
  const ArtistSubmissionScreen({super.key});

  @override
  ConsumerState<ArtistSubmissionScreen> createState() =>
      _ArtistSubmissionScreenState();
}

class _ArtistSubmissionScreenState
    extends ConsumerState<ArtistSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _realName = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Magyarország');
  final _biography = TextEditingController();
  final _contactEmail = TextEditingController();
  final _bookingEmail = TextEditingController();
  final Map<String, TextEditingController> _social = {
    'website': TextEditingController(),
    'facebook': TextEditingController(),
    'instagram': TextEditingController(),
    'tiktok': TextEditingController(),
    'spotify': TextEditingController(),
    'soundcloud': TextEditingController(),
    'youtube': TextEditingController(),
  };
  final Set<String> _categories = {};
  final Set<String> _genres = {};
  bool _bookingViaHuhs = false;
  SubmissionImage? _profileImage;
  SubmissionImage? _logo;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _realName.dispose();
    _city.dispose();
    _country.dispose();
    _biography.dispose();
    _contactEmail.dispose();
    _bookingEmail.dispose();
    for (final controller in _social.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_categories.isEmpty || _genres.isEmpty) {
      _message('Válassz legalább egy kategóriát és egy műfajt.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await ref
          .read(wordpressServiceProvider)
          .submitArtist(
            ArtistSubmission(
              name: _name.text,
              realName: _realName.text,
              categories: _categories.toList(growable: false),
              genres: _genres.toList(growable: false),
              city: _city.text,
              country: _country.text,
              biography: _biography.text,
              contactEmail: _contactEmail.text,
              bookingEmail: _bookingViaHuhs ? '' : _bookingEmail.text,
              bookingViaHuhs: _bookingViaHuhs,
              profileImageUrl: '',
              socialLinks: {
                for (final entry in _social.entries)
                  if (entry.value.text.trim().isNotEmpty)
                    entry.key: entry.value.text,
              },
            ),
            image: _profileImage,
            logo: _logo,
          );

      if (!mounted) return;
      await _success(message);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(profileSubmissionOptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DJ beküldése')),
      body: _background(
        Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            children: [
              const Text(
                'DJ / előadó beküldése',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Az adatlap csak szerkesztői ellenőrzés és jóváhagyás után jelenhet meg.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 22),
              _field(_name, 'DJ-név *', Icons.graphic_eq, validator: _required),
              _field(_realName, 'Valódi név', Icons.person_outline),
              options.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => ListTile(
                  title: const Text('Nem sikerült betölteni a kategóriákat.'),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.invalidate(profileSubmissionOptionsProvider),
                    child: const Text('Újra'),
                  ),
                ),
                data: (value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategória *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: value.artistCategories.map((category) {
                        return FilterChip(
                          selected: _categories.contains(category.slug),
                          label: Text(category.name),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _categories.add(category.slug)
                                : _categories.remove(category.slug);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Műfajok *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: value.genres.map((genre) {
                        return FilterChip(
                          selected: _genres.contains(genre),
                          label: Text(genre),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _genres.add(genre)
                                : _genres.remove(genre);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              _field(_city, 'Város', Icons.location_city),
              _field(_country, 'Ország', Icons.public),
              _field(
                _contactEmail,
                'Privát kapcsolattartó e-mail *',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: _emailRequired,
                helper: 'Csak az admin látja, nem kerül ki az adatlapra.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _bookingViaHuhs,
                onChanged: (value) => setState(() => _bookingViaHuhs = value),
                title: const Text(
                  'Fellépésszervezés a Hungarian Hardstyle-on keresztül',
                ),
                subtitle: const Text(
                  'A booking levelek az info@hungarianhardstyle.hu címre érkeznek.',
                ),
              ),
              if (!_bookingViaHuhs)
                _field(
                  _bookingEmail,
                  'Nyilvános booking e-mail',
                  Icons.mark_email_read_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _optionalEmail,
                ),
              SubmissionImagePicker(
                image: _profileImage,
                title: 'Profilkép feltöltése',
                helperText:
                    'Opcionális · álló portré ajánlott · legfeljebb 5 MB',
                onChanged: (image) => setState(() => _profileImage = image),
              ),
              SubmissionImagePicker(
                image: _logo,
                title: 'DJ-logó feltöltése',
                helperText:
                    'Opcionális · négyzetes, átlátszó PNG ajánlott · legfeljebb 5 MB',
                onChanged: (image) => setState(() => _logo = image),
              ),
              _field(_biography, 'Bemutatkozás', Icons.notes, maxLines: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Közösségi és zenei linkek'),
                children: _social.entries.map((entry) {
                  return _field(
                    entry.value,
                    _linkLabel(entry.key),
                    Icons.link,
                    keyboardType: TextInputType.url,
                    validator: _optionalUrl,
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Küldés…' : 'DJ beküldése'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _background(Widget child) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
      ),
    ),
    child: SafeArea(top: false, child: child),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helper,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF171717),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Kötelező mező.' : null;

  String? _emailRequired(String? value) =>
      _required(value) ?? _optionalEmail(value);

  String? _optionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Érvénytelen e-mail-cím.';
  }

  String? _optionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? null
        : 'Teljes http:// vagy https:// linket adj meg.';
  }

  String _linkLabel(String key) => key[0].toUpperCase() + key.substring(1);

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _success(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Color(0xFFE53935)),
      title: const Text('Beküldés sikeres'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Rendben'),
        ),
      ],
    ),
  );
}
