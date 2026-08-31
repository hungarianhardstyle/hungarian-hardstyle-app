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
            'Hatályos: 2026. augusztus 28.\n\n'
            'Adatkezelő: a Hungarian Hardstyle alkalmazás üzemeltetője. '
            'Az üzemeltető hivatalos jogi nevét, székhelyét és postai elérhetőségét az '
            'aktuális webes impresszummal egyezően kell feltüntetni. Kapcsolat: '
            'info@hungarianhardstyle.hu. Ez a tájékoztató az alkalmazásban megvalósított '
            'adatkezelési folyamatokat foglalja össze.',
          ),
          SizedBox(height: 14),
          Text(
            'Milyen adatokat kezelünk?\n\n'
            'A fiók és a közösségi funkciók használatához kezelhetjük a Firebase-fiókhoz '
            'tartozó azonosítót, e-mail-címet, megjelenő nevet, szerepkört, profilképet és '
            'a beállításokat. Kezeljük továbbá a Chat- és privát üzeneteket, az üzenetekhez '
            'kapcsolódó képeket, a blokkolási és ismerősi kapcsolatokat, a hírreakciókat, '
            'kedvenceket, szavazatokat, esemény-részvételt és a beküldések adatait. '
            'A push értesítésekhez a készülék Firebase Cloud Messaging tokenje kerülhet a '
            'felhasználói fiókhoz kötött, elkülönített tárolóba.',
          ),
          SizedBox(height: 14),
          Text(
            'Vásárlás és letöltés esetén a Google Play termékazonosítója, a vásárlási token '
            'ellenőrzéséhez szükséges adatok és a felhasználói azonosító kapcsolódhatnak '
            'egymáshoz. A vásárlási jogosultságot a szerver ellenőrzi; a letöltési jogosultság '
            'csak ellenőrzött vásárlás vagy az adott változathoz tartozó jutalmazott feloldás '
            'után adható ki. A vásárlási token nyers értékét az alkalmazás adatbázisa nem '
            'tárolja, csak ellenőrzéshez szükséges, vissza nem fejthető azonosító kerülhet megőrzésre.',
          ),
          SizedBox(height: 14),
          Text(
            'Külső szolgáltatók és adatáramlás: Firebase/Firestore és Firebase Authentication '
            '(fiók, közösség, üzenetek, jogosultságok és biztonsági működés), Firebase Cloud '
            'Messaging (push értesítések), Cloudinary (feltöltött profil- és közösségi képek), '
            'WordPress (publikus hírek, események, DJ-k, szervezők, beküldések és a védett '
            'letöltési végpont), Google Play Billing (vásárlás és tranzakció-ellenőrzés), '
            'Google AdMob és annak hozzájárulás-kezelése (banner- és jutalmazott hirdetések), '
            'valamint Mailchimp (külön feliratkozással kért hírlevél). Az egyes szolgáltatók '
            'saját adatkezelési tájékoztatója is irányadó; szerepük az adott folyamatban '
            'adatfeldolgozó vagy önálló adatkezelő lehet. Az adatokat csak a szolgáltatás, '
            'biztonság, visszaélés-megelőzés, jogosultság-ellenőrzés és jogi kötelezettség '
            'teljesítéséhez szükséges mértékben továbbítjuk.',
          ),
          SizedBox(height: 14),
          Text(
            'Célok és jogalapok: a fiók, a közösségi funkciók, a vásárlás és a letöltés '
            'biztosítása a szerződés teljesítéséhez vagy az azt megelőző lépésekhez szükséges; '
            'a biztonság, csalás- és visszaélés-megelőzés, hibakeresés és moderáció az '
            'üzemeltető jogos érdeke lehet; a hírlevél, a nem szükséges értesítések és a '
            'személyre szabott hirdetési megoldások a szükséges hozzájárulás alapján működnek; '
            'jogi vagy számviteli kötelezettség esetén az adatkezelés jogszabályon alapul. '
            'A hozzájárulás bármikor visszavonható, de ez nem érinti a visszavonás előtti '
            'adatkezelés jogszerűségét.',
          ),
          SizedBox(height: 14),
          Text(
            'Megőrzés és törlés: a fiókhoz és közösségi szolgáltatáshoz kapcsolódó adatokat '
            'addig őrizzük, amíg a szolgáltatás biztosításához szükséges, illetve amíg jogi '
            'igény, biztonsági vagy jogszabályi megőrzési ok indokolja. A hirdetési és '
            'hírlevél-hozzájárulás visszavonása után az erre épülő kezelést megszüntetjük. '
            'A saját profil törlése az alkalmazásból indítható; ez a Firebase Auth-fiók és a '
            'hozzá kapcsolt közösségi adatok törlését kezdeményezi. Egyes, jogszabály alapján '
            'megőrzendő vagy jogi igényhez szükséges adatok a szükséges időre korlátozottan '
            'megmaradhatnak.',
          ),
          SizedBox(height: 14),
          Text(
            'Érintetti jogok: kérheted a hozzáférést, helyesbítést, törlést, az adatkezelés '
            'korlátozását, az adathordozhatóságot, valamint tiltakozhatsz a jogos érdeken '
            'alapuló adatkezelés ellen. Kérelmedet az info@hungarianhardstyle.hu címen lehet '
            'benyújtani; az üzemeltető a személyazonosság ellenőrzéséhez szükséges adatot '
            'kérhet. A kérelmeket indokolatlan késedelem nélkül, főszabály szerint egy hónapon '
            'belül kell megválaszolni. Jogod van panaszt tenni a lakóhelyed, tartózkodási '
            'helyed vagy a jogsértés feltételezett helye szerinti adatvédelmi hatóságnál; '
            'Magyarországon ez a NAIH (https://www.naih.hu).',
          ),
        ],
      ),
    );
  }
}
