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
            'A Hungarian Hardstyle az alkalmazás működéséhez szükséges adatokat kezeli. '
            'A regisztráció során megadott e-mail-címet, megjelenő nevet, szerepkört és '
            'az önkéntesen feltöltött profilképet a közösségi funkciók biztosítására használjuk.',
          ),
          SizedBox(height: 14),
          Text(
            'A Chat üzenetei, reakciói és képei a közösségi szolgáltatás működéséhez '
            'szükséges ideig maradnak meg. A saját profil törölhető az alkalmazásból; '
            'adminisztrátor szükség esetén felhasználói fiókot és Chat-üzenetet is törölhet.',
          ),
          SizedBox(height: 14),
          Text(
            'Külső szolgáltatók: Firebase (hitelesítés, profilok, Chat, reakciók és pushértesítések), '
            'Cloudinary (profil- és közösségi képek), WordPress (hírek, események, DJ-k, '
            'szervezők és beküldések), Mailchimp (hírlevél-feliratkozás) és Google AdMob '
            '(alkalmazáson belüli hirdetések és jutalmazott letöltésfeloldás). A szolgáltatók csak a saját feladatukhoz szükséges adatokat kapják meg.',
          ),
          SizedBox(height: 14),
          Text(
            'Kérheted az adataidhoz való hozzáférést, helyesbítését vagy törlését a '
            'info@hungarianhardstyle.hu címen. A készüléken tárolt kedvencek és értesítési '
            'beállítások helyben kezelhetők. Jogellenes adatkezelés gyanúja esetén panaszt '
            'tehetsz a felügyeleti hatóságnál.',
          ),
        ],
      ),
    );
  }
}
