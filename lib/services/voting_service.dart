import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wordpress_service.dart';
import '../core/firebase/firebase_callable.dart';

class VotingStatus {
  final Set<String> votedCategories;
  final Map<String, Set<int>> selectedCandidateIds;

  const VotingStatus({
    required this.votedCategories,
    required this.selectedCandidateIds,
  });
}

class VotingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _deviceIdKey = 'huhs_voting_device_id_v1';
  static const _voteStatusCachePrefix = 'huhs_voting_status_v1_';
  static const _secureStorage = FlutterSecureStorage();

  Future<User> _voter() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  Future<String> _deviceId() async {
    final stored = (await _secureStorage.read(key: _deviceIdKey))?.trim();
    if (stored != null && RegExp(r'^[A-Za-z0-9_-]{24,128}$').hasMatch(stored)) {
      return stored;
    }
    final random = Random.secure();
    final value = List.generate(
      48,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    await _secureStorage.write(key: _deviceIdKey, value: value);
    return value;
  }

  Future<VotingStatus> votingStatus({required int seasonId}) async {
    await _voter();
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getVotingStatus',
      parameters: {'seasonId': seasonId, 'deviceId': await _deviceId()},
    );
    final data = result.data;
    final rawCategories = data['votedCategories'];
    final rawSelections = data['selectedCandidateIds'];
    final selections = <String, Set<int>>{};
    if (rawSelections is Map) {
      for (final entry in rawSelections.entries) {
        final rawIds = entry.value;
        if (rawIds is List) {
          selections['${entry.key}'] = rawIds
              .map((id) => int.tryParse('$id'))
              .whereType<int>()
              .where((id) => id > 0)
              .toSet();
        }
      }
    }
    return VotingStatus(
      votedCategories: rawCategories is List
          ? rawCategories.whereType<String>().toSet()
          : <String>{},
      selectedCandidateIds: selections,
    );
  }

  Future<Set<String>> votedCategories({required int seasonId}) async {
    final status = await votingStatus(seasonId: seasonId);
    return status.votedCategories;
  }

  /// Returns the last known status immediately while the server status loads.
  /// The cache is only a UI optimisation; submitting votes is still validated
  /// by the server.
  Future<Set<String>?> cachedVotedCategories({required int seasonId}) async {
    final status = await cachedVotingStatus(seasonId: seasonId);
    return status?.votedCategories;
  }

  Future<VotingStatus?> cachedVotingStatus({required int seasonId}) async {
    final raw = await _secureStorage.read(
      key: '$_voteStatusCachePrefix$seasonId',
    );
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return VotingStatus(
          votedCategories: decoded.whereType<String>().toSet(),
          selectedCandidateIds: const {},
        );
      }
      if (decoded is! Map) return null;
      final rawCategories = decoded['votedCategories'];
      final rawSelections = decoded['selectedCandidateIds'];
      final selections = <String, Set<int>>{};
      if (rawSelections is Map) {
        for (final entry in rawSelections.entries) {
          final rawIds = entry.value;
          if (rawIds is List) {
            selections['${entry.key}'] = rawIds
                .map((id) => int.tryParse('$id'))
                .whereType<int>()
                .where((id) => id > 0)
                .toSet();
          }
        }
      }
      return VotingStatus(
        votedCategories: rawCategories is List
            ? rawCategories.whereType<String>().toSet()
            : <String>{},
        selectedCandidateIds: selections,
      );
    } catch (_) {
      await _secureStorage.delete(key: '$_voteStatusCachePrefix$seasonId');
    }
    return null;
  }

  Future<void> cacheVotingStatus({
    required int seasonId,
    required VotingStatus status,
  }) async {
    final selections = <String, List<int>>{};
    for (final entry in status.selectedCandidateIds.entries) {
      final ids = entry.value.toList()..sort();
      selections[entry.key] = ids;
    }
    await _cacheStatus(
      seasonId: seasonId,
      votedCategories: status.votedCategories,
      selectedCandidateIds: selections,
    );
  }

  Future<void> cacheVotedCategories({
    required int seasonId,
    required Set<String> categories,
  }) async {
    await _cacheStatus(
      seasonId: seasonId,
      votedCategories: categories,
      selectedCandidateIds: const {},
    );
  }

  Future<void> _cacheStatus({
    required int seasonId,
    required Set<String> votedCategories,
    required Map<String, List<int>> selectedCandidateIds,
  }) async {
    final key = '$_voteStatusCachePrefix$seasonId';
    if (votedCategories.isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }
    final categories = votedCategories.toList()..sort();
    await _secureStorage.write(
      key: key,
      value: jsonEncode({
        'votedCategories': categories,
        'selectedCandidateIds': selectedCandidateIds,
      }),
    );
  }

  Future<void> submitVotes({
    required int seasonId,
    required String category,
    required List<int> candidateIds,
    required bool newsletterConsent,
    required WordpressService wordpress,
  }) async {
    await submitBallot(
      seasonId: seasonId,
      votes: <String, List<int>>{category: candidateIds},
      newsletterConsent: newsletterConsent,
      wordpress: wordpress,
    );
  }

  Future<void> submitBallot({
    required int seasonId,
    required Map<String, List<int>> votes,
    required bool newsletterConsent,
    required WordpressService wordpress,
  }) async {
    final user = await _voter();
    if (newsletterConsent &&
        !user.isAnonymous &&
        user.email != null &&
        user.email!.trim().isNotEmpty) {
      // A hírlevél-feliratkozás **soha nem viheti el a szavazatot**: ha a
      // hírlevél-szolgáltatás épp hibázik (vagy a régi, védelem nélküli
      // szerver rate limitel), a szavazat akkor is menjen be. A duplikált
      // megerősítő levelet a szerver oldali cím-várakozás fogja meg.
      try {
        await wordpress.subscribeNewsletter(email: user.email!, consent: true);
      } catch (_) {
        // szándékosan elnyeljük: a szavazat a fontos
      }
    }
    await callFirebaseCallable<void>(
      'submitVotingBallot',
      parameters: {
        'seasonId': seasonId,
        'deviceId': await _deviceId(),
        'votes': votes.map((key, value) => MapEntry(key, value)),
      },
    );
  }
}
