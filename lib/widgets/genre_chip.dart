import 'package:flutter/material.dart';

import '../screens/genres/genre_discovery_screen.dart';

class GenreChip extends StatelessWidget {
  final String genre;

  const GenreChip({super.key, required this.genre});

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(genre),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GenreDiscoveryScreen(genre: genre),
          ),
        ),
      );
}
