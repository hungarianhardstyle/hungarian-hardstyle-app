import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/screens/events/events_screen.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';
import 'package:hungarian_hardstyle_app/widgets/event_card.dart';

void main() {
  for (final scenario in [(3, 2), (0, 2), (3, 3), (12, 2)]) {
    final (firstCount, lastPage) = scenario;
    testWidgets(
      '$firstCount current events, $lastPage pages: all pages remain reachable',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Wordpress(firstCount, lastPage);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wordpressServiceProvider.overrideWithValue(service),
              communityServiceProvider.overrideWithValue(_Community()),
              communityAuthProvider.overrideWith(
                (ref) => Stream<User?>.value(null),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const EventsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final more = find.widgetWithText(OutlinedButton, 'További események');
        await tester.scrollUntilVisible(more, 500);
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        final exoform = find.byWidgetPredicate(
          (w) => w is EventCard && w.event.id == 13053,
        );
        await tester.scrollUntilVisible(exoform, 500);
        expect(exoform, findsOneWidget);
        expect(service.pages, contains(2));
        if (lastPage == 3) {
          await tester.scrollUntilVisible(more, 500);
          await tester.tap(more);
          await tester.pumpAndSettle();
          final last = find.byWidgetPredicate(
            (w) => w is EventCard && w.event.id == 13054,
          );
          await tester.scrollUntilVisible(last, 500);
          expect(last, findsOneWidget);
          await tester.scrollUntilVisible(exoform, -500);
          expect(
            exoform,
            findsOneWidget,
            reason: 'page two must survive page three',
          );
        }
        expect(
          find.widgetWithText(OutlinedButton, 'További események'),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

HuhsEvent _event(int id) => HuhsEvent.fromJson({
  'id': id,
  'title': id == 13053 ? 'Noise Conference pres: EXOFORM' : 'Event $id',
  'start_date': '2099-12-05',
  'end_date': '2099-12-06',
  'visible': true,
});

class _Wordpress extends Fake implements WordpressService {
  _Wordpress(this.firstCount, this.lastPage);
  final int firstCount;
  final int lastPage;
  final pages = <int>[];

  @override
  Future<List<HuhsEvent>> getEvents({
    bool includePast = false,
    int page = 1,
    int perPage = 12,
    bool forceRefresh = false,
  }) async => (await getEventsPage(includePast: includePast, page: page)).items;

  @override
  Future<EventsPage> getEventsPage({
    bool includePast = false,
    int page = 1,
    int perPage = 12,
    bool forceRefresh = false,
  }) async {
    if (!includePast) pages.add(page);
    return EventsPage(
      items: includePast
          ? []
          : page == 1
          ? List.generate(firstCount, (i) => _event(i + 1))
          : [_event(13051 + page)],
      page: page,
      perPage: perPage,
      total: 13,
      hasMore: !includePast && page < lastPage,
    );
  }
}

class _Community extends Fake implements CommunityService {
  @override
  bool get isAdmin => false;
  @override
  String get cachedAccountRole => '';
}
