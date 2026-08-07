import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/voting.dart';
import 'news_provider.dart';

final votingProvider = FutureProvider<VotingSeason>((ref) async {
  return ref.watch(wordpressServiceProvider).getActiveVoting();
});
