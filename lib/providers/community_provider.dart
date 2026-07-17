import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_post.dart';
import '../services/community_service.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final communityPostsProvider = StreamProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityServiceProvider).watchPosts();
});
