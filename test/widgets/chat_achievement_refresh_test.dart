import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/community_service.dart';

void main() {
  testWidgets('a chat refresh-jelzés újrarendereli a badge-hallgatót', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: CommunityService.publicProfileRefreshGeneration,
          builder: (context, generation, child) => Text('refresh:$generation'),
        ),
      ),
    );

    final before = CommunityService.publicProfileRefreshGeneration.value;
    CommunityService.clearPublicProfileCache('chat-widget-test-user');
    await tester.pump();

    expect(find.text('refresh:${before + 1}'), findsOneWidget);
  });
}
