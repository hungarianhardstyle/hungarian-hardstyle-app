#!/usr/bin/env node
/**
 * A **nem fordított feliratok** javítása (2026-09-26, a tulajdonos jelzése:
 * *„itt maradt egy magyar szó"* — a „My purchased music" fejlécében
 * „11 letöltött zene").
 *
 * ⚠️ MIÉRT SZKRIPT ÉS NEM KÉZI SZERKESZTÉS: a `tmp/check-untranslated-ui.mjs`
 * **95** találatot adott; a javítás így **egy helyen, tételesen** van, a szkript
 * pedig minden cserénél **ellenőrzi, hogy a minta pontosan egyszer szerepel**
 * (ha nem, hibát ír ki a néma félrecserélés helyett). A fájlokat **Node** írja
 * UTF-8-ban (PowerShell-lel SOHA — lásd a korábbi dupla-kódolásokat).
 *
 * A sorvégek: a horgonyok a fájl **saját** sorvégével épülnek (`eolOf`), különben
 * a CRLF-es fájlokban „nem találom" lenne a hamis kép (ez már megtörtént egyszer).
 *
 * Használat:
 *   node tmp/fix-untranslated-ui.mjs A            # száraz futás
 *   node tmp/fix-untranslated-ui.mjs A --write    # írás
 */
import fs from 'node:fs';

/** A fájl saját sorvége (a horgonyok ehhez igazodnak). */
const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const FIXES = {
  /** A-csoport: a „Saját zenéim" lejátszó (a tulajdonos jelzése) + az ismétlés-címke. */
  A: [
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'tárhely-összegzés (kiadvány · tétel · méret)',
      find: [
        '                _storageBytes > 0',
        "                    ? '${visible.length} kiadvány · ${_queue.length} tétel · '",
        "                          '${_formatBytes(_storageBytes)} a készüléken'",
        "                    : '${visible.length} kiadvány · ${_queue.length} tétel',",
      ],
      replace: [
        '                _storageBytes > 0',
        "                    ? trArgs(context, '{releases} kiadvány · {tracks} tétel · {size} a készüléken', {",
        "                        'releases': '${visible.length}',",
        "                        'tracks': '${_queue.length}',",
        '                        \'size\': _formatBytes(_storageBytes),',
        '                      })',
        "                    : trArgs(context, '{releases} kiadvány · {tracks} tétel', {",
        "                        'releases': '${visible.length}',",
        "                        'tracks': '${_queue.length}',",
        '                      }),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: '„Folytatás: … — …-tól" sáv',
      find: [
        "                'Folytatás: ${entry.nowPlayingLabel} — '",
        "                '${playbackClock(point.positionMs)}-tól',",
      ],
      replace: [
        "                trArgs(context, 'Folytatás: {title} — {time}-tól', {",
        "                  'title': entry.nowPlayingLabel,",
        "                  'time': playbackClock(point.positionMs),",
        '                }),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'lejátszási lista száma (keverve / nincs letöltve)',
      find: [
        "                          '${entries.length} tétel'",
        "                          '${_shuffle ? ' · keverve' : ''}'",
        "                          '${pending > 0 ? ' · $pending nincs letöltve' : ''}',",
      ],
      replace: [
        "                          trArgs(context, '{n} tétel{suffix}', {",
        "                            'n': '${entries.length}',",
        "                            'suffix': _shuffle || pending > 0",
        "                                ? ' · ${_shuffle ? tr(context, 'keverve') : ''}'",
        "                                      '${pending > 0 ? trArgs(context, '{n} nincs letöltve', {'n': '$pending'}) : ''}'",
        "                                : '',",
        '                          }),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'kivett tételek jelzése',
      find: [
        "                            '$excludedCount tétel kivéve a listából — a kártyákon '",
        "                            'a lista ikonnal teheted vissza (a fájl megvan).',",
      ],
      replace: [
        '                            trArgs(',
        '                              context,',
        "                              '{n} tétel kivéve a listából — a kártyákon a lista ikonnal teheted vissza (a fájl megvan).',",
        "                              {'n': '$excludedCount'},",
        '                            ),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'a lejátszó második sora (EZ VOLT A TULAJDONOS JELZÉSE)',
      find: [
        "                            ? '${playbackPositionLabel(_cursor, _order.length)} · '",
        "                                  '${_downloaded.length} letöltve'",
        '                            : _downloaded.isEmpty',
        "                            ? tr(context, 'Előbb tölts le egy zenét')",
        "                            : '${_downloaded.length} letöltött zene',",
      ],
      replace: [
        '                            ? trArgs(',
        '                                context,',
        "                                '{position} · {n} letöltve',",
        '                                {',
        "                                  'position': playbackPositionLabel(",
        '                                    _cursor,',
        '                                    _order.length,',
        '                                  ),',
        "                                  'n': '${_downloaded.length}',",
        '                                },',
        '                              )',
        '                            : _downloaded.isEmpty',
        "                            ? tr(context, 'Előbb tölts le egy zenét')",
        "                            : trArgs(context, '{n} letöltött zene', {",
        "                                'n': '${_downloaded.length}',",
        '                              }),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'kiadvány-azonosító a betöltő kártyán',
      find: ["          subtitle: Text('Azonosító: ${item.releaseId}'),"],
      replace: [
        "          subtitle: Text(trArgs(context, 'Azonosító: {id}', {'id': '${item.releaseId}'})),",
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'letöltés-folyamatjelzés',
      find: ["                      ? 'Letöltés… ${(progress * 100).round()}%'"],
      replace: [
        "                      ? trArgs(context, 'Letöltés… {n}%', {",
        "                          'n': '${(progress * 100).round()}',",
        '                        })',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'ismétlés-gomb tooltipje (a szolgáltatás magyar feliratot ad)',
      find: ['                  tooltip: playbackRepeatLabel(_repeat),'],
      replace: ['                  tooltip: tr(context, playbackRepeatLabel(_repeat)),'],
    },
  ],

  /**
   * B-csoport: közösségi + admin képernyők. A `_message(...)` hívások **async**
   * törzsben, await UTÁN futnak, ezért itt **`AppStrings.trArgs`** a helyes út
   * (a `context`-es `trArgs` `use_build_context_synchronously` figyelmeztetést
   * adna) — a `build`-en belüli helyeken viszont `tr(context, …)`.
   */
  B: [
    // --- lib/screens/community/wordpress_admin_screen.dart (11 hibaüzenet) ---
    ...[
      ['A push nem sikerült', '_errorText'],
      ['A művelet nem sikerült', '_errorText'],
      ['A mentés nem sikerült', '_errorText'],
      ['A szerkesztés nem sikerült', '_errorText'],
      ['A létrehozás nem sikerült', '_errorText'],
      ['A felhasználó mentése nem sikerült', '_errorText'],
      ['A felhasználó törlése nem sikerült', '_errorText'],
      ['A törlés nem sikerült', '_errorText'],
      ['A lomtár ürítése nem sikerült', '_errorText'],
      ['A visszaállítás nem sikerült', '_errorText'],
    ].map(([text, helper]) => ({
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: `hibaüzenet: ${text}`,
      hits: text === 'A mentés nem sikerült' ? 2 : 1,
      find: [`      _message('${text}: \${${helper}(error)}');`],
      replace: [
        `      _message(AppStrings.trArgs('${text}: {error}', {'error': ${helper}(error)}));`,
      ],
    })),
    {
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: 'indítási kép törölve/mentve',
      find: [
        '      _message(',
        "        imageUrl.isEmpty ? 'Indítási kép törölve.' : AppStrings.tr('Indítási kép mentve.'),",
        '      );',
      ],
      replace: [
        '      _message(',
        '        imageUrl.isEmpty',
        "            ? AppStrings.tr('Indítási kép törölve.')",
        "            : AppStrings.tr('Indítási kép mentve.'),",
        '      );',
      ],
    },
    {
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: 'indítási kép mentési hiba (régi plugin tippel)',
      find: [
        '      _message(',
        "        'Az indítási kép mentése nem sikerült: '",
        "        '${message.contains('Ismeretlen admin művelet') ? 'a HUHS Mobile API 2.4.32 feltöltése szükséges.' : message}',",
        '      );',
      ],
      replace: [
        '      _message(',
        "        AppStrings.trArgs('Az indítási kép mentése nem sikerült: {detail}', {",
        "          'detail': message.contains('Ismeretlen admin művelet')",
        "              ? AppStrings.tr('a HUHS Mobile API 2.4.32 feltöltése szükséges.')",
        '              : message,',
        '        }),',
        '      );',
      ],
    },
    {
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: 'játék-sor összegzése (beküldések / helyes válaszok)',
      find: [
        '                  subtitle: Text(',
        "                    '${game['type_label'] ?? tr(context, 'Játék')}  •  $status\\n'",
        "                    'Beküldések: ${game['submissions'] ?? 0}  •  '",
        "                    'Helyes válaszok: ${game['correct_answers'] ?? 0}/'",
        "                    '${game['total_answers'] ?? 0}',",
        '                  ),',
      ],
      replace: [
        '                  subtitle: Text(',
        '                    trArgs(',
        '                      context,',
        "                      '{type}  •  {status}\\nBeküldések: {submissions}  •  Helyes válaszok: {correct}/{total}',",
        '                      {',
        "                        'type': '${game['type_label'] ?? tr(context, 'Játék')}',",
        "                        'status': status,",
        "                        'submissions': '${game['submissions'] ?? 0}',",
        "                        'correct': '${game['correct_answers'] ?? 0}',",
        "                        'total': '${game['total_answers'] ?? 0}',",
        '                      },',
        '                    ),',
        '                  ),',
      ],
    },
    {
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: 'játék időszak/jutalom/kérdések sora',
      find: [
        '                  child: Text(',
        "                    'Időszak: ${_adminDate(game['start_at'])} – ${_adminDate(game['end_at'])}\\n'",
        "                    'Jutalom: ${game['reward_points'] ?? 0} pont  •  '",
        "                    'Kérdések: ${game['question_count'] ?? 0}  •  '",
        "                    'Idővonal-elemek: ${game['timeline_count'] ?? 0}',",
        '                    style: Theme.of(context).textTheme.bodySmall,',
        '                  ),',
      ],
      replace: [
        '                  child: Text(',
        '                    trArgs(',
        '                      context,',
        "                      'Időszak: {period}\\nJutalom: {reward} pont  •  Kérdések: {questions}  •  Idővonal-elemek: {timeline}',",
        '                      {',
        "                        'period':",
        "                            '${_adminDate(game['start_at'])} – ${_adminDate(game['end_at'])}',",
        "                        'reward': '${game['reward_points'] ?? 0}',",
        "                        'questions': '${game['question_count'] ?? 0}',",
        "                        'timeline': '${game['timeline_count'] ?? 0}',",
        '                      },',
        '                    ),',
        '                    style: Theme.of(context).textTheme.bodySmall,',
        '                  ),',
      ],
    },
    {
      file: 'lib/screens/community/wordpress_admin_screen.dart',
      note: 'adatlista betöltési hiba',
      find: [
        '                    child: Text(',
        "                      'Az adatok nem tölthetők be.\\n${_errorText(snapshot.error)}',",
        '                    ),',
      ],
      replace: [
        '                    child: Text(',
        "                      trArgs(context, 'Az adatok nem tölthetők be.\\n{error}', {",
        "                        'error': _errorText(snapshot.error),",
        '                      }),',
        '                    ),',
      ],
    },
    // --- lib/screens/community/admin_resource_editor_screen.dart ---
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'import: AppStrings (a _message hívásokhoz)',
      find: ["import '../../core/i18n/tr.dart';"],
      replace: [
        "import '../../core/i18n/app_strings.dart';",
        "import '../../core/i18n/tr.dart';",
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'létrehozva/mentve visszajelzés',
      find: [
        '      _message(',
        '        created',
        "            ? 'A(z) ${_label()} létrehozva.'",
        "            : 'A(z) ${_label()} mentve.',",
        '      );',
      ],
      replace: [
        '      _message(',
        '        created',
        "            ? AppStrings.trArgs('A(z) {label} létrehozva.', {'label': _label()})",
        "            : AppStrings.trArgs('A(z) {label} mentve.', {'label': _label()}),",
        '      );',
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'mentési hiba',
      find: ["      _message('A mentés nem sikerült: ${userFacingError(error)}');"],
      replace: [
        "      _message(AppStrings.trArgs('A mentés nem sikerült: {error}', {'error': userFacingError(error)}));",
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'szerkesztő cím (Új … / … szerkesztése)',
      find: [
        '        title: Text(',
        '          _isNew',
        "              ? 'Új ${_label().toLowerCase()}'",
        "              : '${_label()} szerkesztése',",
        '        ),',
      ],
      replace: [
        '        title: Text(',
        '          _isNew',
        "              ? trArgs(context, 'Új {label}', {'label': _label().toLowerCase()})",
        "              : trArgs(context, '{label} szerkesztése', {'label': _label()}),",
        '        ),',
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'mentés közbeni gombfelirat',
      find: ["              child: Text(_saving ? 'Mentés…' : tr(context, 'Mentés')),"],
      replace: ["              child: Text(_saving ? tr(context, 'Mentés…') : tr(context, 'Mentés')),"],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: '„azonnal megjelenik" súgó',
      find: [
        '                      child: Text(',
        "                        'A(z) ${_label().toLowerCase()} a mentés után azonnal '",
        "                        'megjelenik az appban (kivéve, ha piszkozatot választasz).',",
        '                        style: Theme.of(context).textTheme.bodySmall,',
        '                      ),',
      ],
      replace: [
        '                      child: Text(',
        '                        trArgs(',
        '                          context,',
        "                          'A(z) {label} a mentés után azonnal megjelenik az appban (kivéve, ha piszkozatot választasz).',",
        "                          {'label': _label().toLowerCase()},",
        '                        ),',
        '                        style: Theme.of(context).textTheme.bodySmall,',
        '                      ),',
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'létrehozás gombfelirat',
      find: ["                  label: Text(_isNew ? 'Létrehozás' : tr(context, 'Mentés')),"],
      replace: [
        "                  label: Text(_isNew ? tr(context, 'Létrehozás') : tr(context, 'Mentés')),",
      ],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'szám-mező súgó',
      find: ["              helperText: type == 'int' ? 'Szám' : null,"],
      replace: ["              helperText: type == 'int' ? tr(context, 'Szám') : null,"],
    },
    {
      file: 'lib/screens/community/admin_resource_editor_screen.dart',
      note: 'kérdés sorszáma',
      find: [
        '                  child: Text(',
        "                    '${index + 1}. kérdés',",
        '                    style: Theme.of(context).textTheme.titleSmall,',
        '                  ),',
      ],
      replace: [
        '                  child: Text(',
        "                    trArgs(context, '{n}. kérdés', {'n': '${index + 1}'}),",
        '                    style: Theme.of(context).textTheme.titleSmall,',
        '                  ),',
      ],
    },
    // --- lib/screens/community/community_screen.dart ---
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'bejelentés sora (bejegyzés + ok)',
      find: [
        '                              title: Text(',
        "                                'Bejegyzés: ${report.data()['postId'] ?? '-'}',",
        '                              ),',
        '                              subtitle: Text(',
        "                                'Ok: ${report.data()['reason'] ?? 'egyéb'}',",
        '                              ),',
      ],
      replace: [
        '                              title: Text(',
        "                                trArgs(context, 'Bejegyzés: {id}', {",
        "                                  'id': '${report.data()['postId'] ?? '-'}',",
        '                                }),',
        '                              ),',
        '                              subtitle: Text(',
        "                                trArgs(context, 'Ok: {reason}', {",
        "                                  'reason':",
        "                                      '${report.data()['reason'] ?? tr(context, 'egyéb')}',",
        '                                }),',
        '                              ),',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'regisztrált felhasználók száma',
      find: [
        '                title: Text(',
        "                  'Regisztrált felhasználók (${filteredProfiles.length})',",
        '                ),',
      ],
      replace: [
        '                title: Text(',
        "                  trArgs(context, 'Regisztrált felhasználók ({n})', {",
        "                    'n': '${filteredProfiles.length}',",
        '                  }),',
        '                ),',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'nem kattintható hivatkozások jelzése',
      find: [
        '        _showMessage(',
        "          'Néhány hivatkozás nem kattintható (csak adminnak/moderátornak jár).',",
        '        );',
      ],
      replace: [
        '        _showMessage(',
        "          AppStrings.tr('Néhány hivatkozás nem kattintható (csak adminnak/moderátornak jár).'),",
        '        );',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'Chat betöltési hiba (a dupla backslash is javul: valódi sortörés lesz)',
      find: [
        '                error: (error, _) => Center(',
        '                  child: Text(',
        "                    'A Chat nem érhető el.\\\\n${_chatError(error)}',",
        '                    textAlign: TextAlign.center,',
        '                  ),',
        '                ),',
      ],
      replace: [
        '                error: (error, _) => Center(',
        '                  child: Text(',
        "                    trArgs(context, 'A Chat nem érhető el.\\n{error}', {",
        "                      'error': _chatError(error),",
        '                    }),',
        '                    textAlign: TextAlign.center,',
        '                  ),',
        '                ),',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'profil-mentés hiba',
      find: ["        _message('A profil mentése sikertelen: ${_chatError(error)}');"],
      replace: [
        "        _message(AppStrings.trArgs('A profil mentése sikertelen: {error}', {'error': _chatError(error)}));",
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'Google-bejelentkezés hiba',
      find: ["      _message('Google-bejelentkezés nem sikerült: ${_chatError(error)}');"],
      replace: [
        "      _message(AppStrings.trArgs('Google-bejelentkezés nem sikerült: {error}', {'error': _chatError(error)}));",
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'profil-törlés hiba',
      find: [
        '                                                  _message(',
        "                                                    'A profil törlése sikertelen: ${_chatError(error)}',",
        '                                                  );',
      ],
      replace: [
        '                                                  _message(',
        "                                                    AppStrings.trArgs('A profil törlése sikertelen: {error}', {",
        "                                                      'error': _chatError(error),",
        '                                                    }),',
        '                                                  );',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'regisztráció gombfelirat',
      find: [
        '                                child: Text(',
        "                                  _register ? 'Regisztráció' : tr(context, 'Bejelentkezés'),",
        '                                ),',
      ],
      replace: [
        '                                child: Text(',
        "                                  _register",
        "                                      ? tr(context, 'Regisztráció')",
        "                                      : tr(context, 'Bejelentkezés'),",
        '                                ),',
      ],
    },
    // --- lib/screens/more/community_users_screen.dart ---
    {
      file: 'lib/screens/more/community_users_screen.dart',
      note: 'ismerősnek jelölés hiba',
      find: [
        '        SnackBar(',
        '          content: Text(',
        "            'Az ismerősnek jelölés nem sikerült.\\n${userFacingError(error)}',",
        '          ),',
        '        ),',
      ],
      replace: [
        '        SnackBar(',
        '          content: Text(',
        "            AppStrings.trArgs('Az ismerősnek jelölés nem sikerült.\\n{error}', {",
        "              'error': userFacingError(error),",
        '            }),',
        '          ),',
        '        ),',
      ],
    },
    {
      file: 'lib/screens/more/community_users_screen.dart',
      note: 'elfogadás/elutasítás hiba (2 helyen ugyanaz)',
      hits: 2,
      find: [
        '          content: Text(',
        '            accept',
        "                ? 'Az elfogadás nem sikerült.\\n${userFacingError(error)}'",
        "                : 'Az elutasítás nem sikerült.\\n${userFacingError(error)}',",
        '          ),',
      ],
      replace: [
        '          content: Text(',
        '            accept',
        "                ? AppStrings.trArgs('Az elfogadás nem sikerült.\\n{error}', {",
        "                    'error': userFacingError(error),",
        '                  })',
        "                : AppStrings.trArgs('Az elutasítás nem sikerült.\\n{error}', {",
        "                    'error': userFacingError(error),",
        '                  }),',
        '          ),',
      ],
    },
    {
      file: 'lib/screens/more/community_users_screen.dart',
      note: 'bejelentés adatai (bejelentő / jelentett / indok / bejegyzés)',
      find: [
        "                Text('Bejelentő: $reporter'),",
        '                Text(',
        "                  'Jelentett felhasználó: $liveName${reportedUserId.isEmpty ? '' : ' ($reportedUserId)'}',",
        '                ),',
        "                Text('Indok: $reason'),",
        "                if (postId.isNotEmpty) Text('Bejegyzés: $postId'),",
      ],
      replace: [
        "                Text(trArgs(context, 'Bejelentő: {name}', {'name': reporter})),",
        '                Text(',
        "                  trArgs(context, 'Jelentett felhasználó: {name}{id}', {",
        "                    'name': liveName,",
        "                    'id': reportedUserId.isEmpty ? '' : ' ($reportedUserId)',",
        '                  }),',
        '                ),',
        "                Text(trArgs(context, 'Indok: {reason}', {'reason': reason})),",
        "                if (postId.isNotEmpty)",
        "                  Text(trArgs(context, 'Bejegyzés: {id}', {'id': postId})),",
      ],
    },
    // --- lib/screens/community/prize_admin_screen.dart ---
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'állapot: „nyitott" nyers ág',
      find: ["  'open' => 'nyitott',"],
      replace: ["  'open' => AppStrings.tr('nyitott'),"],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'nyereményjáték betöltési hiba',
      find: [
        '            Text(',
        "              'A nyereményjáték adatait most nem sikerült betölteni.\\n${userFacingError(error)}',",
        '              textAlign: TextAlign.center,',
        '            ),',
      ],
      replace: [
        '            Text(',
        "              trArgs(context, 'A nyereményjáték adatait most nem sikerült betölteni.\\n{error}', {",
        "                'error': userFacingError(error),",
        '              }),',
        '              textAlign: TextAlign.center,',
        '            ),',
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'játék összegzése (állapot/játékosok/nyertes megjelenítése)',
      find: [
        '              child: Text(',
        "                'Állapot: ${summary.stateLabel}\\n'",
        "                'Játékosok: ${summary.players} · helyes válasz: ${summary.correctCount}\\n'",
        "                'Nyertes megjelenítése: '",
        "                '${summary.displayDays == 0 ? 'soha nem tűnik el' : '${summary.displayDays} nap'}',",
        '              ),',
      ],
      replace: [
        '              child: Text(',
        '                trArgs(',
        '                  context,',
        "                  'Állapot: {state}\\nJátékosok: {players} · helyes válasz: {correct}\\nNyertes megjelenítése: {display}',",
        '                  {',
        "                    'state': summary.stateLabel,",
        "                    'players': '${summary.players}',",
        "                    'correct': '${summary.correctCount}',",
        "                    'display': summary.displayDays == 0",
        "                        ? tr(context, 'soha nem tűnik el')",
        "                        : trArgs(context, '{n} nap', {",
        "                            'n': '${summary.displayDays}',",
        '                          }),',
        '                  },',
        '                ),',
        '              ),',
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'nyertes neve',
      find: ["              title: Text('Nyertes: ${summary.winnerName}'),"],
      replace: [
        "              title: Text(trArgs(context, 'Nyertes: {name}', {'name': summary.winnerName})),",
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'sorsolás időpontja',
      find: ["                    : 'Sorsolás: ${summary.winnerAt}',"],
      replace: [
        "                    : trArgs(context, 'Sorsolás: {date}', {",
        "                        'date': summary.winnerAt,",
        '                      }),',
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'résztvevők száma',
      find: [
        '        Text(',
        "          'Résztvevők (${summary.participants.length})',",
        '          style: const TextStyle(fontWeight: FontWeight.w600),',
        '        ),',
      ],
      replace: [
        '        Text(',
        "          trArgs(context, 'Résztvevők ({n})', {",
        "            'n': '${summary.participants.length}',",
        '          }),',
        '          style: const TextStyle(fontWeight: FontWeight.w600),',
        '        ),',
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'játék-sor címkéje (játékos-szám) + helyes válasz jelzés',
      find: [
        '                          game.label,',
      ],
      replace: [
        '                          trArgs(',
        '                            context,',
        "                            '{question} — {state} · {n} játékos',",
        '                            {',
        "                              'question': game.question,",
        "                              'state': game.stateLabel,",
        "                              'n': '${game.players}',",
        '                            },',
        '                          ),',
      ],
    },
    {
      file: 'lib/screens/community/prize_admin_screen.dart',
      note: 'helyes válasz jelzése a válasz mellett',
      find: ["                        answer.correct ? '${answer.label}  ✔ helyes' : answer.label,"],
      replace: [
        "                        answer.correct",
        "                            ? trArgs(context, '{answer}  ✔ helyes', {",
        "                                'answer': answer.label,",
        '                              })',
        '                            : answer.label,',
      ],
    },
    // --- lib/screens/community/private_messages_screen.dart ---
    {
      file: 'lib/screens/community/private_messages_screen.dart',
      note: 'válasz-előnézet a beviteli sávban',
      find: [
        '                            title: Text(',
        "                              'Válasz: \$_replyText',",
        '                              maxLines: 1,',
      ],
      replace: [
        '                            title: Text(',
        "                              trArgs(context, 'Válasz: {text}', {",
        "                                'text': _replyText,",
        '                              }),',
        '                              maxLines: 1,',
      ],
    },
  ],

  /** C-csoport: a többi képernyő és widget (mind `build`-en belül → `tr`/`trArgs`). */
  C: [
    {
      file: 'lib/screens/artists/artist_detail_screen.dart',
      note: 'DJ-adatlap betöltési hiba (névvel)',
      find: [
        '                  fallbackName.isEmpty',
        "                      ? tr(context, 'Nem sikerült betölteni a DJ-adatlapot.')",
        "                      : '$fallbackName adatlapját nem sikerült betölteni.',",
      ],
      replace: [
        '                  fallbackName.isEmpty',
        "                      ? tr(context, 'Nem sikerült betölteni a DJ-adatlapot.')",
        "                      : trArgs(context, '{name} adatlapját nem sikerült betölteni.', {",
        "                          'name': fallbackName,",
        '                        }),',
      ],
    },
    {
      file: 'lib/screens/artists/artist_detail_screen.dart',
      note: 'nincs összekapcsolt DJ-adatlap',
      find: [
        '            name.isEmpty',
        "                ? tr(context, 'Ehhez a fellépőhöz még nincs összekapcsolt DJ-adatlap.')",
        "                : '$name még nincs összekapcsolva egy DJ-adatlappal.',",
      ],
      replace: [
        '            name.isEmpty',
        "                ? tr(context, 'Ehhez a fellépőhöz még nincs összekapcsolt DJ-adatlap.')",
        "                : trArgs(context, '{name} még nincs összekapcsolva egy DJ-adatlappal.', {",
        "                    'name': name,",
        '                  }),',
      ],
    },
    {
      file: 'lib/screens/artists/artist_edit_screen.dart',
      note: 'mentés közbeni gombfelirat',
      find: ["            label: Text(_saving ? 'Mentés…' : tr(context, 'Mentés')),"],
      replace: [
        "            label: Text(_saving ? tr(context, 'Mentés…') : tr(context, 'Mentés')),",
      ],
    },
    {
      file: 'lib/screens/organizers/organizer_detail_screen.dart',
      note: 'szervezői adatlap betöltési hiba (névvel)',
      find: [
        '                  fallbackName.isEmpty',
        "                      ? tr(context, 'Nem sikerült betölteni a szervezői adatlapot.')",
        "                      : '$fallbackName adatlapját nem sikerült betölteni.',",
      ],
      replace: [
        '                  fallbackName.isEmpty',
        "                      ? tr(context, 'Nem sikerült betölteni a szervezői adatlapot.')",
        "                      : trArgs(context, '{name} adatlapját nem sikerült betölteni.', {",
        "                          'name': fallbackName,",
        '                        }),',
      ],
    },
    {
      file: 'lib/screens/organizers/organizer_detail_screen.dart',
      note: 'nincs összekapcsolt szervezői adatlap',
      find: [
        '            name.isEmpty',
        "                ? tr(context, 'Ehhez a szervezőhöz még nincs összekapcsolt adatlap.')",
        "                : '$name még nincs összekapcsolva egy szervezői adatlappal.',",
      ],
      replace: [
        '            name.isEmpty',
        "                ? tr(context, 'Ehhez a szervezőhöz még nincs összekapcsolt adatlap.')",
        "                : trArgs(context, '{name} még nincs összekapcsolva egy szervezői adatlappal.', {",
        "                    'name': name,",
        '                  }),',
      ],
    },
    {
      file: 'lib/screens/releases/release_detail_screen.dart',
      note: 'külső hivatkozás megnyitása gomb',
      find: [
        '                        child: Text(',
        "                          _externalLinkUnlocked ? 'Megnyitás' : tr(context, 'Feloldás'),",
        '                        ),',
      ],
      replace: [
        '                        child: Text(',
        '                          _externalLinkUnlocked',
        "                              ? tr(context, 'Megnyitás')",
        "                              : tr(context, 'Feloldás'),",
        '                        ),',
      ],
    },
    {
      file: 'lib/screens/releases/release_detail_screen.dart',
      note: 'Google Play vásárlás sora',
      find: [
        '          product?.description.isNotEmpty == true',
        '              ? product!.description',
        "              : 'Megvásárolható a Google Playen • ${configured.price} Ft',",
      ],
      replace: [
        '          product?.description.isNotEmpty == true',
        '              ? product!.description',
        "              : trArgs(context, 'Megvásárolható a Google Playen • {price} Ft', {",
        "                  'price': configured.price,",
        '                }),',
      ],
    },
    {
      file: 'lib/screens/events/event_detail_screen.dart',
      note: 'értékelések átlaga',
      find: [
        '                    Text(',
        "                      '\${average.toStringAsFixed(1)} / 5 (\$count értékelés)',",
        '                    ),',
      ],
      replace: [
        '                    Text(',
        "                      trArgs(context, '{avg} / 5 ({n} értékelés)', {",
        "                        'avg': average.toStringAsFixed(1),",
        "                        'n': '\$count',",
        '                      }),',
        '                    ),',
      ],
    },
    {
      file: 'lib/screens/events/event_meetup_screen.dart',
      note: 'érdeklődés visszavonása gomb',
      find: [
        '                                label: Text(',
        "                                  interested ? 'Visszavonás' : tr(context, 'Én is'),",
        '                                ),',
      ],
      replace: [
        '                                label: Text(',
        '                                  interested',
        "                                      ? tr(context, 'Visszavonás')",
        "                                      : tr(context, 'Én is'),",
        '                                ),',
      ],
    },
    {
      file: 'lib/screens/events/event_submission_screen.dart',
      note: 'küldés közbeni gombfelirat',
      find: [
        '                          label: Text(',
        "                            _isSubmitting ? 'Küldés…' : tr(context, 'Esemény elküldése'),",
        '                          ),',
      ],
      replace: [
        '                          label: Text(',
        '                            _isSubmitting',
        "                                ? tr(context, 'Küldés…')",
        "                                : tr(context, 'Esemény elküldése'),",
        '                          ),',
      ],
    },
    {
      file: 'lib/screens/genres/genre_discovery_screen.dart',
      note: 'műfaj-kapcsolódó tartalmak címe',
      find: [
        '              Text(',
        "                '\${widget.genre} – kapcsolódó tartalmak',",
        '                style: const TextStyle(',
      ],
      replace: [
        '              Text(',
        "                trArgs(context, '{genre} – kapcsolódó tartalmak', {",
        "                  'genre': widget.genre,",
        '                }),',
        '                style: const TextStyle(',
      ],
    },
    {
      file: 'lib/screens/more/about_screen.dart',
      note: 'diagnosztika futtatása közben',
      find: [
        '                  label: Text(',
        "                    _running ? 'Mérés…' : tr(context, 'Diagnosztika futtatása'),",
        '                  ),',
      ],
      replace: [
        '                  label: Text(',
        '                    _running',
        "                        ? tr(context, 'Mérés…')",
        "                        : tr(context, 'Diagnosztika futtatása'),",
        '                  ),',
      ],
    },
    {
      file: 'lib/screens/more/settings_screen.dart',
      note: 'Google Authenticator súgó',
      find: [
        '                        subtitle: const Text(',
        "                          'Csak e-mail/jelszavas fióknál használható',",
        '                        ),',
      ],
      replace: [
        '                        subtitle: const AppText(',
        "                          'Csak e-mail/jelszavas fióknál használható',",
        '                        ),',
      ],
    },
    {
      file: 'lib/screens/news/tagged_news_screen.dart',
      note: 'címke-hírek betöltési hiba',
      find: [
        '                    child: Text(',
        "                      'A címke hírei nem tölthetők be.\\n\$_error',",
        '                      textAlign: TextAlign.center,',
        '                    ),',
      ],
      replace: [
        '                    child: Text(',
        "                      trArgs(context, 'A címke hírei nem tölthetők be.\\n{error}', {",
        "                        'error': '\$_error',",
        '                      }),',
        '                      textAlign: TextAlign.center,',
        '                    ),',
      ],
    },
    {
      file: 'lib/screens/poll/poll_results_screen.dart',
      note: 'állapot: „nyitott" nyers ág (2 helyen)',
      hits: 2,
      find: [
        "  String get stateLabel => switch (state) {",
        "    'open' => 'nyitott',",
      ],
      replace: [
        '  String get stateLabel => switch (state) {',
        "    'open' => AppStrings.tr('nyitott'),",
      ],
    },
    {
      file: 'lib/screens/poll/poll_results_screen.dart',
      note: 'összesítő sora (állapot · szavazatok)',
      find: [
        '          Text(',
        "            'Állapot: \${summary.stateLabel} · összes szavazat: \${summary.total}',",
        '            style: Theme.of(context).textTheme.bodyMedium,',
        '          ),',
      ],
      replace: [
        '          Text(',
        "            trArgs(context, 'Állapot: {state} · összes szavazat: {n}', {",
        "              'state': summary.stateLabel,",
        "              'n': '\${summary.total}',",
        '            }),',
        '            style: Theme.of(context).textTheme.bodyMedium,',
        '          ),',
      ],
    },
    {
      file: 'lib/screens/poll/poll_results_screen.dart',
      note: 'szavazás sora (kérdés — állapot · szavazat)',
      find: ['                child: Text(poll.label, overflow: TextOverflow.ellipsis),'],
      replace: [
        '                child: Text(',
        '                  trArgs(',
        '                    context,',
        "                    '{question} — {state} · {n} szavazat',",
        '                    {',
        "                      'question': poll.question,",
        "                      'state': poll.stateLabel,",
        "                      'n': '\${poll.votes}',",
        '                    },',
        '                  ),',
        '                  overflow: TextOverflow.ellipsis,',
        '                ),',
      ],
    },
    {
      file: 'lib/screens/poll/poll_screen.dart',
      note: 'szavazás közbeni gombfelirat',
      find: ["            child: Text(_submitting ? 'Küldés…' : tr(context, 'Szavazok')),"],
      replace: [
        "            child: Text(_submitting ? tr(context, 'Küldés…') : tr(context, 'Szavazok')),",
      ],
    },
    {
      file: 'lib/screens/prize/prize_screen.dart',
      note: 'játék közbeni gombfelirat',
      find: ["            child: Text(_submitting ? 'Küldés…' : tr(context, 'Játszom')),"],
      replace: [
        "            child: Text(_submitting ? tr(context, 'Küldés…') : tr(context, 'Játszom')),",
      ],
    },
    {
      file: 'lib/screens/submissions/artist_submission_screen.dart',
      note: 'booking-tájékoztató',
      find: [
        '                        subtitle: const Text(',
        "                          'A booking levelek az info@hungarianhardstyle.hu címre érkeznek.',",
        '                        ),',
      ],
      replace: [
        '                        subtitle: const AppText(',
        "                          'A booking levelek az info@hungarianhardstyle.hu címre érkeznek.',",
        '                        ),',
      ],
    },
    {
      file: 'lib/screens/submissions/artist_submission_screen.dart',
      note: 'küldés közbeni gombfelirat',
      find: ["                        label: Text(_submitting ? 'Küldés…' : tr(context, 'DJ beküldése')),"],
      replace: [
        '                        label: Text(',
        '                          _submitting',
        "                              ? tr(context, 'Küldés…')",
        "                              : tr(context, 'DJ beküldése'),",
        '                        ),',
      ],
    },
    {
      file: 'lib/screens/submissions/organizer_submission_screen.dart',
      note: 'küldés közbeni gombfelirat',
      find: [
        '                          label: Text(',
        "                            _submitting ? 'Küldés…' : tr(context, 'Szervező beküldése'),",
        '                          ),',
      ],
      replace: [
        '                          label: Text(',
        '                            _submitting',
        "                                ? tr(context, 'Küldés…')",
        "                                : tr(context, 'Szervező beküldése'),",
        '                          ),',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'hiányzó kategóriák (snackbar)',
      find: [
        '          content: Text(',
        "            'Még hiányzik:\\n\${missing.map((category) => '\${category.label}: \${category.minVotes} választás').join('\\n')}',",
        '          ),',
      ],
      replace: [
        '          content: Text(',
        "            trArgs(context, 'Még hiányzik:\\n{list}', {",
        "              'list': missing",
        '                  .map(',
        '                    (category) => trArgs(',
        '                      context,',
        "                      '{label}: {n} választás',",
        "                      {'label': category.label, 'n': '\${category.minVotes}'},",
        '                    ),',
        '                  )',
        "                  .join('\\n'),",
        '            }),',
        '          ),',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'szavazás címe (évvel)',
      find: [
        '                season.title.isEmpty',
        "                    ? 'HUHS \${season.year} szavazás'",
        '                    : season.title,',
      ],
      replace: [
        '                season.title.isEmpty',
        "                    ? trArgs(context, 'HUHS {year} szavazás', {",
        "                        'year': '\${season.year}',",
        '                      })',
        '                    : season.title,',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'pontosan ennyi jelöltet válassz',
      find: [
        '            Text(',
        "              'Válassz pontosan \${category.minVotes} jelöltet (\${selected.length}/\${category.minVotes})',",
        '              style: Theme.of(context).textTheme.bodySmall,',
        '            ),',
      ],
      replace: [
        '            Text(',
        '              trArgs(',
        '                context,',
        "                'Válassz pontosan {min} jelöltet ({selected}/{min})',",
        '                {',
        "                  'min': '\${category.minVotes}',",
        "                  'selected': '\${selected.length}',",
        '                },',
        '              ),',
        '              style: Theme.of(context).textTheme.bodySmall,',
        '            ),',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'legfeljebb ennyi jelölt (snackbar)',
      find: [
        '                                  content: Text(',
        "                                    'Legfeljebb \${category.maxVotes} jelöltet választhatsz.',",
        '                                  ),',
      ],
      replace: [
        '                                  content: Text(',
        "                                    trArgs(context, 'Legfeljebb {n} jelöltet választhatsz.', {",
        "                                      'n': '\${category.maxVotes}',",
        '                                    }),',
        '                                  ),',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'hiányzó kategóriák felsorolása (a képernyőn)',
      find: [
        '              Text(',
        "                'A szavazás elküldéséhez minden kötelező kategóriát ki kell tölteni.\\n\\n\${missing.map((category) => '• \${category.label}: \${category.minVotes} jelölt').join('\\n')}',",
        '              )',
      ],
      replace: [
        '              Text(',
        '                trArgs(',
        '                  context,',
        "                  'A szavazás elküldéséhez minden kötelező kategóriát ki kell tölteni.\\n\\n{list}',",
        '                  {',
        "                    'list': missing",
        '                        .map(',
        '                          (category) => trArgs(',
        '                            context,',
        "                            '• {label}: {n} jelölt',",
        "                            {'label': category.label, 'n': '\${category.minVotes}'},",
        '                          ),',
        '                        )',
        "                        .join('\\n'),",
        '                  },',
        '                ),',
        '              )',
      ],
    },
    {
      file: 'lib/screens/voting/voting_screen.dart',
      note: 'kiválasztott külföldi DJ-k száma',
      find: [
        '          label: Text(',
        '            selected.isEmpty',
        "                ? tr(context, 'Külföldi DJ-k kiválasztása')",
        "                : '\${selected.length} kiválasztva',",
        '          ),',
      ],
      replace: [
        '          label: Text(',
        '            selected.isEmpty',
        "                ? tr(context, 'Külföldi DJ-k kiválasztása')",
        "                : trArgs(context, '{n} kiválasztva', {",
        "                    'n': '\${selected.length}',",
        '                  }),',
        '          ),',
      ],
    },
    {
      file: 'lib/screens/voting/voting_summary_screen.dart',
      note: 'összes leadott szavazat',
      find: [
        '                  Text(',
        "                    'Összes leadott szavazat: \${summary['totalVotes'] ?? 0}',",
        '                    style: Theme.of(context).textTheme.titleLarge,',
        '                  ),',
      ],
      replace: [
        '                  Text(',
        "                    trArgs(context, 'Összes leadott szavazat: {n}', {",
        "                      'n': '\${summary['totalVotes'] ?? 0}',",
        '                    }),',
        '                    style: Theme.of(context).textTheme.titleLarge,',
        '                  ),',
      ],
    },
    {
      file: 'lib/widgets/article_comments.dart',
      note: 'hozzászólás küldése közben',
      find: ["                label: Text(_sending ? 'Küldés…' : tr(context, 'Hozzászólok')),"],
      replace: [
        "                label: Text(_sending ? tr(context, 'Küldés…') : tr(context, 'Hozzászólok')),",
      ],
    },
    {
      file: 'lib/widgets/featured_news_card.dart',
      note: 'kiemelt hír jelvény',
      find: ["                        post.isSticky ? 'KIEMELT HÍR' : tr(context, 'FRISS HÍR'),"],
      replace: [
        '                        post.isSticky',
        "                            ? tr(context, 'KIEMELT HÍR')",
        "                            : tr(context, 'FRISS HÍR'),",
      ],
    },
    {
      file: 'lib/widgets/radio_player_bar.dart',
      note: 'rádió leállítása tooltip',
      find: ["              message: _playing ? 'Leállítás' : tr(context, 'Lejátszás'),"],
      replace: [
        '              message: _playing',
        "                  ? tr(context, 'Leállítás')",
        "                  : tr(context, 'Lejátszás'),",
      ],
    },
    {
      file: 'lib/widgets/post_shortcode_card.dart',
      note: 'kapcsolódó cikkek száma + rövidkód címkéje',
      find: [
        '        title: Text(shortcode.label),',
        '        subtitle: Text(',
        '          related.isEmpty',
        "              ? tr(context, 'Megnyitás az alkalmazásban')",
        "              : '\${related.length} kapcsolódó cikk',",
        '        ),',
      ],
      replace: [
        '        title: Text(tr(context, shortcode.label)),',
        '        subtitle: Text(',
        '          related.isEmpty',
        "              ? tr(context, 'Megnyitás az alkalmazásban')",
        "              : trArgs(context, '{n} kapcsolódó cikk', {",
        "                  'n': '\${related.length}',",
        '                }),',
        '        ),',
      ],
    },
    {
      file: 'lib/widgets/post_embed_card.dart',
      note: 'beágyazott tartalom megnyitása',
      find: ["        title: Text('\${_label(embed.type)} megnyitása'),"],
      replace: [
        "        title: Text(trArgs(context, '{label} megnyitása', {'label': _label(embed.type)})),",
      ],
    },
    {
      file: 'lib/widgets/news_reaction_button.dart',
      note: 'napi lájkpont-keret (snackbar) + import',
      find: ["import 'package:flutter/material.dart';"],
      replace: [
        "import 'package:flutter/material.dart';",
        '',
        "import '../core/i18n/tr.dart';",
      ],
    },
    {
      file: 'lib/widgets/news_reaction_button.dart',
      note: 'napi lájkpont-keret (snackbar)',
      find: [
        '          content: Text(',
        "            '\${_dailyPoints!.label} Hírek kedveléséért naponta '",
        "            '\${_dailyPoints!.limit} alkalommal jár pont.',",
        '          ),',
      ],
      replace: [
        '          content: Text(',
        "            trArgs(context, '{daily} Hírek kedveléséért naponta {n} alkalommal jár pont.', {",
        "              'daily': _dailyPoints!.label,",
        "              'n': '\${_dailyPoints!.limit}',",
        '            }),',
        '          ),',
      ],
    },
  ],

  /** D-csoport: a feliratot adó **modell/szolgáltatás** források. */
  /** E-csoport: a **tárolt** állapotüzenetek (a megjelenítés fordít) + tooltipek. */
  E: [
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: '_MessageBanner: a tárolt üzenet megjelenítéskor fordul',
      find: ['        Expanded(child: Text(message)),'],
      replace: ['        Expanded(child: Text(tr(context, message))),'],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: '_Notice: a cím és a törzs megjelenítéskor fordul',
      find: [
        '        Text(',
        '          title,',
        '          textAlign: TextAlign.center,',
        '          style: Theme.of(context).textTheme.titleMedium,',
        '        ),',
        '        const SizedBox(height: 8),',
        '        Text(body, textAlign: TextAlign.center),',
      ],
      replace: [
        '        Text(',
        '          tr(context, title),',
        '          textAlign: TextAlign.center,',
        '          style: Theme.of(context).textTheme.titleMedium,',
        '        ),',
        '        const SizedBox(height: 8),',
        '        Text(tr(context, body), textAlign: TextAlign.center),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: '„még nincs letöltve" üzenet (interpolált → sablon)',
      find: [
        '          () => _message =',
        "              'A(z) „${entry.nowPlayingLabel}\" még nincs letöltve — előbb '",
        "              'töltsd le, és utána játszható.',",
      ],
      replace: [
        '          () => _message = AppStrings.trArgs(',
        "              'A(z) „{title}\" még nincs letöltve — előbb töltsd le, és utána játszható.',",
        "              {'title': entry.nowPlayingLabel},",
        '            ),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'törlés-megerősítő szöveg (interpolált → sablon)',
      find: [
        "      'A(z) „${entry.nowPlayingLabel}\" letöltött fájlja törlődik. '",
        "          'A vásárlás megmarad, ezért bármikor újra letöltheted.',",
      ],
      replace: [
        '      AppStrings.trArgs(',
        "        'A(z) „{title}\" letöltött fájlja törlődik. A vásárlás megmarad, ezért bármikor újra letöltheted.',",
        "        {'title': entry.nowPlayingLabel},",
        '      ),',
      ],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'lejátszás/szünet tooltip (2 helyen)',
      hits: 2,
      find: ["? 'Szünet' : tr(context, 'Lejátszás'),"],
      replace: ["? tr(context, 'Szünet') : tr(context, 'Lejátszás'),"],
    },
    {
      file: 'lib/screens/more/my_music_screen.dart',
      note: 'keverés tooltip',
      find: ["? 'Keverés kikapcsolása' : tr(context, 'Keverés'),"],
      replace: ["? tr(context, 'Keverés kikapcsolása') : tr(context, 'Keverés'),"],
    },
    {
      file: 'lib/widgets/radio_player_bar.dart',
      note: 'némítás tooltip',
      find: ["? 'Némítás feloldása' : tr(context, 'Némítás'),"],
      replace: ["? tr(context, 'Némítás feloldása') : tr(context, 'Némítás'),"],
    },
  ],

  /** F-csoport: a kiadvány-adatlap **tárolt** állapotüzenetei. */
  F: [
    {
      file: 'lib/screens/releases/release_detail_screen.dart',
      note: 'a tárolt üzenet megjelenítéskor fordul (felső hely)',
      find: [
        '                    Text(',
        '                      _message!,',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
      replace: [
        '                    Text(',
        '                      tr(context, _message!),',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
    },
    {
      file: 'lib/screens/releases/release_detail_screen.dart',
      note: 'a tárolt üzenet megjelenítéskor fordul (Padding-os hely)',
      find: [
        '                    child: Text(',
        '                      _message!,',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
      replace: [
        '                    child: Text(',
        '                      tr(context, _message!),',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
    },
    ...[
      'A meglévő Google Play-vásárlás visszaállítása folyamatban van…',
      'A meglévő vásárlás visszaállításához be kell jelentkezni.',
      'A korábbi Google Play-vásárlások visszaállítása nem sikerült.',
      'A Play-termékazonosítók még nem érkeztek meg. Újrapróbálom automatikusan.',
      'A Google Play terméklista most nem tölthető be. Próbáld újra később.',
      'A Google Play Billing ezen az eszközön még nem adta vissza a kiadvány termékét. Újrapróbálom automatikusan.',
      'A Google Play Billing szolgáltatás még nem áll készen. Újrapróbálom automatikusan.',
      'A Google Play Billing lekérdezése nem adott vissza terméket. Újrapróbálom automatikusan.',
      'A vásárlás a Google Playből telepített alkalmazásban érhető el.',
      'A vásárláshoz előbb be kell jelentkezni.',
      'A Google Play vásárlási ablakát nem sikerült megnyitni.',
      'A Google Play vásárlás nem indítható el.',
      'A jutalmazott reklám betöltése…',
      'A jutalom jóváírása…',
      'A reklám jóváírásának ellenőrzése…',
      'A jutalom jóváírva. A letöltés indul…',
      'Az ingyenes külső link érvénytelen.',
      'A linket nem sikerült megnyitni.',
      'A letöltéshez be kell jelentkezni.',
    ].map((text) => ({
      file: 'lib/screens/releases/release_detail_screen.dart',
      note: `tárolt üzenet: ${text.slice(0, 40)}…`,
      find: [`'${text}'`],
      replace: [`AppStrings.tr('${text}')`],
    })),
  ],

  /** G-csoport: űrlap-ellenőrzők, egyedi üzenetek, egyéb feliratok. */
  G: [
    ...[
      ['lib/screens/events/event_submission_screen.dart', "? 'Kötelező mező.' : null"],
      ['lib/screens/submissions/artist_submission_screen.dart', "? 'Kötelező mező.' : null"],
      ['lib/screens/submissions/organizer_submission_screen.dart', "? 'Kötelező mező.' : null"],
    ].map(([file, anchor]) => ({
      file,
      note: 'kötelező mező üzenete',
      find: [anchor],
      replace: ["? AppStrings.tr('Kötelező mező.') : null"],
    })),
    ...(() => {
      // A hat ellenőrző üzenet **nem** egy folytonos blokkban van, ezért külön
      // cserékkel (a horgony a `return …;` rész, a behúzás nem számít).
      const pairs = [
        [
          "return '${field['label'] ?? key}: legalább $min érték kell.';",
          "return AppStrings.trArgs('{label}: legalább {min} érték kell.', {'label': '${field['label'] ?? key}', 'min': '$min'});",
        ],
        [
          "return '${field['label'] ?? key}: legfeljebb $max érték adható.';",
          "return AppStrings.trArgs('{label}: legfeljebb {max} érték adható.', {'label': '${field['label'] ?? key}', 'max': '$max'});",
        ],
        [
          "return 'Legalább 1 kérdés kell.';",
          "return AppStrings.tr('Legalább 1 kérdés kell.');",
        ],
        [
          "return 'A(z) $row. kérdés szövege üres.';",
          "return AppStrings.trArgs('A(z) {row}. kérdés szövege üres.', {'row': '$row'});",
        ],
        [
          "return 'A(z) $row. kérdéshez 2–6 válaszlehetőség kell.';",
          "return AppStrings.trArgs('A(z) {row}. kérdéshez 2–6 válaszlehetőség kell.', {'row': '$row'});",
        ],
        [
          "return 'A(z) $row. kérdésnél jelöld meg a helyes választ.';",
          "return AppStrings.trArgs('A(z) {row}. kérdésnél jelöld meg a helyes választ.', {'row': '$row'});",
        ],
      ];
      return pairs.map(([find, replace]) => ({
        file: 'lib/screens/community/admin_resource_editor_screen.dart',
        note: `ellenőrző üzenet: ${find.slice(8, 46)}`,
        find: [find],
        replace: [replace],
      }));
    })(),
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'reakció tooltip (a saját reakció)',
      find: ["tooltip: isMine ? 'Te reagáltál erre' : null,"],
      replace: ["tooltip: isMine ? tr(context, 'Te reagáltál erre') : null,"],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'profil-betöltési hiba megjelenítéskor fordul',
      find: ['                        Text(_profileError!),'],
      replace: ['                        Text(tr(context, _profileError!)),'],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'a SnackBar-üzenetek megjelenítéskor fordulnak (3 hely)',
      hits: 1,
      find: ['        SnackBar(content: Text(message)),'],
      replace: ['        SnackBar(content: Text(tr(context, message))),'],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'a SnackBar-üzenetek megjelenítéskor fordulnak (8 mp-es, 2 hely)',
      hits: 2,
      find: ['      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),'],
      replace: [
        '      SnackBar(',
        '        content: Text(tr(context, message)),',
        '        duration: const Duration(seconds: 8),',
        '      ),',
      ],
    },
    {
      file: 'lib/screens/community/community_screen.dart',
      note: 'a törlés-megerősítés szava is fordul (különben DELETE nem működne)',
      find: ["                                                                    'TÖRLÉS',"],
      replace: ["                                                                    tr(context, 'TÖRLÉS'),"],
    },
    {
      file: 'lib/screens/home/home_screen.dart',
      note: 'szavazás-ajánló a főoldalon',
      find: [": 'Szavazz a HUHS ${season.year} jelöltjeire',"],
      replace: [
        ": trArgs(context, 'Szavazz a HUHS {year} jelöltjeire', {",
        "                  'year': '${season.year}',",
        '                }),',
      ],
    },
    {
      file: 'lib/screens/more/about_screen.dart',
      note: 'diagnosztika hibaüzenete megjelenítéskor fordul',
      find: [
        '              Text(',
        '                _problem!,',
        '                style: const TextStyle(color: Color(0xFFFFB74D)),',
        '              ),',
      ],
      replace: [
        '              Text(',
        '                tr(context, _problem!),',
        '                style: const TextStyle(color: Color(0xFFFFB74D)),',
        '              ),',
      ],
    },
    {
      file: 'lib/screens/more/referral_screen.dart',
      note: 'ajánlószöveg (vágólap + megosztás)',
      find: [
        '  String _inviteText(String code) =>',
        "      'Csatlakozz a HUHS közösséghez! Regisztrálj az ajánlólinkkel: ${_inviteUrl(code)}';",
      ],
      replace: [
        '  String _inviteText(String code) => AppStrings.trArgs(',
        "    'Csatlakozz a HUHS közösséghez! Regisztrálj az ajánlólinkkel: {url}',",
        "    {'url': _inviteUrl(code)},",
        '  );',
      ],
    },
    {
      file: 'lib/screens/poll/poll_screen.dart',
      note: 'a kérdőív üzenete megjelenítéskor fordul',
      find: [
        '                    Text(',
        '                      _message!,',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
      replace: [
        '                    Text(',
        '                      tr(context, _message!),',
        '                      style: const TextStyle(color: Colors.white70),',
        '                    ),',
      ],
    },
    {
      file: 'lib/screens/prize/prize_screen.dart',
      note: 'a játék hibaüzenete megjelenítéskor fordul',
      find: [
        '          content: Text(',
        '            error is Exception',
        '                ? _readableError(error)',
        "                : AppStrings.tr('A játékot most nem sikerült rögzíteni. Próbáld újra.'),",
        '          ),',
      ],
      replace: [
        '          content: Text(',
        '            tr(context,',
        '                error is Exception',
        '                    ? _readableError(error)',
        "                    : 'A játékot most nem sikerült rögzíteni. Próbáld újra.'),",
        '          ),',
      ],
    },
    {
      file: 'lib/widgets/community_profile_form_fields.dart',
      note: 'profil-mentési hibák fordítása (import + 2 üzenet)',
      find: ["import '../core/i18n/tr.dart';"],
      replace: [
        "import '../core/i18n/app_strings.dart';",
        "import '../core/i18n/tr.dart';",
      ],
    },
    {
      file: 'lib/widgets/community_profile_form_fields.dart',
      note: 'profil-mentési hiba: érvénytelen név',
      find: [
        "      'AUTH/profile-invalid-display-name: Adj meg 2–40 karakteres, érvényes megjelenítési nevet.',",
      ],
      replace: [
        '      AppStrings.tr(',
        "        'AUTH/profile-invalid-display-name: Adj meg 2–40 karakteres, érvényes megjelenítési nevet.',",
        '      ),',
      ],
    },
    {
      file: 'lib/widgets/community_profile_form_fields.dart',
      note: 'profil-mentési hiba: a szerver nem igazolta vissza',
      find: [
        "      'AUTH/profile-save-not-confirmed: A profil mentését a szerver nem igazolta vissza. Próbáld újra.',",
      ],
      replace: [
        '      AppStrings.tr(',
        "        'AUTH/profile-save-not-confirmed: A profil mentését a szerver nem igazolta vissza. Próbáld újra.',",
        '      ),',
      ],
    },
  ],
  /** H-csoport: az e-mail-űrlapok (félkész üzenet a levelezőben) + meetup-felirat. */
  H: [
    {
      file: 'lib/screens/artists/artist_detail_screen.dart',
      note: 'booking-e-mail tárgya',
      find: ["      queryParameters: {'subject': 'Fellépés kérése – ${artist.title}'},"],
      replace: [
        '      queryParameters: {',
        "        'subject': trArgs(context, 'Fellépés kérése – {artist}', {",
        "          'artist': artist.title,",
        '        }),',
        '      },',
      ],
    },
    {
      file: 'lib/screens/more/more_screen.dart',
      note: 'hibajelentő e-mail tárgya és törzse',
      find: [
        "          'subject': 'Hibajelzés – Hungarian Hardstyle $version',",
        "          'body': 'App verzió: $version\\n\\nHiba leírása:\\n',",
      ],
      replace: [
        "          'subject': trArgs(",
        "            context,",
        "            'Hibajelzés – Hungarian Hardstyle {version}',",
        "            {'version': version},",
        '          ),',
        "          'body': trArgs(",
        '            context,',
        "            'App verzió: {version}\\n\\nHiba leírása:\\n',",
        "            {'version': version},",
        '          ),',
      ],
    },
    {
      file: 'lib/screens/events/event_meetup_screen.dart',
      note: 'érdeklődők száma a meetup-listában',
      find: ["                        subtitle: count == 0 ? 'Meetup' : '$count érdeklődő',"],
      replace: [
        '                        subtitle: count == 0',
        "                            ? 'Meetup'",
        "                            : trArgs(context, '{n} érdeklődő', {",
        "                                'n': '$count',",
        '                              }),',
      ],
    },
  ],
  D: [
    {
      file: 'lib/services/news_reaction_service.dart',
      note: 'napi lájkpont felirata (a snackbar beágyazza)',
      find: [
        "import '../core/firebase/firebase_callable.dart';",
      ],
      replace: [
        "import '../core/firebase/firebase_callable.dart';",
        "import '../core/i18n/app_strings.dart';",
      ],
    },
    {
      file: 'lib/services/news_reaction_service.dart',
      note: 'napi lájkpont felirata',
      find: [
        '  String get label => exhausted',
        "      ? 'A mai lájkpontod elfogyott.'",
        "      : 'Ma \$count/\$limit lájkpont jár.';",
      ],
      replace: [
        '  String get label => exhausted',
        "      ? AppStrings.tr('A mai lájkpontod elfogyott.')",
        "      : AppStrings.trArgs('Ma {count}/{limit} lájkpont jár.', {",
        "          'count': '\$count',",
        "          'limit': '\$limit',",
        '        });',
      ],
    },
    {
      file: 'lib/models/post.dart',
      note: 'rövidkód címkéi (a megjelenítés fordítja)',
      find: [
        "  String get label => switch (name.toLowerCase()) {",
        "    'ays_poll' => 'Interaktív szavazás',",
        "    'irp' => 'Kapcsolódó cikk',",
        "    'finaltilesgallery' => 'Képgaléria',",
        "    _ => 'Interaktív tartalom',",
        '  };',
      ],
      replace: [
        '  /// ⚠️ A címke **magyar kulcs**: a megjelenítés fordítja (`tr(context, …)`),',
        '  /// így nyelvváltáskor is átáll (a 2026-09-26-i kör mérése).',
        '  String get label => switch (name.toLowerCase()) {',
        "    'ays_poll' => 'Interaktív szavazás',",
        "    'irp' => 'Kapcsolódó cikk',",
        "    'finaltilesgallery' => 'Képgaléria',",
        "    _ => 'Interaktív tartalom',",
        '  };',
      ],
    },
  ],
};

/** A kért csoport(ok) összegyűjtése. */
const groups = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const write = process.argv.includes('--write');
if (!groups.length) {
  console.error('Add meg a csoportot (A, B, C …).');
  process.exit(2);
}

let applied = 0;
let failed = 0;
for (const group of groups) {
  const fixes = FIXES[group];
  if (!fixes) {
    console.error(`Ismeretlen csoport: ${group}`);
    process.exit(2);
  }
  const byFile = new Map();
  for (const fix of fixes) {
    if (!byFile.has(fix.file)) byFile.set(fix.file, []);
    byFile.get(fix.file).push(fix);
  }
  for (const [file, fileFixes] of byFile) {
    if (!fs.existsSync(file)) {
      console.error(`HIBA  nincs ilyen fájl: ${file}`);
      failed += fileFixes.length;
      continue;
    }
    let source = fs.readFileSync(file, 'utf8');
    const eol = eolOf(source);
    for (const fix of fileFixes) {
      const find = fix.find.join(eol);
      const replace = fix.replace.join(eol);
      const hits = source.split(find).length - 1;
      const expected = fix.hits ?? 1;
      if (hits !== expected) {
        console.error(
          `HIBA  ${file}: ${fix.note} — a minta ${hits}× szerepel (${expected} kell)`,
        );
        failed += 1;
        continue;
      }
      source = source.replaceAll(find, replace);
      applied += 1;
      console.log(`OK    ${file}: ${fix.note}`);
    }
    if (write) fs.writeFileSync(file, source, 'utf8');
  }
}

console.log(`\n${applied} csere rendben, ${failed} hiba${write ? ' — a fájlok kiírva' : ' — SZÁRAZ futás (--write a kiíráshoz)'}`);
process.exitCode = failed ? 1 : 0;
