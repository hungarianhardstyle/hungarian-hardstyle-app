import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../services/poll_service.dart';

final pollServiceProvider = Provider<PollService>((ref) => PollService());

/// A nyitott kerdőív. Null, ha épp nincs (a szerver csak nyitott kerdőívet ad).
final activePollProvider = FutureProvider<HuhsPoll?>((ref) async {
  return ref.watch(pollServiceProvider).activePoll();
});
