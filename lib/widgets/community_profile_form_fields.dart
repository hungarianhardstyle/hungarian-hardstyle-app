import '../core/i18n/app_strings.dart';
import '../core/i18n/tr.dart';
import 'package:flutter/material.dart';

class CommunityProfileTextDraft {
  final name = TextEditingController();
  final bio = TextEditingController();
  final nameFocus = FocusNode();
  final bioFocus = FocusNode();

  String? _uid;
  bool _hydrated = false;
  final Set<String> _edited = <String>{};

  void bindUid(String? uid) {
    if (_uid == uid) return;
    // The first Auth event can arrive after the form is already editable.
    // That transition is not an account switch, so a stale profile snapshot
    // must not replace the user's in-progress draft.
    final keepUnboundDraft = _uid == null && uid != null && _edited.isNotEmpty;
    _uid = uid;
    if (keepUnboundDraft) {
      // hydrate() keeps the edited fields and still loads untouched ones.
      _hydrated = false;
      return;
    }
    _hydrated = false;
    _edited.clear();
    nameFocus.unfocus();
    bioFocus.unfocus();
    name.clear();
    bio.clear();
  }

  void markEdited(String field) => _edited.add(field);

  bool get hasUnsavedEdits => _edited.isNotEmpty;

  void hydrate({
    required String uid,
    required String nameValue,
    required String bioValue,
  }) {
    if (_uid != uid) bindUid(uid);
    if (_hydrated) return;
    _setInitialValue('name', name, nameValue);
    _setInitialValue('bio', bio, bioValue);
    _hydrated = true;
  }

  void acceptSaved({
    required String uid,
    required String nameValue,
    required String bioValue,
  }) {
    _uid = uid;
    _hydrated = true;
    _edited.clear();
    _setValue(name, nameValue);
    _setValue(bio, bioValue);
  }

  void _setInitialValue(
    String field,
    TextEditingController controller,
    String value,
  ) {
    if (_edited.contains(field)) return;
    _setValue(controller, value);
  }

  static void _setValue(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void dispose() {
    name.dispose();
    bio.dispose();
    nameFocus.dispose();
    bioFocus.dispose();
  }
}

class CommunityProfileFormFields extends StatelessWidget {
  const CommunityProfileFormFields({
    super.key,
    required this.draft,
    required this.nameHelperText,
  });

  final CommunityProfileTextDraft draft;
  final String nameHelperText;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        key: const ValueKey('community-profile-name'),
        controller: draft.name,
        focusNode: draft.nameFocus,
        onChanged: (_) => draft.markEdited('name'),
        decoration: InputDecoration(
          labelText: tr(context, 'Megjelenő név'),
          helperText: nameHelperText,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('community-profile-bio'),
        controller: draft.bio,
        focusNode: draft.bioFocus,
        onChanged: (_) => draft.markEdited('bio'),
        maxLines: 3,
        decoration: InputDecoration(labelText: tr(context, 'Bemutatkozás')),
      ),
    ],
  );
}

Future<Map<String, dynamic>> persistCommunityProfileDraft({
  required String displayName,
  required Future<void> Function(String displayName) claimDisplayName,
  required Future<void> Function() writeProfile,
  required Future<Map<String, dynamic>> Function() readProfileFromServer,
}) async {
  final normalizedName = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalizedName.length < 2 ||
      normalizedName.length > 40 ||
      normalizedName.contains('@') ||
      !RegExp(
        r"^[\p{L}\p{N}][\p{L}\p{N} ._'-]*$",
        unicode: true,
      ).hasMatch(normalizedName)) {
    throw StateError(
      AppStrings.tr(
        'AUTH/profile-invalid-display-name: Adj meg 2–40 karakteres, érvényes megjelenítési nevet.',
      ),
    );
  }
  await claimDisplayName(normalizedName);
  await writeProfile();
  final stored = await readProfileFromServer();
  final storedName = (stored['displayName'] as String? ?? '').trim();
  final storedRole = stored['role'] as String?;
  if (storedName != normalizedName ||
      !const {'dj', 'organizer', 'partygoer'}.contains(storedRole)) {
    throw StateError(
      AppStrings.tr(
        'AUTH/profile-save-not-confirmed: A profil mentését a szerver nem igazolta vissza. Próbáld újra.',
      ),
    );
  }
  return stored;
}
