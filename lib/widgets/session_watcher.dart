import 'dart:async';

import 'package:flutter/widgets.dart';

/// Lives above the Navigator: replacing a route must not stop session checks.
class SessionWatcher extends StatefulWidget {
  const SessionWatcher({
    super.key,
    required this.users,
    required this.refresh,
    required this.onEnded,
    required this.onVerified,
    required this.child,
  });
  final Stream<String?> users;
  final Future<Map<String, bool>> Function() refresh;
  final void Function(bool deleted) onEnded;
  final VoidCallback onVerified;
  final Widget child;

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _subscription;
  Timer? _timer;
  String? _uid;
  bool _checking = false;
  bool _endedDuringCheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.users.listen((uid) {
      final ended = _uid != null && uid == null;
      _uid = uid;
      if (!ended) return;
      if (_checking) {
        _endedDuringCheck = true;
      } else {
        widget.onEnded(false);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_checking || _uid == null) return;
    final uid = _uid;
    _checking = true;
    _endedDuringCheck = false;
    try {
      final result = await widget.refresh();
      if (!mounted || (_uid != null && _uid != uid)) return;
      if (result['active'] == false || _endedDuringCheck) {
        widget.onEnded(result['deleted'] == true);
        _endedDuringCheck = false;
      } else if (result['emailVerifiedChanged'] == true) {
        widget.onVerified();
      }
    } catch (_) {
      // A transport failure is not proof that an account was deleted.
    } finally {
      if (mounted && _endedDuringCheck && _uid == null) widget.onEnded(false);
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
