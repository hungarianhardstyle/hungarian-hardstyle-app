import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/widgets/event_card.dart';

void main() {
  testWidgets('event card fits at 2x accessibility text size', (tester) async {
    tester.view
      ..physicalSize = const Size(720, 1280)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const event = HuhsEvent(
      id: 1,
      title: 'Rave Revolution - Stenk',
      description: '',
      startDate: '2026-07-17',
      startTime: '23:30',
      endDate: '',
      endTime: '',
      venueName: 'Stenk',
      venueCity: 'Budapest',
      venueZip: '1087',
      venueAddress: 'Kerepesi út 9',
      venueCountry: 'HU',
      googleMapsUrl: '',
      facebookEventUrl: '',
      genres: [
        'Hardstyle',
        'Rawstyle',
        'Euphoric',
        'Classic Hardstyle',
        'Reverse Bass',
        'Hardcore',
        'Uptempo',
      ],
      ticketType: '',
      ticketUrl: '',
      organizer: EventOrganizer(id: 0, name: ''),
      artists: [],
      flyerUrl: '',
      featured: false,
      visible: true,
      status: 'publish',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: EventCard(event: event, width: 250),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
