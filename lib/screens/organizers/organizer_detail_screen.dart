import 'package:flutter/material.dart';

import '../../models/event.dart';

class OrganizerDetailScreen extends StatelessWidget {
  final EventOrganizer organizer;

  const OrganizerDetailScreen({super.key, required this.organizer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szervező adatlap')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              organizer.name,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'A részletes szervezői adatok az organizer REST API bekötése után jelennek meg.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
