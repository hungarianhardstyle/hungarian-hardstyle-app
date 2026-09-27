#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **születési dátum / 16+ korhatár / privát chat jelentés**
 * körhöz (a tulajdonos döntése, 2026-09-27).
 *
 * MIÉRT KELL: a zöld kapu önmagában nem bizonyíték — meg kell mérni, hogy a
 * hiba **el is kapható**. Minden mutációnál egy konkrét védelmet veszünk ki,
 * lefuttatjuk a kapukat, és elvárjuk, hogy **bukjanak**; utána bájtazonosan
 * visszaállítunk, és a helyreállított körnek **zöldnek** kell lennie.
 *
 * Két kapu-csoport:
 *   * Dart: `flutter test` a születési dátum, a jelentés, az i18n- és a
 *     widget-teszttel;
 *   * szerver: `node --test functions/birth-date-plan.test.cjs`.
 *
 * Használat: node tmp/mutation-proof-birthdate-report.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const DART_TESTS = [
  'test/services/birth_date_test.dart',
  'test/services/private_chat_report_test.dart',
  'test/services/i18n_untranslated_ui_test.dart',
  'test/widgets/chat_birth_date_prompt_test.dart',
];

const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const MUTATIONS = [
  // ---- 1. A regisztrációs korhatár kikényszerítése -------------------------
  {
    name: 'az e-mailes regisztráció csak formailag ellenőrzi a dátumot (16+ kapu kiesik)',
    file: 'lib/services/community_service.dart',
    find: ['    final normalizedBirthDate = BirthDate.requireRegistrationValue(birthDate);'],
    replace: ['    final normalizedBirthDate = BirthDate.requireValue(birthDate);'],
  },
  {
    name: 'a regisztráció nem menti el a születési dátumot',
    file: 'lib/services/community_service.dart',
    find: [
      "          'birthDate': normalizedBirthDate,",
      "          'birthDateVisible': false,",
    ],
    replace: ["          'birthDateVisible': false,"],
  },
  {
    name: 'a szerveroldali második kapu nem kapja meg a dátumot',
    file: 'lib/services/community_service.dart',
    find: ["        parameters: {'email': normalizedEmail, 'birthDate': normalizedBirthDate},"],
    replace: ["        parameters: {'email': normalizedEmail},"],
  },
  {
    name: 'a Google-regisztráció nem kéri a 16+ dátumot',
    file: 'lib/services/community_service.dart',
    find: ['          final requiredBirthDate = BirthDate.requireRegistrationValue('],
    replace: ['          final requiredBirthDate = BirthDate.requireValue('],
  },
  {
    name: 'a Google-regisztráció nem írja be a dátumot a profilba',
    file: 'lib/services/community_service.dart',
    find: [
      '          if (providedBirthDate != null &&',
      "              (existingData['birthDate'] as String? ?? '').trim().isEmpty)",
      "            'birthDate': providedBirthDate,",
    ],
    replace: [
      '          if (providedBirthDate != null &&',
      "              (existingData['birthDate'] as String? ?? '').trim().isEmpty) 'updatedAt': 'x',",
    ],
  },
  {
    name: 'a profil-mentés nem kényszeríti ki a kötelező dátumot',
    file: 'lib/widgets/community_profile_form_fields.dart',
    find: ['    BirthDate.requireValue(birthDate);'],
    replace: ['    // BirthDate.requireValue(birthDate);'],
  },
  {
    name: 'a profil-szerkesztő mentése nem kéri kötelezővé a dátumot',
    file: 'lib/screens/community/community_screen.dart',
    find: ['        requireBirthDate: true,'],
    replace: ['        requireBirthDate: false,'],
  },
  // ---- 2. A dátum szabályai ------------------------------------------------
  {
    name: 'az életkor nem veszi figyelembe a születésnap előtti állapotot',
    file: 'lib/services/birth_date.dart',
    find: ['    if (!hadBirthday) age -= 1;'],
    replace: ['    if (false) age -= 1;'],
  },
  {
    name: 'a jövőbeli dátum is elfogadott születési dátum',
    file: 'lib/services/birth_date.dart',
    find: ['    if (date.isAfter(_todayOf(null))) return null;'],
    replace: ['    if (false) return null;'],
  },
  {
    name: 'a figyelmeztető sáv feltétele nem nézi, hogy a néző kiskorú-e',
    file: 'lib/services/birth_date.dart',
    find: ['  }) => isMinor(viewerBirthDate, now: now) && partnerIsAdult;'],
    replace: ['  }) => partnerIsAdult;'],
  },
  {
    name: 'a dátumválasztó bármikor enged választani (nincs 16 éves korlát)',
    file: 'lib/widgets/birth_date_field.dart',
    find: ['    lastDate: last,'],
    replace: ['    lastDate: DateTime(2100),'],
  },
  {
    name: 'a már tárolt, 16 év alatti dátum jelzése kiesik',
    file: 'lib/widgets/birth_date_field.dart',
    find: [
      '    final underage = date != null && !BirthDate.isAtLeast(value, BirthDate.minimumAge);',
    ],
    replace: ['    final underage = false;'],
  },
  // ---- 3. A Chat fül felszólítása -----------------------------------------
  {
    name: 'a hiányzó dátum sávja nem jelenik meg',
    file: 'lib/screens/community/community_screen.dart',
    find: ['            if (!_birthDateMissing || _anonymous) return content;'],
    replace: ['            return content;'],
  },
  {
    name: 'a felajánló ablak nem nyílik meg magától',
    file: 'lib/screens/community/community_screen.dart',
    find: ['      if (_birthDateMissing) _scheduleBirthDateDialog();'],
    replace: ['      if (false) _scheduleBirthDateDialog();'],
  },
  {
    name: 'a Google-ág bejelentkezésnél is bekérné a dátumot (a régi fiók elakadna)',
    file: 'lib/screens/community/community_screen.dart',
    find: ['        birthDate: _register ? _birthDate : null,'],
    replace: ['        birthDate: _birthDate,'],
  },
  // ---- 4. A nyilvános profil ----------------------------------------------
  {
    name: 'a nyilvános profil nem olvassa a vetített születési dátumot',
    file: 'lib/screens/more/community_users_screen.dart',
    find: ["          final birthDate = BirthDate.parse(data['birthDate'] as String?);"],
    replace: ['          final DateTime? birthDate = null;'],
  },
  {
    name: 'a szerver a dátumot engedély nélkül vetíti ki',
    file: 'functions/birth-date-plan.js',
    find: ['  if (!profile || profile.birthDateVisible !== true) return {};'],
    replace: ['  if (!profile) return {};'],
  },
  {
    name: 'a szerver a visszavont dátumot nem törli a vetítésből',
    file: 'functions/index.js',
    find: ['  for (const field of birthDateProjectionDeletions(data)) {'],
    replace: ['  for (const field of []) {'],
  },
  // ---- 5. A privát chat jelentése -----------------------------------------
  {
    name: 'a jelentés nem a közös mező-összeállítót használja',
    file: 'lib/services/community_service.dart',
    find: ['      ...privateChatReportFields('],
    replace: ['      ...<String, dynamic>{},'],
  },
  {
    name: 'az ismeretlen indok kódja nyers értékként megy be',
    file: 'lib/services/chat_report.dart',
    find: ["  return chatReportReasons.contains(code) ? code : 'other';"],
    replace: ["  return code.isEmpty ? 'other' : code;"],
  },
  {
    name: 'a jelentés minden esetben a másik fél szövegét idézi',
    file: 'lib/services/chat_report.dart',
    find: ['  final quoted = lastSenderId.trim() == reported && reported.isNotEmpty'],
    replace: ['  final quoted = lastMessage.trim().isNotEmpty && reported.isNotEmpty'],
  },
  {
    name: 'a jelentés menüpont eltűnik a beszélgetés menüjéből',
    file: 'lib/screens/community/private_messages_screen.dart',
    find: ["              if (value == 'report') _reportUser();"],
    replace: ['              // if (value == \'report\') _reportUser();'],
  },
  {
    name: 'a visszajelzés nem ajánlja fel a blokkolást',
    file: 'lib/screens/community/private_messages_screen.dart',
    find: [
      '            action: SnackBarAction(',
      "              label: AppStrings.tr('Felhasználó blokkolása'),",
      '              onPressed: _block,',
      '            ),',
    ],
    replace: ['            action: null,'],
  },
  {
    name: 'a kiskorú ↔ nagykorú figyelmeztető sáv nem épül be a beszélgetésbe',
    file: 'lib/screens/community/private_messages_screen.dart',
    find: ['          if (_showAdultPartnerWarning) _adultPartnerWarning(),'],
    replace: ['          if (false) _adultPartnerWarning(),'],
  },
  {
    name: 'a jelentés menüpont értéke megváltozik (a koppintás nem jelentést indít)',
    file: 'lib/screens/community/private_messages_screen.dart',
    find: [
      '              PopupMenuItem(',
      "                value: 'report',",
    ],
    replace: [
      '              PopupMenuItem(',
      "                value: 'report-old',",
    ],
  },
  {
    name: 'a jelentés beküldése után AUTOMATIKUS blokkolás fut',
    file: 'lib/screens/community/private_messages_screen.dart',
    find: [
      '        reportedUserName: widget.otherUserName,',
      '      );',
      '      if (!mounted) return;',
    ],
    replace: [
      '        reportedUserName: widget.otherUserName,',
      '      );',
      '      await _service.blockUser(widget.otherUserId);',
      '      if (!mounted) return;',
    ],
  },
  {
    name: 'a gyors dátum-mentés a megjelenítés kapcsolójához is hozzányúl',
    file: 'lib/services/community_service.dart',
    find: [
      "      'birthDate': normalized,",
      "      'updatedAt': FieldValue.serverTimestamp(),",
      '    }, SetOptions(merge: true));',
      '    clearProfileCache(id);',
    ],
    replace: [
      "      'birthDate': normalized,",
      "      'birthDateVisible': true,",
      "      'updatedAt': FieldValue.serverTimestamp(),",
      '    }, SetOptions(merge: true));',
      '    clearProfileCache(id);',
    ],
  },
  // ---- 6. A szótár ---------------------------------------------------------
  {
    name: 'a szótárból eltűnik a „Születési dátum" kulcs',
    file: 'assets/i18n/en.json',
    find: ['  "Születési dátum": "Date of birth",'],
    replace: [''],
  },
];

// `--dry`: csak a horgonyokat ellenőrzi (nem futtat tesztet) — így a bizonyíték
// előtt látszik, ha egy minta elavult (a „nem találta" hamis képet adna).
if (process.argv.includes('--dry')) {
  let bad = 0;
  for (const mutation of MUTATIONS) {
    const source = fs.readFileSync(mutation.file, 'utf8');
    const find = mutation.find.join(eolOf(source));
    const hits = source.split(find).length - 1;
    if (hits !== 1) {
      bad += 1;
      console.log(`NEM MÉRHETŐ (${hits}×) — ${mutation.name}`);
    }
  }
  console.log(
    bad === 0
      ? `mind a ${MUTATIONS.length} horgony pontosan egyszer szerepel`
      : `${bad} horgony elavult`,
  );
  process.exit(bad === 0 ? 0 : 1);
}

const dartPass = () => {
  try {
    execFileSync('flutter', ['test', ...DART_TESTS], { stdio: 'pipe', shell: true });
    return true;
  } catch {
    return false;
  }
};

const serverPass = () => {
  try {
    // ⚠️ `shell` NÉLKÜL: a `shell: true` + argumentumok a Node DEP0190
    // figyelmeztetését írja a stderr-re, amit a PowerShell hibaként lát, és a
    // bizonyíték kilépési kódja hamisan 1 lenne.
    execFileSync('node', ['--test', 'functions/birth-date-plan.test.cjs'], {
      stdio: 'pipe',
    });
    return true;
  } catch {
    return false;
  }
};

const gatesPass = () => {
  const dart = dartPass();
  const server = serverPass();
  return { dart, server, ok: dart && server };
};

console.log('--- kiinduló állapot ---');
const baseline = gatesPass();
console.log(
  `a kapuk a kiinduló állapotban: Dart=${baseline.dart ? 'ZÖLD' : 'BUKIK'}, ` +
    `szerver=${baseline.server ? 'ZÖLD' : 'BUKIK'}`,
);
if (!baseline.ok) {
  console.log('⚠️ A kiinduló állapot nem zöld — a bizonyíték így nem értelmezhető.');
  process.exitCode = 1;
} else {
  const results = [];
  for (const mutation of MUTATIONS) {
    const source = fs.readFileSync(mutation.file, 'utf8');
    const eol = eolOf(source);
    const find = mutation.find.join(eol);
    const hits = source.split(find).length - 1;
    if (hits !== 1) {
      results.push('NEM MÉRHETŐ');
      console.log(
        `\n${mutation.name}\n  NEM MÉRHETŐ — a minta ${hits}× szerepel (1 kell)`,
      );
      continue;
    }
    const mutated = source.replace(find, mutation.replace.join(eol));
    if (mutated === source) {
      results.push('NEM MÉRHETŐ');
      console.log(`\n${mutation.name}\n  NEM MÉRHETŐ — a csere nem változtatott`);
      continue;
    }
    fs.writeFileSync(mutation.file, mutated, 'utf8');
    const caught = gatesPass();
    fs.writeFileSync(mutation.file, source, 'utf8');
    const restored = fs.readFileSync(mutation.file, 'utf8') === source;
    const caughtText = caught.ok
      ? 'NEM KAPTA EL'
      : `ELKAPVA (Dart=${caught.dart ? 'zöld' : 'bukik'}, szerver=${caught.server ? 'zöld' : 'bukik'})`;
    results.push(caught.ok ? 'NEM KAPTA EL' : 'ELKAPVA');
    console.log(
      `\n${mutation.name}\n  ${caughtText}${restored ? '' : ' — ⚠️ a visszaállítás nem bájtazonos!'}`,
    );
  }

  console.log('\n--- helyreállított állapot ---');
  const restored = gatesPass();
  console.log(
    `a kapuk a helyreállítás után: Dart=${restored.dart ? 'ZÖLD' : 'BUKIK'}, ` +
      `szerver=${restored.server ? 'ZÖLD' : 'BUKIK'}`,
  );

  const caught = results.filter((value) => value === 'ELKAPVA').length;
  const missed = results.filter((value) => value !== 'ELKAPVA').length;
  console.log(`\nösszesítés: ${caught}/${MUTATIONS.length} elkapva, ${missed} nem`);
  console.log(`eredmény: ${missed === 0 && restored.ok ? 'MINDEN MUTÁCIÓ ELKAPVA' : 'HIÁNYOS'}`);
  if (missed !== 0 || !restored.ok) process.exitCode = 1;
}
