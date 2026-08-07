import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/voting_service.dart';

final votingServiceProvider = Provider<VotingService>((ref) => VotingService());
