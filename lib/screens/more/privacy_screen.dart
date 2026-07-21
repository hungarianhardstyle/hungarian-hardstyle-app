import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adatvédelem és GDPR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Adatkezelési tájékoztató',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'A Hungarian Hardstyle app a működéshez szükséges adatokat kezeli. '
            'A regisztráció során megadott e-mail-címet, megjelenő nevet, '
            'szerepkört és az önkéntesen feltöltött profilképet a közösségi '
            'funkciók biztosítására használjuk.',
          ),
          SizedBox(height: 14),
          Text(
            'A Chat-bejegyzések és képek a közösségi szolgáltatás működéséig '
            'megmaradnak. A felhasználói fiók és a hozzá tartozó profil törlését '
            'az adminisztrátor végezheti el kérésre.',
          ),
          SizedBox(height: 14),
          Text(
            'Külső szolgáltatók: Firebase (hitelesítés, adatbázis és értesítések), '
            'Cloudinary (képfeltöltés) és WordPress (hírek, események, DJ-k és '
            'szervezők). A szolgáltatók csak a saját feladatukhoz szükséges '
            'adatokat kapják meg.',
          ),
          SizedBox(height: 14),
          Text(
            'Kérheted az adataid helyesbítését vagy törlését a '
            'info@hungarianhardstyle.hu címen. Jogellenes adatkezelés gyanúja '
            'esetén panaszt tehetsz a felügyeleti hatóságnál.',
          ),
        ],
      ),
    );
  }
}
