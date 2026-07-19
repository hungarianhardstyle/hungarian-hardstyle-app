import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile_submission.dart';
import '../../models/submission_image.dart';
import '../../providers/news_provider.dart';
import '../../providers/profile_submission_provider.dart';
import '../../widgets/submission_image_picker.dart';

class OrganizerSubmissionScreen extends ConsumerStatefulWidget {
  const OrganizerSubmissionScreen({super.key});

  @override
  ConsumerState<OrganizerSubmissionScreen> createState() =>
      _OrganizerSubmissionScreenState();
}

class _OrganizerSubmissionScreenState
    extends ConsumerState<OrganizerSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Magyarország');
  final _description = TextEditingController();
  final _contactEmail = TextEditingController();
  final Map<String, TextEditingController> _links = {
    'website': TextEditingController(),
    'facebook': TextEditingController(),
    'instagram': TextEditingController(),
    'tiktok': TextEditingController(),
  };
  SubmissionImage? _logo;
  final Set<String> _genres = {};
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    _description.dispose();
    _contactEmail.dispose();
    for (final controller in _links.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_genres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz legalább egy műfajt.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await ref
          .read(wordpressServiceProvider)
          .submitOrganizer(
            OrganizerSubmission(
              name: _name.text,
              city: _city.text,
              country: _country.text,
              description: _description.text,
              contactEmail: _contactEmail.text,
              genres: _genres.toList(growable: false),
              logoUrl: '',
              socialLinks: _linkValues(),
            ),
            image: _logo,
          );

      if (!mounted) return;
      await showDialog<void>(
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
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szervező beküldése')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              children: [
                const Text(
                  'Szervező beküldése',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A szervezői adatlap csak ellenőrzés és jóváhagyás után jelenhet meg.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 22),
                _field(_name, 'Szervező neve *', Icons.groups, _required),
                _field(_city, 'Város', Icons.location_city, null),
                _field(_country, 'Ország', Icons.public, null),
                _field(
                  _contactEmail,
                  'Privát kapcsolattartó e-mail *',
                  Icons.email_outlined,
                  _emailRequired,
                  keyboardType: TextInputType.emailAddress,
                  helper: 'Csak az admin látja.',
                ),
                ref
                    .watch(profileSubmissionOptionsProvider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          const Text('A műfajok betöltése sikertelen.'),
                      data: (options) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Műfajok *',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: options.genres
                                .map(
                                  (genre) => FilterChip(
                                    selected: _genres.contains(genre),
                                    label: Text(genre),
                                    onSelected: (selected) => setState(() {
                                      selected
                                          ? _genres.add(genre)
                                          : _genres.remove(genre);
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                SubmissionImagePicker(
                  image: _logo,
                  title: 'Szervezői logó feltöltése',
                  helperText:
                      'Opcionális · JPG, PNG vagy WebP · legfeljebb 5 MB',
                  onChanged: (image) => setState(() => _logo = image),
                ),
                _field(
                  _description,
                  'Bemutatkozás',
                  Icons.notes,
                  null,
                  maxLines: 6,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Weboldal és közösségi linkek',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._links.entries.map(
                  (entry) => _field(
                    entry.value,
                    _label(entry.key),
                    Icons.link,
                    _optionalUrl,
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Küldés…' : 'Szervező beküldése'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?)? validator, {
    TextInputType? keyboardType,
    String? helper,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
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

  String? _emailRequired(String? value) {
    final required = _required(value);
    if (required != null) return required;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
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

  String _label(String key) => switch (key) {
    'website' => 'Weboldal',
    'facebook' => 'Facebook',
    'instagram' => 'Instagram',
    'tiktok' => 'TikTok',
    _ => key,
  };

  Map<String, String> _linkValues() => {
    for (final entry in _links.entries)
      if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text,
  };
}
