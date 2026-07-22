import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/event_submission.dart';
import '../../models/submission_image.dart';
import '../../providers/events_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/organizers_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/submission_image_picker.dart';

class EventSubmissionScreen extends ConsumerStatefulWidget {
  const EventSubmissionScreen({super.key});

  @override
  ConsumerState<EventSubmissionScreen> createState() =>
      _EventSubmissionScreenState();
}

class _EventSubmissionScreenState extends ConsumerState<EventSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedGenres = {};

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  int? _selectedOrganizerId;
  String _selectedOrganizerName = '';
  SubmissionImage? _flyer;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );

    if (selected != null && mounted) {
      setState(() => _startDate = selected);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 22, minute: 0),
    );

    if (selected != null && mounted) {
      setState(() => _startTime = selected);
    }
  }

  Future<void> _pickEndDate() async {
    final now = _startDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: _startDate ?? DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (selected != null && mounted) setState(() => _endDate = selected);
  }

  Future<void> _pickEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          _endTime ?? _startTime ?? const TimeOfDay(hour: 23, minute: 0),
    );
    if (selected != null && mounted) setState(() => _endTime = selected);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final user = ref.read(communityServiceProvider).auth.currentUser;
    if (user == null || user.isAnonymous) {
      _showMessage('Eseményt csak regisztrált felhasználó küldhet be.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null) {
      _showMessage('Válaszd ki az esemény dátumát.');
      return;
    }

    if ((_endDate == null) != (_endTime == null)) {
      _showMessage('Az esemény végét napra és órára együtt add meg.');
      return;
    }

    if (_endDate != null && _startDate != null) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime?.hour ?? 0,
        _startTime?.minute ?? 0,
      );
      final end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime?.hour ?? 0,
        _endTime?.minute ?? 0,
      );
      if (!end.isAfter(start)) {
        _showMessage(
          'Az esemény vége nem lehet a kezdés előtt vagy azzal egy időben.',
        );
        return;
      }
    }

    if (_selectedGenres.isEmpty) {
      _showMessage('Válassz legalább egy műfajt.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final message = await ref
          .read(wordpressServiceProvider)
          .submitEvent(
            EventSubmission(
              title: _titleController.text,
              startDate: _formatDate(_startDate),
              startTime: _formatTime(_startTime),
              endDate: _formatDate(_endDate),
              endTime: _formatTime(_endTime),
              venueName: _venueController.text,
              venueCity: _cityController.text,
              venueZip: _zipController.text,
              venueAddress: _addressController.text,
              organizerName: _selectedOrganizerName,
              organizerId: _selectedOrganizerId ?? 0,
              genres: _selectedGenres.toList(growable: false),
              contactEmail: _emailController.text,
              eventUrl: _urlController.text,
              description: _descriptionController.text,
            ),
            image: _flyer,
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

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Kötelező mező.' : null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    final email = value!.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Adj meg egy érvényes e-mail-címet.';
  }

  String? _validateUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? null
        : 'Teljes http:// vagy https:// linket adj meg.';
  }

  String? _validatePostalCode(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    return RegExp(r'^\d+$').hasMatch(value!.trim())
        ? null
        : 'Az irányítószám csak számokat tartalmazhat.';
  }

  String _formatDate(DateTime? value) =>
      value == null ? '' : DateFormat('yyyy-MM-dd').format(value);

  String _formatTime(TimeOfDay? value) => value == null
      ? ''
      : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final genres = ref.watch(eventSubmissionGenresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Esemény beküldése')),
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
                  'Küldd be az eseményed',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A beküldés ellenőrzés után kerülhet fel az oldalra és az alkalmazásba.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 24),
                _field(
                  controller: _titleController,
                  label: 'Esemény neve *',
                  icon: Icons.event,
                  validator: _required,
                ),
                _pickerTile(
                  icon: Icons.calendar_month,
                  label: 'Dátum *',
                  value: _startDate == null
                      ? 'Válassz dátumot'
                      : DateFormat('yyyy. MM. dd.').format(_startDate!),
                  onTap: _pickDate,
                ),
                _pickerTile(
                  icon: Icons.schedule,
                  label: 'Kezdés',
                  value: _startTime?.format(context) ?? 'Válassz időpontot',
                  onTap: _pickTime,
                  trailing: _startTime == null
                      ? null
                      : IconButton(
                          tooltip: 'Időpont törlése',
                          onPressed: () => setState(() => _startTime = null),
                          icon: const Icon(Icons.close),
                        ),
                ),
                _pickerTile(
                  icon: Icons.event_available,
                  label: 'Esemény vége',
                  value: _endDate == null
                      ? 'Opcionális – válassz napot'
                      : DateFormat('yyyy. MM. dd.').format(_endDate!),
                  onTap: _pickEndDate,
                  trailing: _endDate == null
                      ? null
                      : IconButton(
                          tooltip: 'Vége törlése',
                          onPressed: () => setState(() {
                            _endDate = null;
                            _endTime = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
                _pickerTile(
                  icon: Icons.schedule,
                  label: 'Esemény vége – óra',
                  value:
                      _endTime?.format(context) ??
                      'Opcionális – válassz időpontot',
                  onTap: _pickEndTime,
                ),
                _field(
                  controller: _venueController,
                  label: 'Helyszín *',
                  icon: Icons.location_on,
                  validator: _required,
                ),
                _field(
                  controller: _cityController,
                  label: 'Város *',
                  icon: Icons.location_city,
                  validator: _required,
                ),
                _field(
                  controller: _zipController,
                  label: 'Irányítószám *',
                  icon: Icons.markunread_mailbox,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePostalCode,
                ),
                _field(
                  controller: _addressController,
                  label: 'Cím *',
                  icon: Icons.home,
                  validator: _required,
                ),
                _organizerDropdown(ref.watch(organizersProvider(''))),
                const SizedBox(height: 4),
                const Text(
                  'Műfajok *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                genres.when(
                  loading: () => const Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Nem sikerült betölteni a műfajokat.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(eventSubmissionGenresProvider),
                        child: const Text('Újra'),
                      ),
                    ],
                  ),
                  data: (items) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((genre) {
                      final selected = _selectedGenres.contains(genre);
                      return FilterChip(
                        selected: selected,
                        label: Text(genre),
                        onSelected: (value) {
                          setState(() {
                            value
                                ? _selectedGenres.add(genre)
                                : _selectedGenres.remove(genre);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  controller: _emailController,
                  label: 'Kapcsolattartó e-mail *',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                _field(
                  controller: _urlController,
                  label: 'Facebook- vagy eseménylink',
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                  validator: _validateUrl,
                ),
                SubmissionImagePicker(
                  image: _flyer,
                  title: 'Flyer feltöltése',
                  helperText:
                      'Opcionális · JPG, PNG vagy WebP · legfeljebb 5 MB',
                  onChanged: (image) => setState(() => _flyer = image),
                ),
                _field(
                  controller: _descriptionController,
                  label: 'Rövid leírás',
                  icon: Icons.notes,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Küldés…' : 'Esemény elküldése'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
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
  }

  Widget _organizerDropdown(AsyncValue<dynamic> value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: value.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text(
          'A szervezők nem tölthetők be.',
          style: TextStyle(color: Colors.white70),
        ),
        data: (page) {
          final items = page.items as List;
          return DropdownButtonFormField<int?>(
            initialValue: _selectedOrganizerId,
            decoration: const InputDecoration(
              labelText: 'Szervező',
              prefixIcon: Icon(Icons.groups),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Nincs kiválasztva'),
              ),
              ...items.map(
                (organizer) => DropdownMenuItem<int?>(
                  value: organizer.id as int,
                  child: Text(
                    organizer.title as String,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (id) {
              final matches = items.where((item) => item.id == id);
              final match = matches.isEmpty ? null : matches.first;
              setState(() {
                _selectedOrganizerId = id;
                _selectedOrganizerName = match?.title as String? ?? '';
              });
            },
          );
        },
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value),
          trailing: trailing ?? const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
