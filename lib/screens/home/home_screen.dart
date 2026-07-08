import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            Center(
              child: Image.asset(
                'assets/logos/huhs_logo.png',
                width: width * 0.72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.music_note,
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "LEGFRISSEBB HÍREK",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 15),

            _featuredNews(),

            const SizedBox(height: 20),

            _smallNews(
              "WordPress kapcsolat hamarosan elkészül",
            ),

            _smallNews(
              "Automatikus hírszinkron fejlesztés alatt",
            ),

            _smallNews(
              "Push értesítések érkeznek",
            ),

            const SizedBox(height: 35),

            const Text(
              "KÖZELGŐ ESEMÉNYEK",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 190,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  EventCard(
                    title: "Hardstyle Revolution",
                    date: "2026",
                  ),
                  SizedBox(width: 14),
                  EventCard(
                    title: "Új esemény",
                    date: "Hamarosan",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _featuredNews() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            color: Colors.red.shade700,
            child: const Center(
              child: Icon(
                Icons.image,
                color: Colors.white,
                size: 70,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Ide kerül majd a kiemelt WordPress hír",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  static Widget _smallNews(String title) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.article),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String date;

  const EventCard({
    super.key,
    required this.title,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: const Color(0xff1d1d1d),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.festival,
              size: 60,
              color: Colors.red,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(date),
          ],
        ),
      ),
    );
  }
}