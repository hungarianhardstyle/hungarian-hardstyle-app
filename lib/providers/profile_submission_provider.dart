import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_submission.dart';
import 'news_provider.dart';

final profileSubmissionOptionsProvider =
    FutureProvider<ProfileSubmissionOptions>((ref) async {
      return ref.watch(wordpressServiceProvider).getProfileSubmissionOptions();
    });
