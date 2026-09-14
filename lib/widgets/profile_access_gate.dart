import 'package:flutter/material.dart';

bool hasRequiredProfile(Map<String, dynamic>? data) {
  final name = (data?['displayName'] as String? ?? '').trim();
  return name.length >= 2 &&
      name.length <= 40 &&
      !name.contains('@') &&
      const {'dj', 'organizer', 'partygoer'}.contains(data?['role']);
}

class ProfileAccessState {
  const ProfileAccessState(this.data, {this.fromCache = false});
  final Map<String, dynamic>? data;
  final bool fromCache;
}

/// The underlying Navigator stays mounted, but cannot receive input or back
/// events until the server-owned name and required role have been loaded.
class ProfileAccessGate extends StatefulWidget {
  const ProfileAccessGate({
    super.key,
    required this.uid,
    required this.profile,
    required this.completion,
    required this.child,
    this.onServerProfileMissing,
  });
  final String? uid;
  final Stream<ProfileAccessState> profile;
  final Widget completion;
  final Widget child;
  final Future<void> Function()? onServerProfileMissing;

  @override
  State<ProfileAccessGate> createState() => _ProfileAccessGateState();
}

class _ProfileAccessGateState extends State<ProfileAccessGate> {
  bool _missingCheckPending = false;
  late Stream<ProfileAccessState> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  @override
  void didUpdateWidget(covariant ProfileAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _profile = widget.profile;
      _missingCheckPending = false;
    }
  }

  void _checkMissingServerProfile(ProfileAccessState value) {
    if (value.data != null ||
        value.fromCache ||
        widget.onServerProfileMissing == null ||
        _missingCheckPending) {
      return;
    }
    _missingCheckPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.onServerProfileMissing!();
      } finally {
        if (mounted) _missingCheckPending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) return widget.child;
    return StreamBuilder<ProfileAccessState>(
      key: ValueKey(widget.uid),
      stream: _profile,
      builder: (context, state) {
        final loaded = state.hasData && !state.hasError;
        final value = state.data;
        if (loaded && value != null) _checkMissingServerProfile(value);
        final allowed =
            loaded && value != null && hasRequiredProfile(value.data);
        // A tényleges, de hiányos cache-elt profil is szerkeszthető állapot,
        // nem végtelen betöltés. A hiányzó szerverprofil ellenőrzése ettől
        // külön, kizárólag nem cache-elt hiánynál fut.
        final showCompletion = loaded && value != null;
        // Do not keep the protected app tree Offstage while profile
        // completion is open. It could load the old incomplete snapshot and
        // reveal that stale state after the gate becomes allowed.
        if (allowed) return widget.child;
        return PopScope(
          canPop: false,
          child: showCompletion
              ? widget.completion
              : Scaffold(
                  body: Center(
                    child: Text(
                      state.hasError
                          ? 'A profil nem tölthető be. Ellenőrizd az internetkapcsolatot.'
                          : 'Betöltés…',
                    ),
                  ),
                ),
        );
      },
    );
  }
}
