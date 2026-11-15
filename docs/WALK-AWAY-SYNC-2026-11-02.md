# Walk Away (#12942) – helyreállítás, 2026-11-02

Éles állapot a javítás előtt: `audio_processing_status=queued`, üres WordPress
terméklista, négy `DRAFT` Play-vásárlási opció. A futó szinkron
`audio-not-ready` indokkal kihagyta a kiadványt.

A hitelesített privát letöltési végpont mind a négy változatra 200-at adott;
a válaszfolyam elején a WAV-ok RIFF/WAVE, az MP3-ak ID3 fejlécet tartalmaztak.
A nyilvános előzetes is elérhető, MP3-fejléccel. Az XML-RPC `wp.getPost`
válasza a privát fájlok metaadatait is tartalmazta; a forráscsatolmányok
azonosítója már 0 volt. Ez kész fájlok mellett fennmaradt hibás státuszt igazol.
A teljes hanganyag tartalmi/minőségi ellenőrzése nem történt meg.

A `tools/repair-label-audio-status.mjs 12942 --confirm` az ellenőrzések és
egy második, változatlanságot ellenőrző olvasás után kizárólag a meglévő
`audio_processing_status` mezőt állította `ready` értékre a WordPress
támogatott `wp.editPost` felületén. Ezután egy célzott
`label_product_sync_requests` kérést hozott létre. Nem indított új
hangfeldolgozást, nem törölt fájlt, és nem módosított árat.

Az eredeti backend 11:22:18 UTC-kor (12:22:18 Budapest) ezt naplózta:
`label_sync_summary { releaseId: 12942, processed: 1, failed: [], skipped: [] }`.
Külön Play API-visszaolvasás: mind a négy opció `ACTIVE`. A WordPress
visszaolvasása: `ready`, mind a négy termékazonosító megvan, WAV 700 Ft,
MP3 550 Ft. Készülékes Billing-lekérdezés és tényleges vásárlás nem történt.

Azt, hogy történetileg melyik mentés/hook állította vissza a státuszt
`queued` értékre, a rendelkezésre álló adatok nem bizonyítják. A plugin
újramentési ága ezt az állapotot nem javítja magától. Ez a helyreállítás
az érintett kiadvány hibás adatait rendezi; általános pluginjavítás nem készült.
Az app, a deployolt Functions és a plugin kódja változatlan: új AAB vagy
deploy nem kellett.
