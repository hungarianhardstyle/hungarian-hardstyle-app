import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';
import 'package:hungarian_hardstyle_app/widgets/profile_access_gate.dart';

Widget gate(
  Stream<ProfileAccessState> profile, {
  Future<void> Function()? onServerProfileMissing,
}) => MaterialApp(
  home: ProfileAccessGate(
    uid: 'uid-a',
    profile: profile,
    completion: const Scaffold(body: Text('Profil befejezése')),
    onServerProfileMissing: onServerProfileMissing,
    child: const Scaffold(body: Text('Privát tartalom')),
  ),
);

class _MountProbe extends StatefulWidget {
  const _MountProbe(this.onMount);
  final VoidCallback onMount;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Friss app'));
}

void main() {
  testWidgets('profile gate shows loading before a server result', (
    tester,
  ) async {
    await tester.pumpWidget(gate(const Stream<ProfileAccessState>.empty()));
    expect(find.text('Betöltés…'), findsOneWidget);
  });

  testWidgets('profile gate shows incomplete profile after it is loaded', (
    tester,
  ) async {
    final stream = StreamController<ProfileAccessState>();
    addTearDown(stream.close);
    await tester.pumpWidget(gate(stream.stream));
    stream.add(
      const ProfileAccessState({'displayName': '', 'role': 'partygoer'}),
    );
    await tester.pump();
    expect(find.text('Profil befejezése'), findsOneWidget);
    expect(find.text('Privát tartalom'), findsNothing);
  });

  testWidgets('a teljes profilra nyíló kapu friss app-fát épít', (tester) async {
    final stream = StreamController<ProfileAccessState>();
    addTearDown(stream.close);
    var mounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileAccessGate(
          uid: 'uid-a',
          profile: stream.stream,
          completion: const Scaffold(body: Text('Profil befejezése')),
          child: _MountProbe(() => mounts += 1),
        ),
      ),
    );
    stream.add(const ProfileAccessState({'displayName': '', 'role': 'partygoer'}));
    await tester.pump();
    expect(mounts, 0);

    stream.add(const ProfileAccessState({'displayName': 'Azonnali Név', 'role': 'partygoer'}));
    await tester.pump();
    await tester.pump();
    expect(mounts, 1);
    expect(find.text('Friss app'), findsOneWidget);
  });

  testWidgets('cached incomplete profile remains editable instead of loading', (
    tester,
  ) async {
    final stream = StreamController<ProfileAccessState>();
    addTearDown(stream.close);
    await tester.pumpWidget(gate(stream.stream));
    stream.add(
      const ProfileAccessState({
        'displayName': '',
        'role': 'partygoer',
      }, fromCache: true),
    );
    await tester.pump();
    expect(find.text('Profil befejezése'), findsOneWidget);
    expect(find.text('Betöltés…'), findsNothing);
  });

  testWidgets('profile gate keeps errors separate and unlocks complete data', (
    tester,
  ) async {
    final error = StreamController<ProfileAccessState>();
    addTearDown(error.close);
    await tester.pumpWidget(gate(error.stream));
    error.addError(StateError('offline'));
    await tester.pump();
    expect(find.textContaining('nem tölthető be'), findsOneWidget);

    final complete = StreamController<ProfileAccessState>();
    addTearDown(complete.close);
    await tester.pumpWidget(
      KeyedSubtree(key: UniqueKey(), child: gate(complete.stream)),
    );
    complete.add(
      const ProfileAccessState({
        'displayName': 'Tesztelő',
        'role': 'partygoer',
      }),
    );
    await tester.pump();
    expect(find.text('Privát tartalom'), findsOneWidget);
  });

  testWidgets('uncached missing profile probes Auth, cached missing does not', (
    tester,
  ) async {
    final stream = StreamController<ProfileAccessState>();
    addTearDown(stream.close);
    var probes = 0;
    await tester.pumpWidget(
      gate(stream.stream, onServerProfileMissing: () async => probes++),
    );
    stream.add(const ProfileAccessState(null, fromCache: true));
    await tester.pump();
    await tester.pump();
    expect(probes, 0);
    stream.add(const ProfileAccessState(null));
    await tester.pump();
    await tester.pump();
    expect(probes, 1);
  });

  testWidgets(
    'Google Auth claim profile readback gate and navigation survive reordered responses',
    (tester) async {
      final original = StreamController<ProfileAccessState>();
      final replacement = StreamController<ProfileAccessState>.broadcast();
      final authRefresh = ValueNotifier<Stream<ProfileAccessState>>(
        original.stream,
      );
      addTearDown(original.close);
      addTearDown(replacement.close);
      addTearDown(authRefresh.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<Stream<ProfileAccessState>>(
            valueListenable: authRefresh,
            builder: (_, profile, _) => ProfileAccessGate(
              uid: 'uid-a',
              profile: profile,
              completion: const Scaffold(body: Text('Profil befejezése')),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        const Text('Kezdőlap'),
                        FilledButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const Scaffold(body: Text('Használható app')),
                            ),
                          ),
                          child: const Text('Tovább'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      original.add(const ProfileAccessState(null, fromCache: true));
      await tester.pump();

      // Firebase Auth can emit the same user again while the initial server
      // profile is still pending. The gate must keep that pending listener.
      authRefresh.value = replacement.stream;
      await tester.pump();

      final storedProfile = <String, dynamic>{};
      final bootstrap = await bootstrapGoogleProfile(
        existingProfile: const {},
        requestedDisplayName: null,
        googleDisplayName: 'Google Tesztelő',
        role: 'partygoer',
        claimDisplayName: (name) async {
          storedProfile['displayName'] = name;
        },
        saveAndReadProfile: (role) async {
          storedProfile['role'] = role;
          return Map<String, dynamic>.from(storedProfile);
        },
      );
      expect(bootstrap, GoogleProfileBootstrapStatus.saved);
      expect(storedProfile, {
        'displayName': 'Google Tesztelő',
        'role': 'partygoer',
      });
      original.add(
        ProfileAccessState(Map<String, dynamic>.from(storedProfile)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Kezdőlap'), findsOneWidget);
      expect(find.text('Betöltés…'), findsNothing);
      await tester.tap(find.text('Tovább'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Használható app'), findsOneWidget);

      final restarted = StreamController<ProfileAccessState>();
      addTearDown(restarted.close);
      await tester.pumpWidget(
        KeyedSubtree(key: UniqueKey(), child: gate(restarted.stream)),
      );
      restarted.add(
        ProfileAccessState(Map<String, dynamic>.from(storedProfile)),
      );
      await tester.pump();
      expect(find.text('Privát tartalom'), findsOneWidget);
      expect(find.text('Profil befejezése'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'invalid Google name keeps completion open and a manual claim unlocks it',
    (tester) async {
      final profiles = StreamController<ProfileAccessState>();
      addTearDown(profiles.close);
      await tester.pumpWidget(gate(profiles.stream));

      final storedProfile = <String, dynamic>{};
      final automatic = await bootstrapGoogleProfile(
        existingProfile: const {},
        requestedDisplayName: null,
        googleDisplayName: 'google.user@example.com',
        role: 'partygoer',
        claimDisplayName: (_) async => fail('invalid name must not be claimed'),
        saveAndReadProfile: (_) async => fail('invalid name must not be saved'),
      );
      expect(automatic, GoogleProfileBootstrapStatus.invalidName);
      profiles.add(const ProfileAccessState({}));
      await tester.pump();
      expect(find.text('Profil befejezése'), findsOneWidget);

      final manual = await bootstrapGoogleProfile(
        existingProfile: const {},
        requestedDisplayName: 'Saját Név',
        googleDisplayName: 'google.user@example.com',
        role: 'partygoer',
        claimDisplayName: (name) async {
          storedProfile['displayName'] = name;
        },
        saveAndReadProfile: (role) async {
          storedProfile['role'] = role;
          return Map<String, dynamic>.from(storedProfile);
        },
      );
      expect(manual, GoogleProfileBootstrapStatus.saved);
      profiles.add(ProfileAccessState(storedProfile));
      await tester.pump();
      await tester.pump();
      expect(find.text('Privát tartalom'), findsOneWidget);
      expect(find.text('Profil befejezése'), findsNothing);
    },
  );
}
