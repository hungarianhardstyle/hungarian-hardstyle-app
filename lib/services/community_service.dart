import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

import '../models/community_post.dart';
import '../models/achievement.dart';
import '../models/artist_claim_status.dart';
import '../core/firebase/firebase_callable.dart';
import '../core/images/wordpress_image_url.dart';
import 'wordpress_service.dart';

class _AchievementCacheEntry {
  _AchievementCacheEntry(this.value) : fetchedAt = DateTime.now();

  final AchievementSummary value;
  final DateTime fetchedAt;

  bool get isFresh =>
      DateTime.now().difference(fetchedAt) <
      CommunityService._publicAchievementCacheTtl;
}

class _PublicProfileCacheEntry {
  _PublicProfileCacheEntry(this.data, this.exists) : fetchedAt = DateTime.now();

  final Map<String, dynamic> data;
  final bool exists;
  final DateTime fetchedAt;

  bool get isFresh =>
      DateTime.now().difference(fetchedAt) < CommunityService._publicCacheTtl;
}

class _AdminCacheEntry {
  _AdminCacheEntry(this.value) : fetchedAt = DateTime.now();

  final dynamic value;
  final DateTime fetchedAt;

  bool get isFresh =>
      DateTime.now().difference(fetchedAt) < CommunityService._adminCacheTtl;
}

class CloudinaryUploadResult {
  const CloudinaryUploadResult({required this.url, required this.publicId});

  final String url;
  final String publicId;
}

enum GoogleProfileBootstrapStatus { saved, missingName, invalidName, nameTaken }

bool _validProfileName(String value) =>
    value.length >= 2 &&
    value.length <= 40 &&
    !value.contains('@') &&
    RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} ._'-]*$", unicode: true).hasMatch(value);

@visibleForTesting
Future<GoogleProfileBootstrapStatus> bootstrapGoogleProfile({
  required Map<String, dynamic> existingProfile,
  required String? requestedDisplayName,
  required String? googleDisplayName,
  required String role,
  required Future<void> Function(String displayName) claimDisplayName,
  required Future<Map<String, dynamic>> Function(String role)
  saveAndReadProfile,
}) async {
  final savedName = (existingProfile['displayName'] as String? ?? '').trim();
  if (!_validProfileName(savedName)) {
    final candidate =
        (requestedDisplayName?.trim().isNotEmpty == true
                ? requestedDisplayName
                : googleDisplayName)
            ?.trim()
            .replaceAll(RegExp(r'\s+'), ' ');
    if (candidate == null || candidate.isEmpty) {
      return GoogleProfileBootstrapStatus.missingName;
    }
    if (!_validProfileName(candidate)) {
      return GoogleProfileBootstrapStatus.invalidName;
    }
    try {
      await claimDisplayName(candidate);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists') {
        return GoogleProfileBootstrapStatus.nameTaken;
      }
      rethrow;
    }
  }

  final stored = await saveAndReadProfile(role);
  final storedName = (stored['displayName'] as String? ?? '').trim();
  if (!_validProfileName(storedName) || stored['role'] != role) {
    throw StateError(
      'GOOGLE/profile-incomplete: A név vagy a szerepkör nem mentődött el. Próbáld újra.',
    );
  }
  return GoogleProfileBootstrapStatus.saved;
}

class CommunityService {
  static const _authChannel = MethodChannel('hu_hs/auth');
  static const _publicProfileCacheLimit = 128;
  static final Map<String, _PublicProfileCacheEntry> _publicProfileCache = {};
  static final Map<String, Future<_PublicProfileCacheEntry>>
  _publicProfileRequests = {};
  static final Map<String, Future<_PublicProfileCacheEntry>>
  _publicProfileRefreshRequests = {};
  static List<Map<String, dynamic>>? _publicProfilesCache;
  static Future<List<Map<String, dynamic>>>? _publicProfilesRequest;
  static int _publicProfilesEpoch = 0;
  static final Map<String, _AchievementCacheEntry> _publicAchievementCache = {};
  static final Map<String, Future<AchievementSummary>>
  _publicAchievementRequests = {};
  static final Map<String, Future<AchievementSummary>>
  _publicAchievementRefreshRequests = {};
  static final Map<String, DocumentSnapshot<Map<String, dynamic>>>
  _profileCache = {};
  static final Map<String, DateTime> _profileCacheFetchedAt = {};
  static final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _profileRefreshRequests = {};
  static final Map<String, int> _publicCacheEpochs = {};
  static int _publicCacheEpoch = 0;
  static final ValueNotifier<int> publicProfileRefreshGeneration =
      ValueNotifier<int>(0);
  static String? _publicCacheOwnerUid;
  // Keep the fast in-memory profile cache, but revisit it often enough for a
  // changed badge artwork/rank to become visible without a manual logout.
  // Persistent data is still rendered immediately and revalidated in the
  // background, so this does not turn profile rows into blocking requests.
  static const _publicCacheTtl = Duration(seconds: 30);
  static const _publicPersistentCacheTtl = Duration(hours: 24);
  static const _publicAchievementCacheTtl = Duration(minutes: 2);
  static const _profileCacheTtl = Duration(seconds: 30);
  static const _adminCacheTtl = Duration(seconds: 20);
  static final Map<String, _AdminCacheEntry> _adminCache = {};
  static final Map<String, Future<dynamic>> _adminRequests = {};
  static const cloudName = 'fjxo93em';
  static const uploadPreset = 'Hun_hs_Mobile';
  static const adminEmail = 'djdeeroy@gmail.com';
  static const firestoreDatabaseId = 'hungarian-hardstyle';
  static const accessNone = 'none';
  static const accessModerator = 'moderator';
  static const accessAdmin = 'admin';
  static const maxUploadBytes = 5 * 1024 * 1024;

  static bool isSupportedImageBytes(Uint8List bytes) {
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    final webp =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    return jpeg || png || webp;
  }

  static bool isSafeCloudinaryImageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'res.cloudinary.com' &&
        uri.path.startsWith('/fjxo93em/image/upload/');
  }

  static String? _biometricSessionUid;
  static Future<bool>? _biometricRequest;
  static String? _profileSessionUid;
  static Future<bool>? _profileUnlockRequest;
  static const _secureStorage = FlutterSecureStorage();
  static const _totpSecretKey = 'huhs_totp_secret';

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Dio _dio;
  String _cachedRole = '';
  String _cachedAccessRole = accessNone;
  String? _cachedRoleUid;
  String? _googleProfileCompletionNotice;
  String? _blockedUsersUid;
  Set<String> _blockedUserIds = <String>{};
  Future<Set<String>>? _blockedUsersRequest;

  CommunityService({FirebaseAuth? auth, FirebaseFirestore? firestore, Dio? dio})
    : auth = auth ?? FirebaseAuth.instance,
      firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: firestoreDatabaseId,
          ),
      _dio = dio ?? Dio();

  Future<User> ensureAnonymousUser() async {
    final current = auth.currentUser;
    if (current != null) return current;
    final credential = await auth.signInAnonymously();
    return credential.user!;
  }

  Stream<List<CommunityPost>> watchPosts() {
    return firestore
        .collection('live_feed_posts')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .asyncMap((snapshot) async {
          final blocked = await _loadBlockedUserIds();
          final posts = snapshot.docs.map(CommunityPost.fromDocument).toList();
          posts.removeWhere((post) => blocked.contains(post.authorId));
          posts.sort((a, b) {
            final pinOrder = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
            return pinOrder == 0
                ? b.createdAt.compareTo(a.createdAt)
                : pinOrder;
          });
          return posts;
        });
  }

  /// A chat **régebbi** üzenetei (lapozás).
  ///
  /// **A tulajdonos jelzése:** *„chaten kéne valami limit, … ha valaki vissza
  /// akar olvasni legyen valami lehetőség arra hogy lefele scrollozáskor
  /// töltsön be"*. Az élő ablak (`watchPosts`) csak a legfrissebb 60 üzenetet
  /// figyeli — ez a függvény teszi elérhetővé a régebbieket, egyszeri
  /// lekérdezéssel, hogy 5000 üzenetnél se legyen lassú.
  ///
  /// [before] előtti (szigorúan régebbi) üzeneteket ad vissza, a legfrissebbel
  /// kezdve. A tiltott felhasználók üzenetei itt is kimaradnak.
  Future<List<CommunityPost>> loadOlderPosts({
    required DateTime before,
    int limit = 30,
  }) async {
    final snapshot = await firestore
        .collection('live_feed_posts')
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final blocked = await _loadBlockedUserIds();
    final posts = snapshot.docs.map(CommunityPost.fromDocument).toList();
    posts.removeWhere((post) => blocked.contains(post.authorId));
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<Set<String>> _loadBlockedUserIds() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return Future.value(<String>{});
    if (_blockedUsersUid == user.uid && _blockedUsersRequest != null) {
      return _blockedUsersRequest!;
    }
    _blockedUsersUid = user.uid;
    final request = firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('blocked_users')
        .get()
        .then((snapshot) {
          _blockedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
          return _blockedUserIds;
        });
    _blockedUsersRequest = request;
    return request;
  }

  String privateConversationId(String firstUserId, String secondUserId) {
    final ids = [firstUserId, secondUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPrivateConversations() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return firestore
        .collection('private_conversations')
        .where('participantIds', arrayContains: user.uid)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPrivateMessages(
    String conversationId,
  ) {
    return firestore
        .collection('private_conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .limit(100)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPrivateConversation(
    String conversationId,
  ) {
    return firestore
        .collection('private_conversations')
        .doc(conversationId)
        .get();
  }

  Future<void> deletePrivateConversation(String conversationId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A beszélgetés törléséhez bejelentkezés szükséges.');
    }
    await callFirebaseCallable<void>(
      'deletePrivateConversation',
      parameters: {'conversationId': conversationId},
    );
  }

  Future<void> deletePrivateMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Az üzenet törléséhez bejelentkezés szükséges.');
    }
    await firestore
        .collection('private_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> editPrivateMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async {
    final user = auth.currentUser;
    final trimmed = maskProfanity(text.trim());
    if (user == null || user.isAnonymous) {
      throw StateError('Az üzenet szerkesztéséhez bejelentkezés szükséges.');
    }
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError('Az üzenet 1–2000 karakter lehet.');
    }
    await firestore
        .collection('private_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'text': trimmed});
  }

  Future<void> sendPrivateMessage({
    required String otherUserId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final user = auth.currentUser;
    final trimmed = maskProfanity(text.trim());
    if (user == null || user.isAnonymous) {
      throw StateError('Privát üzenet küldéséhez regisztráció szükséges.');
    }
    if (otherUserId.isEmpty || otherUserId == user.uid) {
      throw ArgumentError('Érvénytelen címzett.');
    }
    if (trimmed.isEmpty && imageBytes == null) {
      throw ArgumentError('Írj üzenetet vagy válassz egy képet.');
    }
    if (trimmed.length > 2000) {
      throw ArgumentError('Az üzenet 1–2000 karakter lehet.');
    }

    final blockedByMe = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('blocked_users')
        .doc(otherUserId)
        .get();
    // The recipient's blocked_users document is intentionally unreadable by
    // another user.  The Firestore message rule enforces the reverse-block
    // check server-side, so reading it here only caused permission-denied.
    if (blockedByMe.exists) {
      throw StateError(
        'A privát üzenetküldés ennél a felhasználónál nem érhető el.',
      );
    }

    final otherData = await getPublicProfile(otherUserId);
    if (otherData.isEmpty) throw StateError('A felhasználó nem található.');
    CloudinaryUploadResult? uploadedImage;
    final imageUrl = imageBytes == null
        ? ''
        : (uploadedImage = await uploadImageWithMetadata(
            imageBytes,
            filename: imageFilename?.trim().isNotEmpty == true
                ? imageFilename!.trim()
                : 'private-message.jpg',
            userScoped: true,
          )).url;
    final ownProfile = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final ownData = ownProfile.data() ?? const <String, dynamic>{};
    final conversationId = privateConversationId(user.uid, otherUserId);
    final conversation = firestore
        .collection('private_conversations')
        .doc(conversationId);
    await conversation.set({
      'participantIds': [user.uid, otherUserId]..sort(),
      'participantNames': {
        user.uid:
            (ownData['displayName'] as String? ??
            user.displayName ??
            'HUHS user'),
        otherUserId: otherData['displayName'] as String? ?? 'HUHS user',
      },
      'lastMessage': trimmed.isEmpty ? 'Kép' : trimmed,
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await conversation.collection('messages').add({
      'senderId': user.uid,
      'recipientId': otherUserId,
      'text': trimmed,
      'imageUrl': imageUrl,
      if (uploadedImage?.publicId.isNotEmpty == true)
        'imagePublicId': uploadedImage!.publicId,
      'createdAt': FieldValue.serverTimestamp(),
      if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty)
        'replyToMessageId': replyToMessageId.trim(),
      if (replyToText != null && replyToText.trim().isNotEmpty)
        'replyToText': replyToText.trim().substring(
          0,
          replyToText.trim().length > 200 ? 200 : replyToText.trim().length,
        ),
    });
  }

  Future<void> togglePrivateMessageReaction({
    required String conversationId,
    required String messageId,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A reakcióhoz bejelentkezés szükséges.');
    }
    await callFirebaseCallable<void>(
      'togglePrivateMessageReaction',
      parameters: {'conversationId': conversationId, 'messageId': messageId},
    );
  }

  Future<void> rateEvent({required int eventId, required int score}) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Az értékeléshez regisztráció szükséges.');
    }
    await callFirebaseCallable<void>(
      'rateEvent',
      parameters: {'eventId': eventId, 'score': score},
    );
  }

  Future<Map<String, dynamic>> getEventRating(int eventId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const {};
    final snapshot = await firestore
        .collection('event_ratings')
        .doc('$eventId')
        .collection('users')
        .get();
    var total = 0;
    var count = 0;
    int? myScore;
    for (final doc in snapshot.docs) {
      final score = (doc.data()['score'] as num?)?.toInt();
      if (score == null || score < 1 || score > 5) continue;
      total += score;
      count++;
      if (doc.id == user.uid) myScore = score;
    }
    return {
      'count': count,
      'average': count == 0 ? 0.0 : total / count,
      'myScore': myScore,
    };
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
    Map<String, String>? socialLinks,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    var createdNow = false;
    var resumedPartialAccount = false;
    String? verificationWarning;
    try {
      _authStage('pre_auth_check');
      await callFirebaseCallable<void>(
        'checkRegistrationEligibility',
        parameters: {'email': normalizedEmail},
      );
      // This avoids creating Auth for a known-taken name. The atomic claim
      // below remains authoritative because the name can change meanwhile.
      await checkDisplayNameAvailability(displayName);
      final current = auth.currentUser;
      final emailCredential = EmailAuthProvider.credential(
        email: normalizedEmail,
        password: password,
      );
      final resumesExistingSession =
          current != null &&
          !current.isAnonymous &&
          normalizedEmail == (current.email ?? '').trim().toLowerCase();
      late final User user;
      if (resumesExistingSession) {
        user = current;
      } else if (current?.isAnonymous == true) {
        user = (await current!.linkWithCredential(emailCredential)).user!;
      } else {
        try {
          user = (await auth.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )).user!;
        } on FirebaseAuthException catch (error) {
          _authStage('email_create_user', error: error);
          if (error.code != 'email-already-in-use') rethrow;
          // A previous attempt may have created Auth successfully and failed
          // while sending verification or creating the profile. Continue that
          // account instead of creating a duplicate or leaving it stranded.
          user = (await auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )).user!;
          resumedPartialAccount = true;
        }
      }
      createdNow = !resumesExistingSession && !resumedPartialAccount;
      _authStage('email_create_user', isNewUser: createdNow);
      // Linking the anonymous session changes the provider, but the first
      // callable can otherwise still receive the old anonymous ID token.
      await user.getIdToken(true);
      final profileRef = firestore
          .collection('community_profiles')
          .doc(user.uid);
      final existingProfile = await profileRef.get();
      final profileData = existingProfile.data() ?? const <String, dynamic>{};
      final existingName = (profileData['displayName'] as String? ?? '').trim();
      final isPlaceholderName = RegExp(
        r'^HUHS user(?: \d+)?$',
        caseSensitive: false,
      ).hasMatch(existingName);
      if (!createdNow && existingName.isNotEmpty && !isPlaceholderName) {
        throw StateError(
          'Ez az e-mail-cím már használatban van. Jelentkezz be.',
        );
      }
      Object? profileError;
      try {
        _authStage('display_name_claim', isNewUser: createdNow);
        await claimDisplayName(displayName);
        await user.updateDisplayName(displayName.trim());
        final accountRole = _isAdmin(normalizedEmail)
            ? 'organizer'
            : this.accountRole(role);
        await profileRef.set({
          // claimDisplayName already creates/updates displayName atomically;
          // Firestore rules intentionally reject a second client-side write.
          'role': accountRole,
          'accessRole': _isAdmin(user.email) ? accessAdmin : accessNone,
          'email': normalizedEmail,
          if (socialLinks != null && profileData['socialLinks'] == null)
            'socialLinks': socialLinks,
          if (!existingProfile.exists)
            'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _authStage('profile_creation', isNewUser: createdNow);
      } catch (error) {
        // Auth now exists. Always attempt verification below; the same signed-in
        // partial account can continue with another name without duplication.
        profileError = error;
      }
      // A slow or unavailable SMTP server must not strand a newly created
      // Auth account before its server-owned name and required role are saved.
      if (!user.emailVerified) {
        _authStage('email_verification', isNewUser: createdNow);
        try {
          await callFirebaseCallable<void>(
            'sendAuthEmail',
            parameters: {'action': 'verification'},
          );
        } catch (error) {
          _authStage('email_verification', error: error, isNewUser: true);
          verificationWarning = _verificationError(
            error is FirebaseFunctionsException ? error.code : 'unknown',
            duringRegistration: true,
          );
        }
      }
      if (profileError != null) {
        if (profileError is FirebaseFunctionsException &&
            profileError.code == 'already-exists') {
          throw StateError(
            'Ez a felhasználónév már foglalt. Válassz másikat. A megerősítő e-mailt elküldtük.',
          );
        }
        throw profileError;
      }
      if (verificationWarning != null) throw StateError(verificationWarning);
      _authStage('registration_complete', isNewUser: createdNow);
    } on FirebaseAuthException catch (error) {
      _authStage('email_create_user', error: error, isNewUser: createdNow);
      throw StateError(_authError(error.code));
    } catch (error) {
      _authStage(
        'email_registration_followup',
        error: error,
        isNewUser: createdNow,
      );
      if (error is StateError) rethrow;
      final code = error is FirebaseException ? error.code : 'unknown';
      throw StateError(
        'AUTH/registration-$code: A fiók létrejött, de a profil befejezése nem sikerült. Próbáld újra.',
      );
    }
  }

  Future<String> getMyReferralCode() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Az ajánlókód megtekintéséhez jelentkezz be.');
    }
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getMyReferralCode',
    );
    final code = result.data['code']?.toString().trim().toUpperCase();
    if (code == null || code.isEmpty) {
      throw StateError('Az ajánlókód nem tölthető be.');
    }
    return code;
  }

  Future<bool> claimReferralCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'claimReferralCode',
      parameters: {'code': normalized},
    );
    return result.data['claimed'] == true;
  }

  Future<void> claimDisplayName(String displayName) async {
    final value = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.length < 2 ||
        value.length > 40 ||
        !RegExp(
          r"^[\p{L}\p{N}][\p{L}\p{N} ._'-]*$",
          unicode: true,
        ).hasMatch(value)) {
      throw StateError(
        'AUTH/claimDisplayName-invalid-argument: Adj meg 2–40 karakteres, érvényes megjelenítési nevet.',
      );
    }
    // The backend grants the owner account unlimited name changes from the
    // verified Auth email claim. Refresh it before profile saves so a stale
    // Google/Auth token cannot be mistaken for a regular account.
    await auth.currentUser?.getIdToken(true);
    await callFirebaseCallable<void>(
      'claimDisplayName',
      parameters: {'displayName': value},
    );
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      clearProfileCache(uid);
      clearPublicProfileCache(uid);
    }
  }

  Future<void> checkDisplayNameAvailability(String displayName) async {
    final value = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.length < 2 ||
        value.length > 40 ||
        !RegExp(
          r"^[\p{L}\p{N}][\p{L}\p{N} ._'-]*$",
          unicode: true,
        ).hasMatch(value)) {
      throw StateError('Adj meg 2–40 karakteres, érvényes felhasználónevet.');
    }
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'checkDisplayNameAvailability',
      parameters: {'displayName': value},
    );
    if (result.data['available'] != true) {
      throw StateError('Ez a felhasználónév már foglalt. Válassz másikat.');
    }
  }

  String? get googleProfileCompletionNotice => _googleProfileCompletionNotice;

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      _authStage('email_sign_in');
      final credential = await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      await user.reload();
      // Unverified users may sign in; the UI keeps the persistent warning and
      // the resend action visible until verification succeeds.
      await _ensureAdminProfile(user);
      await _cacheProfileRole();
    } on FirebaseAuthException catch (error) {
      _authStage('email_sign_in', error: error);
      throw StateError(_authError(error.code));
    }
  }

  Future<String> resendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Nincs ellenőrizhető e-mailes fiók.');
    }
    try {
      // A közvetlenül regisztráció után megnyitott profil még régi ID tokent
      // hordozhat. A callable az Auth-token e-mailjét ellenőrzi.
      await user.getIdToken(true);
      final result = await callFirebaseCallable<Map<String, dynamic>>(
        'sendAuthEmail',
        parameters: {'action': 'verification'},
      );
      return result.data['outcome'] as String? ?? 'smtp_accepted';
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_verificationError(error.code));
    }
  }

  Future<void> requestEmailChange(String email) async {
    final user = auth.currentUser;
    final normalized = email.trim().toLowerCase();
    if (user == null || user.isAnonymous || user.email == null) {
      throw StateError('Ehhez e-mailes bejelentkezés szükséges.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw StateError('Érvénytelen e-mail-cím.');
    }
    await callFirebaseCallable<void>(
      'requestEmailChange',
      parameters: {'email': normalized},
    );
    try {
      await user.verifyBeforeUpdateEmail(normalized);
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> syncEmailChange() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await callFirebaseCallable<void>('syncEmailChange');
  }

  Future<void> resendEmailVerificationForCredentials({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final signedInUser = auth.currentUser;
      if (signedInUser == null) {
        throw StateError('A bejelentkezett fiók nem érhető el. Próbáld újra.');
      }
      await signedInUser.getIdToken(true);
      await callFirebaseCallable<void>(
        'sendAuthEmail',
        parameters: {'action': 'verification'},
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    } finally {
      await auth.signOut();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await callFirebaseCallable<void>(
        'sendAuthEmail',
        parameters: {
          'action': 'passwordReset',
          'email': email.trim().toLowerCase(),
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || user.isAnonymous || email == null) {
      throw StateError('Ehhez e-mailes bejelentkezés szükséges.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || user.isAnonymous || email == null) {
      throw StateError('E-mailes újrahitelesítés szükséges.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  String _authError(String code) =>
      'AUTH/$code: ${switch (code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'A megadott e-mail-cím vagy jelszó hibás.',
        'invalid-email' => 'Érvénytelen e-mail-cím.',
        'email-already-in-use' => 'Ez az e-mail-cím már használatban van.',
        'weak-password' => 'A jelszó túl gyenge.',
        'requires-recent-login' => 'A módosításhoz jelentkezz be újra.',
        'network-request-failed' => 'Hálózati hiba. Próbáld újra később.',
        'too-many-requests' => 'Túl sok próbálkozás történt. Próbáld újra később.',
        'account-exists-with-different-credential' => 'Ehhez a Google-fiókhoz már más bejelentkezési mód tartozik. Előbb azzal lépj be.',
        'credential-already-in-use' => 'Ez a Google-fiók már egy másik HUHS-fiókhoz tartozik.',
        _ => 'A bejelentkezés nem sikerült. Próbáld újra.',
      }}';

  String _verificationError(String code, {bool duringRegistration = false}) {
    if (duringRegistration) {
      return switch (code) {
        'too-many-requests' => 'A fiók létrejött, de túl sok ellenőrző e-mailt kértél. Próbáld újra később.',
        'network-request-failed' => 'A fiók létrejött, de az ellenőrző e-mail küldése hálózati hiba miatt nem sikerült. Próbáld újra.',
        _ => 'A fiók létrejött, de az ellenőrző e-mail küldése most nem sikerült. Próbáld újra később.',
      };
    }
    return switch (code) {
      'too-many-requests' =>
        'A megerősítő e-mail kérését most korlátozzuk. Próbáld újra később.',
      'network-request-failed' => 'A megerősítő e-mail küldése hálózati hiba miatt nem sikerült. Próbáld újra.',
      'unauthenticated' =>
        'Az újraküldéshez jelentkezz be újra, majd próbáld meg ismét.',
      _ =>
        'A megerősítő e-mail küldése most nem sikerült. Próbáld újra később.',
    };
  }

  String _googleAuthError(String code) =>
      'GOOGLE/$code: ${switch (code) {
        'account-exists-with-different-credential' => 'Ehhez a Google-fiókhoz már más bejelentkezési mód tartozik. Előbb azzal lépj be.',
        'credential-already-in-use' => 'Ez a Google-fiók már egy másik HUHS-fiókhoz tartozik.',
        'invalid-credential' => 'A Google-hitelesítő adat lejárt vagy érvénytelen. Válassz fiókot újra.',
        'network-request-failed' => 'A Google-belépéshez nem sikerült kapcsolódni. Ellenőrizd az internetkapcsolatot.',
        _ => 'A Google-belépés nem sikerült. Próbáld újra.',
      }}';

  void _authStage(String stage, {Object? error, bool? isNewUser}) {
    if (!kDebugMode) return;
    final currentUser = auth.currentUser;
    final operationId =
        error is FirebaseFunctionsException && error.details is Map
        ? (error.details as Map)['operationId']?.toString()
        : null;
    final details = error is FirebaseException
        ? ':code=${error.code}:type=${error.runtimeType}${operationId == null ? '' : ':operationId=$operationId'}'
        : error == null
        ? ''
        : ':type=${error.runtimeType}';
    debugPrint(
      'Auth stage=$stage:hasUser=${currentUser != null}:anonymous=${currentUser?.isAnonymous ?? false}:isNewUser=${isNewUser ?? false}$details',
    );
  }

  Future<bool> signInWithGoogle({
    String? role,
    String? displayName,
    Map<String, String>? socialLinks,
  }) async {
    _googleProfileCompletionNotice = null;
    try {
      _authStage('google_account_selection');
      // Request the Firebase web OAuth audience explicitly. Relying only on
      // google-services.json can return a Google account without an ID token
      // on Play-signed builds, which makes Firebase reject the sign-in.
      final googleSignIn = GoogleSignIn(
        serverClientId: '1030187737487-7cpgfu99rdngge4ine087ltlr339drkt.apps.googleusercontent.com',
      );
      // Clear only the local Google session so the account chooser is shown;
      // do not revoke the user's Google grant.
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) return false;
      final googleEmail = account.email.trim().toLowerCase();
      final tokens = await account.authentication;
      _authStage('google_firebase_credential');
      if (tokens.idToken == null || tokens.idToken!.trim().isEmpty) {
        throw StateError(
          'GOOGLE/missing-id-token: A Google-fiók nem adott érvényes azonosító tokent.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      final current = auth.currentUser;
      UserCredential result;
      if (current?.isAnonymous == true) {
        try {
          result = await current!.linkWithCredential(credential);
        } on FirebaseAuthException catch (error) {
          // If the Google identity already belongs to an account, signing
          // into that account still lets the server-side device claim block
          // a second annual vote on this installation.
          if (error.code != 'credential-already-in-use' &&
              error.code != 'provider-already-linked') {
            rethrow;
          }
          result = await auth.signInWithCredential(credential);
        }
      } else {
        result = await auth.signInWithCredential(credential);
      }
      final user = result.user!;
      final isNewAuthAccount = result.additionalUserInfo?.isNewUser ?? false;
      _authStage('google_firebase_auth', isNewUser: isNewAuthAccount);
      // Keep the callable context in sync when an anonymous session was
      // upgraded to Google; otherwise the backend can still see it as guest.
      await user.getIdToken(true);
      // The screen can still be in registration mode when the user selects a
      // Google account that already exists in Firebase.  That is a login, not
      // a new registration, so it must never trigger the display-name dialog.
      final profile = firestore.collection('community_profiles').doc(user.uid);
      try {
        final existing = await profile.get(
          const GetOptions(source: Source.server),
        );
        final existingData = existing.data() ?? const <String, dynamic>{};
        final savedDisplayName = (existingData['displayName'] as String? ?? '')
            .trim();
        final savedNameIsValid =
            savedDisplayName.length >= 2 &&
            savedDisplayName.length <= 40 &&
            !savedDisplayName.contains('@');
        final existingRole = existingData['role'] as String?;
        final profileComplete =
            existing.exists &&
            savedNameIsValid &&
            const {'dj', 'organizer', 'partygoer'}.contains(existingRole);
        if (!profileComplete) {
          final requiredRole = accountRole(role);
          final bootstrap = await bootstrapGoogleProfile(
            existingProfile: existingData,
            requestedDisplayName: displayName,
            googleDisplayName: account.displayName,
            role: requiredRole,
            claimDisplayName: claimDisplayName,
            saveAndReadProfile: (savedRole) async {
              await profile.set({
                'role': savedRole,
                'accessRole': accessNone,
                'email': googleEmail,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              final saved = await profile.get(
                const GetOptions(source: Source.server),
              );
              return saved.data() ?? const <String, dynamic>{};
            },
          );
          _googleProfileCompletionNotice = switch (bootstrap) {
            GoogleProfileBootstrapStatus.missingName => 'A Google-fiók nem adott használható nyilvános nevet. Adj meg egyet a profilban.',
            GoogleProfileBootstrapStatus.invalidName => 'A Google-fiók neve nem felel meg a névszabályoknak. Adj meg másik nyilvános nevet.',
            GoogleProfileBootstrapStatus.nameTaken => 'A Google-fiók automatikus neve már foglalt. Adj meg másik nyilvános nevet a profilban.',
            GoogleProfileBootstrapStatus.saved => null,
          };
          clearProfileCache(user.uid);
          if (bootstrap == GoogleProfileBootstrapStatus.saved) {
            _cachedRole = requiredRole;
            _cachedAccessRole = accessNone;
            _cachedRoleUid = user.uid;
          }
          return true;
        }
        final existingAccessRole =
            existingData['accessRole'] as String? ??
            (existingRole == accessAdmin ? accessAdmin : accessNone);
        await profile.set({
          'email': googleEmail,
          if (_isAdmin(googleEmail)) 'role': 'organizer',
          if (_isAdmin(googleEmail)) 'accessRole': accessAdmin,
          if (!_isAdmin(googleEmail) && existingRole == null && role != null)
            'role': role,
          if (!_isAdmin(googleEmail) &&
              existingRole == null &&
              socialLinks != null)
            'socialLinks': socialLinks,
          if (!_isAdmin(googleEmail) && existingData['accessRole'] == null)
            'accessRole': existingAccessRole,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _cachedRole = _isAdmin(googleEmail)
            ? 'organizer'
            : accountRole(existingRole ?? role);
        _cachedAccessRole = _isAdmin(googleEmail)
            ? accessAdmin
            : existingAccessRole;
        _cachedRoleUid = user.uid;
      } catch (error) {
        _authStage(
          'profile_creation',
          error: error,
          isNewUser: isNewAuthAccount,
        );
        if (error is StateError) rethrow;
        final code = error is FirebaseException ? error.code : 'unknown';
        throw StateError(
          'GOOGLE/profile-$code: ${isNewAuthAccount ? 'A Google-fiók létrejött, de a profil befejezése szükséges.' : 'A Google-belépés sikerült, de a profil nem tölthető be.'} Próbáld újra.',
        );
      }
      await _ensureAdminProfile(user);
      await _cacheProfileRole();
      return true;
    } on FirebaseAuthException catch (error) {
      _authStage('google_firebase_auth', error: error);
      throw StateError(_googleAuthError(error.code));
    } on PlatformException catch (error) {
      _authStage('google_account_selection', error: error);
      if (error.code == GoogleSignIn.kNetworkError ||
          error.code == 'network-request-failed') {
        throw StateError(
          'GOOGLE/${error.code}: A Google-belépéshez nem sikerült kapcsolódni. Ellenőrizd az internetkapcsolatot.',
        );
      }
      if (error.code == GoogleSignIn.kSignInCanceledError) return false;
      final platformDetails = '${error.message ?? ''} ${error.details ?? ''}';
      if (error.code == '10' ||
          RegExp(r'ApiException\s*:\s*10').hasMatch(platformDetails)) {
        throw StateError(
          'GOOGLE/10: A Google-belépés elutasította az OAuth-kérést.',
        );
      }
      throw StateError(
        'GOOGLE/${error.code}: A Google-belépés nem sikerült. Próbáld újra.',
      );
    }
  }

  bool _isAdmin(String? email) => email?.trim().toLowerCase() == adminEmail;

  /// A tulajdonos e-mail-címe. A szerver ugyanezt tekinti adminnak, ezért a
  /// kliensnek is azonnal annak kell látnia — a profil `accessRole` mezőjének
  /// betöltése nélkül is. (Lásd `currentUserIsAdminProvider`.)
  static bool isOwnerEmail(String? email) =>
      email?.trim().toLowerCase() == adminEmail;

  bool get isOwner => _isAdmin(auth.currentUser?.email);

  bool get isAdmin =>
      _isAdmin(auth.currentUser?.email) ||
      _hasCurrentUserRoleCache &&
          (_cachedAccessRole == accessAdmin || _cachedRole == accessAdmin);

  String get cachedAccountRole =>
      _hasCurrentUserRoleCache ? accountRole(_cachedRole) : 'partygoer';

  bool get canModerate =>
      isAdmin ||
      (_hasCurrentUserRoleCache && _cachedAccessRole == accessModerator);

  bool get _hasCurrentUserRoleCache {
    final user = auth.currentUser;
    return user != null && !user.isAnonymous && _cachedRoleUid == user.uid;
  }

  String accountRole(String? value) {
    if (value == accessAdmin || value == 'organizer') return 'organizer';
    if (value == 'dj' || value == 'partygoer') return value!;
    return 'partygoer';
  }

  Future<void> publishPost({
    required String text,
    Uint8List? imageBytes,
    bool pinned = false,
    String? replyToText,
    String? replyToName,
    String? replyToAuthorId,
  }) async {
    final user = await ensureAnonymousUser();
    final isAnonymous = user.isAnonymous;
    if (pinned && !isAdmin) {
      throw StateError('Csak admin rögzíthet Chat-üzenetet.');
    }
    final trimmed = maskProfanity(text.trim());
    if (trimmed.isEmpty && imageBytes == null) {
      throw ArgumentError('A bejegyzés szövege vagy képe kötelező.');
    }
    if (isAnonymous && imageBytes != null) {
      throw StateError('Névtelen felhasználó nem tölthet fel képet.');
    }
    if (!isAnonymous &&
        (await firestore.collection('community_bans').doc(user.uid).get())
            .exists) {
      throw StateError('A Chat-hozzáférésed le van tiltva.');
    }
    String imageUrl = '';
    CloudinaryUploadResult? uploadedImage;
    if (imageBytes != null) {
      uploadedImage = await uploadImageWithMetadata(
        imageBytes,
        filename: 'chat.jpg',
        userScoped: true,
      );
      imageUrl = uploadedImage.url;
    }
    await callFirebaseCallable<void>(
      'publishChatPost',
      parameters: {
        'text': trimmed,
        if (replyToText?.trim().isNotEmpty == true)
          'replyToText': replyToText!.trim().substring(
            0,
            replyToText.trim().length > 200 ? 200 : replyToText.trim().length,
          ),
        if (replyToText?.trim().isNotEmpty == true &&
            replyToName?.trim().isNotEmpty == true)
          'replyToName': replyToName!.trim().substring(
            0,
            replyToName.trim().length > 80 ? 80 : replyToName.trim().length,
          ),
        // KIT válaszoltunk meg: ebből lesz a szerveren az értesítés a válaszolt
        // felhasználónak (a tulajdonos kérése). A `replyToText`/`replyToName`
        // csak a megjelenítéshez kell, a szerző UID-ja az értesítéshez.
        if (replyToText?.trim().isNotEmpty == true &&
            replyToAuthorId?.trim().isNotEmpty == true)
          'replyToAuthorId': replyToAuthorId!.trim().substring(
            0,
            replyToAuthorId.trim().length > 128
                ? 128
                : replyToAuthorId.trim().length,
          ),
        'imageUrl': imageUrl,
        if (uploadedImage?.publicId.isNotEmpty == true)
          'imagePublicId': uploadedImage!.publicId,
        if (pinned) 'pinned': true,
      },
    );
  }

  /// A Chat-üzenet reakciójának váltása; visszaadja a **saját** új állapotot.
  ///
  /// MIÉRT adja vissza: a szerver `selected` mezője (`''` = visszavontuk) az
  /// egyetlen biztos forrás arra, hogy a felület **azonnal** mutassa, hogy a
  /// felhasználó reakciója ott van-e. Enélkül a koppintás 100–300 ms-ig
  /// „nem csinált semmit" benyomást kelt, és a felhasználó nem látja
  /// egyértelműen, hogy lájkolt-e (a tulajdonos jelzése).
  Future<String> toggleReaction({
    required String postId,
    required String emoji,
  }) async {
    await ensureAnonymousUser();
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'toggleChatReaction',
      parameters: {'postId': postId, 'emoji': emoji},
    );
    return result.data['selected'] as String? ?? '';
  }

  /// A Chat-üzenet törlése — **csak adminnak**.
  ///
  /// A tulajdonos kérése: *„Admin természetesen mindenkiét + admin törölni is
  /// tudjon"*. A szerzo a SAJÁT üzenetét **szerkesztheti** (lásd
  /// [updatePostText]), de nem törölheti: a törlés admin-jog.
  Future<void> deletePost(String postId) async {
    if (!isAdmin && _cachedAccessRole == accessNone) {
      await _cacheProfileRole();
    }
    if (!isAdmin) {
      throw StateError('Csak admin törölhet Chat-üzenetet.');
    }
    await firestore.collection('live_feed_posts').doc(postId).delete();
  }

  /// A Chat-üzenet szerkesztése — a **szerző magáé**, adminként **bárkié**.
  ///
  /// A tulajdonos kérése: *„a chaten a felhasználó tudja szerkeszteni a saját
  /// üzenetét … Admin természetesen mindenkiét"*.
  ///
  /// A jogosultságot a KLIENS oldal is ellenőrzi (hogy a felület ne kínáljon
  /// lehetetlent), de a valódi védelem a Firestore-szabályban van: a szerző
  /// kizárólag a saját során, kizárólag a `text` és az `editedAt` mezőt
  /// módosíthatja. Így egy másik fiók üzenetét akkor sem lehet átírni, ha
  /// valaki megkerüli a felületet.
  ///
  /// Az `authorId` azért jön paraméterként, mert a hívó már ismeri a bejegyzést:
  /// így nem kell egy plusz Firestore-olvasás csak a jogosultság eldöntéséhez.
  Future<void> updatePostText({
    required String postId,
    required String text,
    String authorId = '',
  }) async {
    if (!isAdmin && _cachedAccessRole == accessNone) {
      await _cacheProfileRole();
    }
    if (!isAdmin) {
      final uid = auth.currentUser?.uid ?? '';
      if (uid.isEmpty || authorId.trim() != uid) {
        throw StateError('Csak a saját üzenetedet szerkesztheted.');
      }
    }
    final trimmed = maskProfanity(text.trim());
    if (trimmed.isEmpty) throw ArgumentError('Az üzenet nem lehet üres.');
    await firestore.collection('live_feed_posts').doc(postId).update({
      'text': trimmed,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportPost(String postId, {String reason = 'other'}) async {
    final user = await ensureAnonymousUser();
    if (user.isAnonymous) {
      throw StateError('Jelentéshez regisztráció szükséges.');
    }
    final post = await firestore
        .collection('live_feed_posts')
        .doc(postId)
        .get();
    final postData = post.data() ?? const <String, dynamic>{};
    final reporter = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final reporterData = reporter.data() ?? const <String, dynamic>{};
    await firestore.collection('chat_reports').add({
      'postId': postId,
      'reporterId': user.uid,
      'reporterName':
          reporterData['displayName'] as String? ??
          user.displayName ??
          user.email ??
          '',
      'reason': reason,
      'reportedUserId': postData['authorId'] as String? ?? '',
      'reportedUserName': postData['authorName'] as String? ?? '',
      'reportedText': postData['text'] as String? ?? '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveReport(String reportId) async {
    if (!isAdmin) throw StateError('Csak admin kezelhet jelentést.');
    await firestore.collection('chat_reports').doc(reportId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminBlockUser(String userId) async {
    if (!isAdmin || userId.isEmpty) {
      throw StateError('Csak admin tilthat felhasználót.');
    }
    await firestore.collection('community_bans').doc(userId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': auth.currentUser?.uid,
    });
  }

  Future<void> blockUser(String userId) async {
    final user = await ensureAnonymousUser();
    if (user.isAnonymous || userId.isEmpty || userId == user.uid) {
      throw StateError('A blokkoláshoz regisztráció szükséges.');
    }
    await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('blocked_users')
        .doc(userId)
        .set({'createdAt': FieldValue.serverTimestamp()});
    _blockedUserIds = {..._blockedUserIds, userId};
    await callFirebaseCallable<void>(
      'manageConnection',
      parameters: {'action': 'remove', 'otherUid': userId},
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBlockedUsers() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('blocked_users')
        .snapshots();
  }

  Future<void> unblockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('blocked_users')
        .doc(userId)
        .delete();
    _blockedUserIds = {..._blockedUserIds}..remove(userId);
  }

  Future<void> adminSetDisplayName(String userId, String displayName) async {
    if (!isAdmin) throw StateError('Csak admin módosíthat nevet.');
    await callFirebaseCallable<void>(
      'claimDisplayName',
      parameters: {'targetUid': userId, 'displayName': displayName},
    );
  }

  Future<void> claimArtist(int artistId) async {
    if (auth.currentUser?.emailVerified != true) {
      throw StateError('Hitelesített e-mailes fiók szükséges.');
    }
    await callFirebaseCallable<void>(
      'claimArtistProfile',
      parameters: {'artistId': artistId},
    );
  }

  /// A DJ-adatlap claim-jogosultsága (a **szerver** dönt, e-mail cím nélkül).
  ///
  /// A tulajdonos jelzése szerint a claim gomb csak akkor jelenhet meg, ha a
  /// bejelentkezési e-mail egyezik az adatlapon szereplő **booking vagy privát**
  /// címmel — ezért kérdezzük le a döntést, ahelyett hogy a felület találgatna.
  Future<ArtistClaimStatus> artistClaimStatus(int artistId) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getArtistClaimStatus',
      parameters: {'artistId': artistId},
    );
    return ArtistClaimStatus.fromJson(result.data);
  }

  /// A claim **visszavonása** (a saját claimet bárki, a hibásat az admin).
  ///
  /// MIÉRT kell: élesben egy idegen DJ-adatlap került a tulajdonos fiókjára az
  /// admin-kivétel miatt, és *„lekéne szedni rólam"* — ezt eddig semmilyen úton
  /// nem lehetett megtenni.
  Future<void> releaseArtistClaim(int artistId) async {
    if (auth.currentUser?.emailVerified != true) {
      throw StateError('Hitelesített e-mailes fiók szükséges.');
    }
    await callFirebaseCallable<void>(
      'releaseArtistClaim',
      parameters: {'artistId': artistId},
    );
  }

  /// Egy **másik felhasználó** claimelt DJ-adatlapjai (a nyilvános profilhoz).
  ///
  /// A tulajdonos kérése: *„ha valaki megnyitja egy user adatlapját és claimelt
  /// egy DJ profilt, látszódjon az is ott, egy kattintható kártyaként"*.
  Future<List<int>> claimedArtistsOfUser(String userId) async {
    if (userId.trim().isEmpty) return const [];
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getClaimedArtistsForUser',
      parameters: {'uid': userId},
    );
    final ids = (result.data as Map?)?['artistIds'];
    if (ids is! List) return const [];
    return ids.whereType<num>().map((id) => id.toInt()).toList();
  }

  Future<List<int>> myClaimedArtists() async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getMyClaimedArtists',
    );
    final ids = (result.data as Map?)?['artistIds'];
    if (ids is! List) return const [];
    return ids.whereType<num>().map((id) => id.toInt()).toList();
  }

  Future<void> setPostPinned(String postId, bool pinned) async {
    if (!isAdmin) {
      throw StateError('Csak admin rögzíthet Chat-üzenetet.');
    }
    await firestore.collection('live_feed_posts').doc(postId).update({
      'pinned': pinned,
    });
  }

  static String maskProfanity(String text) {
    const words = [
      // Hungarian roots and common compounds.
      'kurva',
      'kurvaanyad',
      'kurvaisten',
      'fasz',
      'faszfej',
      'faszkalap',
      'faszopó',
      'fasszopó',
      'geci',
      'gecifej',
      'bazdmeg',
      'bazd',
      'basz',
      'picsa',
      'szar',
      'szarházi',
      'buzi',
      'buzeráns',
      'seggfej',
      'köcsög',
      // English words and common compounds.
      'fuck',
      'fck',
      'shit',
      'bitch',
      'cunt',
      'dick',
      'pussy',
      'whore',
      'slut',
      'bastard',
      'asshole',
      'bullshit',
      'dumbass',
      'motherfucker',
      // Common leetspeak spellings.
      'f4sz',
      'b4sz',
      'g3ci',
      'sh1t',
      'fck',
    ];
    var result = text;
    result = result.replaceAllMapped(
      RegExp(
        r'(?<![A-Za-zÀ-ÖØ-öø-ÿ0-9_])(?:bazd|baszd)\s+meget',
        caseSensitive: false,
      ),
      (match) => match.group(0)!.replaceAllMapped(RegExp(r'\S'), (_) => '*'),
    );
    for (final word in words) {
      result = result.replaceAllMapped(
        RegExp(
          r'(?<![A-Za-zÀ-ÖØ-öø-ÿ0-9_])' +
              RegExp.escape(word) +
              r'[A-Za-zÀ-ÖØ-öø-ÿ0-9_]*',
          caseSensitive: false,
        ),
        (match) => '*' * match.group(0)!.length,
      );
    }
    return result;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProfiles() {
    if (!isAdmin) return const Stream.empty();
    return firestore
        .collection('community_profiles')
        .orderBy('displayName')
        .snapshots();
  }

  Future<void> refreshMyAchievementBadge() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await callFirebaseCallable<void>('refreshAchievementBadge');
    // The chat may already hold this user's public profile for up to the
    // normal profile-cache lifetime. Invalidate only this UID immediately
    // after the server recalculates the badge so the next chat rebuild gets
    // the new rank without disabling caching for everybody else.
    clearPublicProfileCache(user.uid);
    clearProfileCache(user.uid);
  }

  /// Refreshes the signed-in profile without making the caller lose the
  /// already-rendered local snapshot.
  Future<DocumentSnapshot<Map<String, dynamic>>> refreshOwnProfile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A profil megtekintéséhez regisztráció szükséges.');
    }
    clearProfileCache(user.uid);
    return _refreshProfileInBackground(user);
  }

  /// Returns a public profile from a shared in-memory cache.
  ///
  /// Profile screens used to create a new Firestore `get()` Future in
  /// `build()`. Apart from refetching after every rebuild, that made opening
  /// the same profile again wait for the network every time. The cache is
  /// process-local and scoped to the authenticated user session; sign-out or
  /// account switching clears it.
  Future<Map<String, dynamic>> getPublicProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const <String, dynamic>{};
    _preparePublicCacheForCurrentUser();
    final cached = _publicProfileCache[normalizedUserId];
    if (!forceRefresh &&
        cached != null &&
        cached.isFresh &&
        !_hasUnnumberedPlaceholderName(cached.data)) {
      _touchPublicProfileCache(normalizedUserId, cached);
      return Map<String, dynamic>.from(cached.data);
    }
    if (cached != null && !cached.isFresh) {
      _publicProfileCache.remove(normalizedUserId);
    }
    if (!forceRefresh) {
      final persistent = await _readPersistentPublicProfile(normalizedUserId);
      if (persistent != null && !_hasUnnumberedPlaceholderName(persistent)) {
        final entry = _PublicProfileCacheEntry(persistent, true);
        _publicProfileCache[normalizedUserId] = entry;
        // Stale-while-revalidate: render the persisted profile immediately,
        // then refresh it in the background without blanking the UI.
        unawaited(getPublicProfile(normalizedUserId, forceRefresh: true));
        return Map<String, dynamic>.from(persistent);
      }
    }
    // Normal reads use the fast public projection. A forced refresh must
    // bypass it so changed badge artwork can be reconciled with WordPress by
    // the callable instead of reading the same stale projection again.
    if (!forceRefresh) {
      try {
        final snapshot = await firestore
            .collection('public_profiles')
            .doc(normalizedUserId)
            .get();
        if (snapshot.exists && snapshot.data() != null) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          if (_hasUnnumberedPlaceholderName(data)) {
            // Older public projections may still contain the generic label;
            // let the callable assign and persist the stable user number.
          } else {
            final entry = _PublicProfileCacheEntry(data, true);
            _storePublicProfileCache(normalizedUserId, entry);
            unawaited(
              _writePersistentPublicProfile(
                normalizedUserId,
                data,
                ownerUid: _publicCacheOwnerUid,
              ),
            );
            return data;
          }
        }
      } catch (_) {
        // Rules/deployment lag or legacy installations use the callable below.
      }
    }
    final existingRefresh = _publicProfileRefreshRequests[normalizedUserId];
    if (existingRefresh != null) return (await existingRefresh).data;
    if (!forceRefresh) {
      final existing = _publicProfileRequests[normalizedUserId];
      if (existing != null) return (await existing).data;
    }
    final requestEpoch = _cacheEpochFor(normalizedUserId);
    final requestOwnerUid = _publicCacheOwnerUid;
    final request = () async {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await callFirebaseCallable<Map<String, dynamic>>(
            'getPublicProfile',
            parameters: {'userId': normalizedUserId},
          );
          final data = result.data;
          final entry = _PublicProfileCacheEntry(data, data.isNotEmpty);
          // A response started before invalidation must never resurrect stale
          // profile/rank data after the newer request has completed.
          if (data.isNotEmpty &&
              _cacheEpochFor(normalizedUserId) == requestEpoch) {
            _storePublicProfileCache(normalizedUserId, entry);
            unawaited(
              _writePersistentPublicProfile(
                normalizedUserId,
                data,
                ownerUid: requestOwnerUid,
              ),
            );
          }
          return entry;
        } catch (error) {
          if (error is FirebaseFunctionsException &&
              error.code == 'not-found') {
            clearPublicProfileCache(normalizedUserId);
            await _removePersistentPublicProfile(normalizedUserId);
            return _PublicProfileCacheEntry(<String, dynamic>{}, true);
          }
          if (attempt == 2) {
            if (kDebugMode) {
              debugPrint(
                'Publikus profil lekérése sikertelen: ${error.runtimeType}',
              );
            }
            return _PublicProfileCacheEntry(<String, dynamic>{}, false);
          }
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }
      return _PublicProfileCacheEntry(<String, dynamic>{}, false);
    }();
    _publicProfileRequests[normalizedUserId] = request;
    if (forceRefresh) {
      _publicProfileRefreshRequests[normalizedUserId] = request;
    }
    try {
      return (await request).data;
    } finally {
      if (identical(_publicProfileRequests[normalizedUserId], request)) {
        _publicProfileRequests.remove(normalizedUserId);
      }
      if (identical(_publicProfileRefreshRequests[normalizedUserId], request)) {
        _publicProfileRefreshRequests.remove(normalizedUserId);
      }
    }
  }

  bool _hasUnnumberedPlaceholderName(Map<String, dynamic> data) {
    final name =
        (data['displayName'] as String?)?.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        ) ??
        '';
    final number = int.tryParse('${data['huhsUserNumber'] ?? ''}');
    return (name.isEmpty ||
            const {'hun hs', 'hs hu', 'hu hs', 'huhs user'}.contains(name)) &&
        (number == null || number < 1000);
  }

  Stream<Map<String, dynamic>> watchPublicProfile(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const Stream.empty();
    _preparePublicCacheForCurrentUser();
    return firestore
        .collection('public_profiles')
        .doc(normalizedUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            clearPublicProfileCache(normalizedUserId);
            await _removePersistentPublicProfile(normalizedUserId);
            return <String, dynamic>{};
          }
          final value = Map<String, dynamic>.from(data);
          if (_hasUnnumberedPlaceholderName(value)) {
            // Older projections may still contain the generic label. The
            // callable assigns the stable number and rewrites the projection.
            return getPublicProfile(normalizedUserId, forceRefresh: true);
          }
          final entry = _PublicProfileCacheEntry(value, true);
          _storePublicProfileCache(normalizedUserId, entry);
          await _writePersistentPublicProfile(
            normalizedUserId,
            value,
            ownerUid: _publicCacheOwnerUid,
          );
          return value;
        });
  }

  String _persistentPublicProfileKey(String userId, {String? ownerUid}) {
    final owner = (ownerUid ?? auth.currentUser?.uid)?.trim();
    final ownerKey = owner == null || owner.isEmpty ? 'anonymous' : owner;
    return 'huhs.public.profile.$ownerKey.$userId';
  }

  Future<Map<String, dynamic>?> _readPersistentPublicProfile(
    String userId,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _persistentPublicProfileKey(userId);
      final savedAt = preferences.getInt('$key.savedAt');
      final payload = preferences.getString(key);
      if (savedAt == null || payload == null) return null;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > _publicPersistentCacheTtl) {
        unawaited(preferences.remove(key));
        unawaited(preferences.remove('$key.savedAt'));
        return null;
      }
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentPublicProfile(
    String userId,
    Map<String, dynamic> data, {
    String? ownerUid,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _persistentPublicProfileKey(userId, ownerUid: ownerUid);
      await preferences.setString(key, jsonEncode(data));
      await preferences.setInt(
        '$key.savedAt',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // The memory cache remains the source for this session if persistence
      // is unavailable (for example on a restricted platform).
    }
  }

  Future<void> _removePersistentPublicProfile(String userId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _persistentPublicProfileKey(userId);
      await preferences.remove(key);
      await preferences.remove('$key.savedAt');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getRegisteredPublicProfiles({
    bool forceRefresh = false,
  }) async {
    _preparePublicCacheForCurrentUser();
    if (forceRefresh) {
      _publicProfilesEpoch++;
      _publicProfilesCache = null;
      _publicProfilesRequest = null;
    }
    final cached = _publicProfilesCache;
    if (cached != null) {
      return _visiblePublicProfiles(cached)
          .map((profile) => Map<String, dynamic>.from(profile))
          .toList(growable: false);
    }
    final existing = _publicProfilesRequest;
    if (existing != null) return existing;
    final requestEpoch = _publicProfilesEpoch;
    final Future<List<Map<String, dynamic>>> request = () async {
      final result = await callFirebaseCallable<Map<String, dynamic>>(
        'getPublicProfiles',
      );
      final data = result.data;
      if (data['profiles'] is! List) {
        return const <Map<String, dynamic>>[];
      }
      final profiles = (data['profiles'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (_publicProfilesEpoch == requestEpoch) {
        _publicProfilesCache = profiles;
      }
      return _visiblePublicProfiles(profiles).toList(growable: false);
    }();
    _publicProfilesRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_publicProfilesRequest, request)) {
        _publicProfilesRequest = null;
      }
    }
  }

  Stream<List<Map<String, dynamic>>> watchRegisteredPublicProfiles() =>
      firestore
          .collection('public_profiles')
          .orderBy('displayName')
          .snapshots()
          .map(
            (snapshot) =>
                _visiblePublicProfiles(
                      snapshot.docs.map(
                        (document) => {
                          ...document.data(),
                          'userId': document.id,
                        },
                      ),
                    )
                    .map((profile) => Map<String, dynamic>.from(profile))
                    .toList(growable: false),
          );

  Future<Map<String, dynamic>> getAchievementLeaderboardPage({
    int pageSize = 50,
    int? cursorPoints,
    String? cursorUserId,
    int offset = 0,
  }) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getAchievementLeaderboard',
      parameters: <String, dynamic>{
        'pageSize': pageSize,
        'offset': offset,
        ...?(cursorPoints == null
            ? null
            : <String, dynamic>{'cursorPoints': cursorPoints}),
        ...?(cursorUserId?.isNotEmpty == true
            ? <String, dynamic>{'cursorUserId': cursorUserId}
            : null),
      },
    );
    return Map<String, dynamic>.from(result.data);
  }

  static Iterable<Map<String, dynamic>> _visiblePublicProfiles(
    Iterable<Map<String, dynamic>> profiles,
  ) {
    return profiles.where((profile) {
      final deleted =
          profile['deleted'] == true ||
          profile['isDeleted'] == true ||
          profile['deletedAt'] != null ||
          (profile['accountStatus'] as String? ?? '').trim().toLowerCase() ==
              'deleted';
      return !deleted;
    });
  }

  static void clearPublicProfileCache([String? userId]) {
    final normalizedUserId = userId?.trim();
    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      _publicProfileCache.clear();
      _publicProfileRequests.clear();
      _publicProfileRefreshRequests.clear();
      _publicProfilesCache = null;
      _publicProfilesRequest = null;
      _publicProfilesEpoch++;
      _publicAchievementCache.clear();
      _publicAchievementRequests.clear();
      _publicAchievementRefreshRequests.clear();
      _publicCacheEpochs.clear();
      _publicCacheEpoch++;
      _publicCacheOwnerUid = null;
      publicProfileRefreshGeneration.value++;
      // Public profile persistence is scoped to the current auth owner. Do
      // not synchronously block logout or account switching on cleanup.
      return;
    }
    _publicCacheEpochs[normalizedUserId] =
        (_publicCacheEpochs[normalizedUserId] ?? 0) + 1;
    _publicProfileCache.remove(normalizedUserId);
    _publicProfileRequests.remove(normalizedUserId);
    _publicProfileRefreshRequests.remove(normalizedUserId);
    _publicProfilesCache = null;
    _publicProfilesEpoch++;
    _publicAchievementCache.remove(normalizedUserId);
    _publicAchievementRequests.remove(normalizedUserId);
    _publicAchievementRefreshRequests.remove(normalizedUserId);
    publicProfileRefreshGeneration.value++;
    // The persistent entry is intentionally retained: it is public data and
    // is used for the next fast first paint; a forced server refresh follows.
  }

  Future<AchievementSummary> getPublicAchievement(
    String userId, {
    bool forceRefresh = false,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return Future.value(AchievementSummary.empty);
    _preparePublicCacheForCurrentUser();
    final cached = _publicAchievementCache[normalizedUserId];
    if (cached != null && cached.isFresh) {
      _touchAchievementCache(normalizedUserId, cached);
      return Future.value(cached.value);
    }
    if (cached != null) _publicAchievementCache.remove(normalizedUserId);
    if (!forceRefresh) {
      final persistent = _readPersistentPublicAchievement(normalizedUserId);
      return persistent.then((value) {
        if (value == null) {
          return _loadPublicAchievement(normalizedUserId, forceRefresh: false);
        }
        _publicAchievementCache[normalizedUserId] = _AchievementCacheEntry(
          value,
        );
        unawaited(_loadPublicAchievement(normalizedUserId, forceRefresh: true));
        return value;
      });
    }
    return _loadPublicAchievement(normalizedUserId, forceRefresh: true);
  }

  Future<AchievementSummary> _loadPublicAchievement(
    String normalizedUserId, {
    required bool forceRefresh,
  }) {
    final existingRefresh = _publicAchievementRefreshRequests[normalizedUserId];
    if (existingRefresh != null) return existingRefresh;
    final existing = _publicAchievementRequests[normalizedUserId];
    if (existing != null && !forceRefresh) return existing;
    final requestEpoch = _cacheEpochFor(normalizedUserId);
    final request = () async {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await callFirebaseCallable<Map<String, dynamic>>(
            'getPublicAchievement',
            parameters: {'userId': normalizedUserId},
          );
          final data = result.data;
          final value = AchievementSummary.fromProfile(data);
          if (_cacheEpochFor(normalizedUserId) == requestEpoch) {
            _storeAchievementCache(
              normalizedUserId,
              _AchievementCacheEntry(value),
            );
            unawaited(
              _writePersistentPublicAchievement(
                normalizedUserId,
                value,
                ownerUid: _publicCacheOwnerUid,
              ),
            );
          }
          return value;
        } catch (error) {
          if (attempt == 2) {
            if (kDebugMode) {
              debugPrint(
                'Publikus achievement lekérése sikertelen: ${error.runtimeType}',
              );
            }
            return AchievementSummary.empty;
          }
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }
      return AchievementSummary.empty;
    }();
    _publicAchievementRequests[normalizedUserId] = request;
    if (forceRefresh) {
      _publicAchievementRefreshRequests[normalizedUserId] = request;
    }
    request.whenComplete(() {
      if (identical(_publicAchievementRequests[normalizedUserId], request)) {
        _publicAchievementRequests.remove(normalizedUserId);
      }
      if (identical(
        _publicAchievementRefreshRequests[normalizedUserId],
        request,
      )) {
        _publicAchievementRefreshRequests.remove(normalizedUserId);
      }
    });
    return request;
  }

  String _persistentPublicAchievementKey(String userId, {String? ownerUid}) {
    final owner = (ownerUid ?? auth.currentUser?.uid)?.trim();
    final ownerKey = owner == null || owner.isEmpty ? 'anonymous' : owner;
    return 'huhs.public.achievement.$ownerKey.$userId';
  }

  Future<AchievementSummary?> _readPersistentPublicAchievement(
    String userId,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _persistentPublicAchievementKey(userId);
      final payload = preferences.getString(key);
      final savedAt = preferences.getInt('$key.savedAt');
      if (payload == null || savedAt == null) return null;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > _publicPersistentCacheTtl) {
        await preferences.remove(key);
        await preferences.remove('$key.savedAt');
        return null;
      }
      final decoded = jsonDecode(payload);
      return decoded is Map
          ? AchievementSummary.fromProfile(Map<String, dynamic>.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentPublicAchievement(
    String userId,
    AchievementSummary value, {
    String? ownerUid,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _persistentPublicAchievementKey(userId, ownerUid: ownerUid);
      await preferences.setString(
        key,
        jsonEncode({
          'achievementPoints': value.points,
          'achievementBadge': {
            'name': value.badgeName,
            'description': value.badgeDescription,
            'imageUrl': value.badgeImageUrl,
            'slug': value.badgeSlug,
          },
        }),
      );
      await preferences.setInt(
        '$key.savedAt',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // The memory cache remains the source for this session if persistence
      // is unavailable.
    }
  }

  void _preparePublicCacheForCurrentUser() {
    final uid = auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty || uid == _publicCacheOwnerUid) return;
    _publicCacheEpoch++;
    _publicProfileCache.clear();
    _publicProfileRequests.clear();
    _publicProfileRefreshRequests.clear();
    _publicProfilesCache = null;
    _publicProfilesRequest = null;
    _publicProfilesEpoch++;
    _publicAchievementCache.clear();
    _publicAchievementRequests.clear();
    _publicCacheOwnerUid = uid;
  }

  static int _cacheEpochFor(String userId) =>
      _publicCacheEpoch + (_publicCacheEpochs[userId] ?? 0);

  static void _storePublicProfileCache(
    String userId,
    _PublicProfileCacheEntry entry,
  ) {
    _publicProfileCache.remove(userId);
    _publicProfileCache[userId] = entry;
    while (_publicProfileCache.length > _publicProfileCacheLimit) {
      _publicProfileCache.remove(_publicProfileCache.keys.first);
    }
  }

  static void _touchPublicProfileCache(
    String userId,
    _PublicProfileCacheEntry entry,
  ) {
    _storePublicProfileCache(userId, entry);
  }

  static void _storeAchievementCache(
    String userId,
    _AchievementCacheEntry entry,
  ) {
    _publicAchievementCache.remove(userId);
    _publicAchievementCache[userId] = entry;
    while (_publicAchievementCache.length > _publicProfileCacheLimit) {
      _publicAchievementCache.remove(_publicAchievementCache.keys.first);
    }
  }

  static void _touchAchievementCache(
    String userId,
    _AchievementCacheEntry entry,
  ) {
    _storeAchievementCache(userId, entry);
  }

  @visibleForTesting
  static int publicCacheEpochForTesting(String userId) =>
      _cacheEpochFor(userId.trim());

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReports() {
    if (!isAdmin) return const Stream.empty();
    return firestore
        .collection('chat_reports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyReports() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return firestore
        .collection('chat_reports')
        .where('reporterId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  CollectionReference<Map<String, dynamic>> _attendance(int eventId) =>
      firestore
          .collection('event_attendance')
          .doc('$eventId')
          .collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEventAttendance(
    int eventId,
  ) => _attendance(eventId).snapshots();

  Future<String?> getMyAttendance(int eventId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    final snapshot = await _attendance(eventId).doc(user.uid).get();
    return snapshot.data()?['state'] as String?;
  }

  Future<void> setAttendance(int eventId, String state, {String? title}) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A részvétel mentéséhez regisztráció szükséges.');
    }
    if (!{'attending', 'not_attending'}.contains(state)) {
      throw ArgumentError('Érvénytelen részvételi állapot.');
    }
    await callFirebaseCallable<void>(
      'setEventAttendance',
      parameters: {
        'eventId': eventId,
        'state': state,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
  }

  CollectionReference<Map<String, dynamic>> _eventMeetups(int eventId) =>
      firestore.collection('event_meetups').doc('$eventId').collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEventMeetups(int eventId) {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return _eventMeetups(eventId).orderBy('createdAt').snapshots();
  }

  Future<bool> getMyMeetup(int eventId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return (await _eventMeetups(eventId).doc(user.uid).get()).exists;
  }

  Future<void> setMeetup(
    int eventId, {
    required String title,
    required bool enabled,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A Meetup használatához regisztráció szükséges.');
    }
    final attendance = await getMyAttendance(eventId);
    if (enabled && attendance != 'attending') {
      throw StateError('A Meetup használatához jelöld be, hogy ott leszel.');
    }
    final reference = _eventMeetups(eventId).doc(user.uid);
    if (!enabled) {
      await reference.delete();
      return;
    }
    final profile = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final data = profile.data() ?? const <String, dynamic>{};
    await reference.set({
      'eventId': eventId,
      'eventTitle': title.trim(),
      'userId': user.uid,
      'displayName': (data['displayName'] as String? ?? 'HUHS user').trim(),
      'imageUrl': resolveProfileImage(data, user.photoURL ?? ''),
      'interestedBy': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleMeetupInterest({
    required int eventId,
    required String meetupUserId,
    required bool interested,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A Meetup használatához regisztráció szükséges.');
    }
    if (meetupUserId.isEmpty || meetupUserId == user.uid) return;
    if (await getMyAttendance(eventId) != 'attending') {
      throw StateError('A Meetup használatához jelöld be, hogy ott leszel.');
    }
    final reference = _eventMeetups(eventId).doc(meetupUserId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('Ez a Meetup már nem érhető el.');
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      final interestedBy = Map<String, dynamic>.from(
        data['interestedBy'] as Map? ?? const {},
      );
      if (interested) {
        interestedBy[user.uid] = true;
      } else {
        interestedBy.remove(user.uid);
      }
      transaction.update(reference, {'interestedBy': interestedBy});
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlannedEvents() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return watchPlannedEventsFor(user.uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlannedEventsFor(
    String userId,
  ) {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || userId.isEmpty) {
      return const Stream.empty();
    }
    return firestore
        .collection('community_profiles')
        .doc(userId)
        .collection('planned_events')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  watchActivePlannedEventsFor(String userId) {
    return watchPlannedEventsFor(userId).asyncMap((snapshot) async {
      try {
        final activeIds = (await WordpressService().getEvents())
            .where((event) => !event.isPast)
            .map((event) => event.id)
            .toSet();
        return snapshot.docs
            .where((doc) {
              final value = doc.data()['eventId'];
              final eventId = value is num
                  ? value.toInt()
                  : int.tryParse('$value');
              return eventId != null && activeIds.contains(eventId);
            })
            .toList(growable: false);
      } catch (_) {
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  watchActivePlannedEvents() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const Stream.empty();
    }
    return watchActivePlannedEventsFor(user.uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConnections(String userId) {
    final viewer = auth.currentUser;
    if (viewer == null || viewer.isAnonymous) return const Stream.empty();
    return firestore
        .collection('community_profiles')
        .doc(userId)
        .collection('connections')
        .snapshots();
  }

  Future<void> pruneStaleConnections(String userId) async {
    final viewer = auth.currentUser;
    if (viewer == null || viewer.isAnonymous || userId != viewer.uid) return;
    await callFirebaseCallable<void>(
      'manageConnection',
      parameters: {'action': 'prune'},
    );
  }

  Future<List<Map<String, String>>> getFriendAttendees(int eventId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const [];
    final connections = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('connections')
        .get();
    if (connections.docs.isEmpty) return const [];
    final attendance = await _attendance(eventId).get();
    final attendeeIds = attendance.docs
        .where((doc) => doc.data()['state'] == 'attending')
        .map((doc) => doc.id)
        .toSet();
    final result = await Future.wait(
      connections.docs
          .where((connection) => attendeeIds.contains(connection.id))
          .map((connection) async {
            final data = connection.data();
            var name = (data['displayName'] as String? ?? '').trim();
            var image = (data['imageUrl'] as String? ?? '').trim();
            if (name.isEmpty || image.isEmpty) {
              final profileData = await getPublicProfile(connection.id);
              name = name.isEmpty
                  ? (profileData['displayName'] as String? ?? '').trim()
                  : name;
              image = image.isEmpty ? resolveProfileImage(profileData) : image;
            }
            return {'id': connection.id, 'name': name, 'image': image};
          }),
    );
    return result;
  }

  Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_unlock') ?? false;
  }

  Future<bool> deviceCodeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('device_code_unlock') ?? false;
  }

  Future<void> setDeviceCodeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_code_unlock', value);
    if (value) await prefs.setBool('biometric_unlock', false);
  }

  Future<bool> authenticatorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('authenticator_unlock') ?? false;
  }

  Future<String?> authenticatorSecret() =>
      _secureStorage.read(key: _totpSecretKey);

  Future<void> setAuthenticatorSecret(String secret) async {
    await _secureStorage.write(key: _totpSecretKey, value: secret);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('authenticator_unlock', true);
  }

  Future<void> setAuthenticatorEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('authenticator_unlock', value);
  }

  Future<bool> authenticateDeviceCode() async {
    try {
      final nativeResult = await _authChannel.invokeMethod<bool>(
        'deviceCredential',
      );
      if (nativeResult != null) return nativeResult;
    } on PlatformException {
      // Other platforms use the local_auth fallback below.
    } on MissingPluginException {
      // Other platforms use the local_auth fallback below.
    }
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Oldd fel a Hungarian Hardstyle profilodat',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> verifyAuthenticatorCode(String code) async {
    final secret = await authenticatorSecret();
    if (secret == null || secret.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final offset in const [-30, 0, 30]) {
      final expected = OTP.generateTOTPCodeString(
        secret,
        now + offset * 1000,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (OTP.constantTimeVerification(expected, code.trim())) return true;
    }
    return false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_unlock', value);
    if (value) await prefs.setBool('device_code_unlock', false);
  }

  Future<bool> authenticateBiometric() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) return false;
      if (!await auth.canCheckBiometrics) return false;
      if ((await auth.getAvailableBiometrics()).isEmpty) return false;
      return await auth.authenticate(
        localizedReason: 'Oldd fel a Hungarian Hardstyle profilodat',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> unlockBiometricSession(String userId) async {
    if (_biometricSessionUid == userId) return true;
    final active = _biometricRequest;
    if (active != null) return active;
    final request = authenticateBiometric();
    _biometricRequest = request;
    final unlocked = await request.whenComplete(() => _biometricRequest = null);
    if (unlocked) _biometricSessionUid = userId;
    return unlocked;
  }

  Future<bool> unlockProfileSession(
    String userId,
    Future<bool> Function() unlock,
  ) async {
    if (_profileSessionUid == userId) return true;
    final active = _profileUnlockRequest;
    if (active != null) return active;
    final request = unlock();
    _profileUnlockRequest = request;
    final unlocked = await request.whenComplete(
      () => _profileUnlockRequest = null,
    );
    if (unlocked) _profileSessionUid = userId;
    return unlocked;
  }

  static void resetBiometricSession() {
    _biometricSessionUid = null;
    _profileSessionUid = null;
  }

  Future<String?> connectionStatus(String otherUserId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || otherUserId == user.uid) {
      return null;
    }
    final ownConnection = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('connections')
        .doc(otherUserId)
        .get();
    if (ownConnection.exists) return 'accepted';
    final otherConnection = await firestore
        .collection('community_profiles')
        .doc(otherUserId)
        .collection('connections')
        .doc(user.uid)
        .get();
    if (otherConnection.exists) return 'accepted';
    final request = firestore
        .collection('connection_requests')
        .doc('${user.uid}_$otherUserId');
    final reverse = firestore
        .collection('connection_requests')
        .doc('${otherUserId}_${user.uid}');
    final own = await request.get();
    if (own.exists) return own.data()?['status'] as String?;
    final incoming = await reverse.get();
    if (!incoming.exists) return null;
    final status = incoming.data()?['status'] as String?;
    return status == 'accepted' ? 'accepted' : 'incoming:$status';
  }

  Future<void> requestConnection(String otherUserId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || otherUserId == user.uid) {
      throw StateError('Ismerős-jelöléshez regisztráció szükséges.');
    }
    await callFirebaseCallable<void>(
      'manageConnection',
      parameters: {'action': 'request', 'otherUid': otherUserId},
    );
  }

  Future<void> respondConnection(String fromUserId, bool accept) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Regisztráció szükséges.');
    }
    await callFirebaseCallable<void>(
      'manageConnection',
      parameters: {
        'action': 'respond',
        'otherUid': fromUserId,
        'accept': accept,
      },
    );
  }

  Future<void> removeConnection(String otherUserId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || otherUserId == user.uid) {
      throw StateError('Regisztráció szükséges.');
    }
    await callFirebaseCallable<void>(
      'manageConnection',
      parameters: {'action': 'remove', 'otherUid': otherUserId},
    );
  }

  Future<void> setUserRole(String userId, String role) async {
    await setAccountRole(userId, role);
  }

  Future<void> setAccountRole(String userId, String role) async {
    if (!isAdmin) throw StateError('Csak admin módosíthat szerepkört.');
    if (!{'dj', 'organizer', 'partygoer'}.contains(role)) {
      throw ArgumentError('Invalid account role.');
    }
    await firestore.collection('community_profiles').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAccessRole(String userId, String accessRole) async {
    if (!isAdmin) throw StateError('Csak admin adhat jogosultságot.');
    if (!{'none', 'moderator', 'admin'}.contains(accessRole)) {
      throw ArgumentError('Invalid access role.');
    }
    await firestore.collection('community_profiles').doc(userId).set({
      'accessRole': accessRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> deleteUser(String userId) async {
    if (!isAdmin) {
      throw StateError('Csak admin törölhet felhasználót.');
    }
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'deleteCommunityUser',
      parameters: <String, dynamic>{'uid': userId},
    );
    return result.data['cleanupStatus']?.toString() ?? 'completed';
  }

  Future<String> deleteOwnProfile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Nincs törölhető profil.');
    }
    final uid = user.uid;
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'deleteCommunityUser',
      parameters: <String, dynamic>{'uid': uid},
    );
    await _clearDeletedAccountState(uid);
    return result.data['cleanupStatus']?.toString() ?? 'completed';
  }

  Future<void> _clearDeletedAccountState(String uid) async {
    // Drop both the in-memory projections and the persisted profile/achievement
    // snapshots before signing out. Otherwise a deleted account can briefly
    // reappear when the app returns to the anonymous home screen.
    clearPublicProfileCache();
    _adminCache.clear();
    _adminRequests.clear();
    final prefs = await SharedPreferences.getInstance();
    final userCacheKeys = prefs.getKeys().where(
      (key) =>
          key == 'favorite_items' ||
          key.contains(uid) ||
          key.startsWith('huhs.public.profile.$uid.') ||
          key.startsWith('huhs.public.achievement.$uid.'),
    );
    for (final key in <String>{
      ...userCacheKeys,
      'biometric_unlock',
      'device_code_unlock',
      'authenticator_unlock',
      'fcm_token',
      'fcm_token_refresh_v3',
    }) {
      await prefs.remove(key);
    }
    await _secureStorage.delete(key: _totpSecretKey);
    _cachedRole = '';
    _cachedAccessRole = accessNone;
    resetBiometricSession();
    await WordpressService().clearPublicCache();
    try {
      await GoogleSignIn().disconnect();
    } on PlatformException {
      // No revocable Google grant is a valid state; local and Firebase
      // cleanup must still complete.
    }
    await auth.signOut();
  }

  Future<dynamic> wordPressAdminRequest({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('A vezérlőközpont használatához jelentkezz be.');
    }
    final normalizedMethod = method.toUpperCase();
    final uid = auth.currentUser?.uid.trim();
    final cacheKey = uid == null || uid.isEmpty ? null : '$uid:$path';
    if (normalizedMethod == 'GET' && cacheKey != null) {
      final cached = _adminCache[cacheKey];
      if (cached != null && cached.isFresh) return cached.value;
      final existing = _adminRequests[cacheKey];
      if (existing != null) return existing;
      final request = _fetchWordPressAdmin(
        path: path,
        method: normalizedMethod,
        body: body,
      );
      _adminRequests[cacheKey] = request;
      try {
        final value = await request;
        _adminCache[cacheKey] = _AdminCacheEntry(value);
        return value;
      } finally {
        if (identical(_adminRequests[cacheKey], request)) {
          _adminRequests.remove(cacheKey);
        }
      }
    }
    final value = await _fetchWordPressAdmin(
      path: path,
      method: normalizedMethod,
      body: body,
    );
    if (normalizedMethod != 'GET' && uid != null && uid.isNotEmpty) {
      _adminCache.removeWhere((key, _) => key.startsWith('$uid:'));
    }
    return value;
  }

  /// Forces the next HUHS admin request to read the current WordPress data.
  /// A manual refresh must refresh the current voting state as well as rebuild
  /// the screen.
  void clearAdminCache() {
    _adminCache.clear();
    _adminRequests.clear();
  }

  Future<dynamic> _fetchWordPressAdmin({
    required String path,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final result = await callFirebaseCallable<dynamic>(
      'wordPressAdminRequest',
      parameters: {'path': path, 'method': method, 'body': ?body},
    );
    return result.data;
  }

  Future<List<Map<String, dynamic>>> wordPressSubmissions() async {
    final currentUser = auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('A beküldések megtekintéséhez jelentkezz be.');
    }
    final result = await callFirebaseCallable<List<dynamic>>(
      'listWordPressSubmissions',
    );
    final items = result.data;
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> manageWordPressSubmission({
    required int id,
    required String action,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('A beküldések kezeléséhez jelentkezz be.');
    }
    await callFirebaseCallable<void>(
      'manageWordPressSubmission',
      parameters: {'id': id, 'action': action},
    );
  }

  Future<void> updateWordPressSubmission({
    required int id,
    required String title,
    required String content,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('A beküldések szerkesztéséhez jelentkezz be.');
    }
    await callFirebaseCallable<void>(
      'updateWordPressSubmission',
      parameters: {'id': id, 'title': title, 'content': content},
    );
  }

  Future<String> uploadImage(
    Uint8List bytes, {
    String filename = 'upload.jpg',
  }) async {
    if (bytes.isEmpty ||
        bytes.length > maxUploadBytes ||
        !isSupportedImageBytes(bytes)) {
      throw StateError(
        'Csak érvényes JPG, PNG vagy WebP kép tölthető fel (max. 5 MB).',
      );
    }
    return (await uploadImageWithMetadata(bytes, filename: filename)).url;
  }

  Future<CloudinaryUploadResult> uploadImageWithMetadata(
    Uint8List bytes, {
    String filename = 'upload.jpg',
    bool userScoped = false,
  }) async {
    if (bytes.isEmpty ||
        bytes.length > maxUploadBytes ||
        !isSupportedImageBytes(bytes)) {
      throw StateError(
        'Csak érvényes JPG, PNG vagy WebP kép tölthető fel (max. 5 MB).',
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': uploadPreset,
        if (userScoped && auth.currentUser?.uid != null)
          'folder': 'huhs_users/${auth.currentUser!.uid}',
      }),
    );
    final url = response.data?['secure_url'];
    if (url is! String || url.isEmpty) {
      throw StateError('A kép feltöltése sikertelen.');
    }
    return CloudinaryUploadResult(
      url: url,
      publicId: (response.data?['public_id'] as String? ?? '').trim(),
    );
  }

  String resolveProfileImage(
    Map<String, dynamic> data, [
    String fallback = '',
  ]) {
    for (final key in const ['profileSourceImageUrl', 'profileImageUrl']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        final version = (data['profileVersion'] ?? '').toString().trim();
        if (version.isEmpty) return value.trim();
        final separator = value.contains('?') ? '&' : '?';
        return '${value.trim()}${separator}huhs_profile_v=${Uri.encodeComponent(version)}';
      }
    }
    return fallback.trim();
  }

  /// Adds a CDN thumbnail transformation without changing the stored URL: the
  /// server keeps owning the original image.
  ///
  /// Cloudinary assets use Cloudinary's own transform. Community avatars that
  /// still point at the WordPress media library are sized through Photon, so a
  /// 40 px avatar no longer downloads the full 1.5 MB featured image. Every
  /// other host (Gravatar, Google, …) is returned untouched.
  static String optimizedImageUrl(String url, {required int width}) {
    final value = url.trim();
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (!uri.host.contains('cloudinary.com')) {
      return WordpressImageUrl.resized(value, physicalWidth: width);
    }
    final marker = '/image/upload/';
    final index = uri.path.indexOf(marker);
    if (index < 0) return value;
    final afterUpload = index + marker.length;
    final remainder = uri.path.substring(afterUpload);
    if (remainder.startsWith('f_auto,q_auto,')) return value;
    final safeWidth = width.clamp(42, 720);
    final transformedPath =
        '${uri.path.substring(0, afterUpload)}'
        'f_auto,q_auto,w_$safeWidth,c_limit/$remainder';
    return uri.replace(path: transformedPath).toString();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> profile({
    bool forceServer = false,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A profil megtekintéséhez regisztráció szükséges.');
    }
    final uid = user.uid;
    final cached = _profileCache[uid];
    final cachedAt = _profileCacheFetchedAt[uid];
    if (!forceServer &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _profileCacheTtl) {
      unawaited(_refreshProfileInBackground(user));
      _cacheProfileRoleFromSnapshot(user, cached);
      return cached;
    }
    if (_isAdmin(user.email)) {
      // Admin role is derived from the authenticated account immediately;
      // keeping this merge in the background prevents an admin profile paint
      // from waiting on a write round trip.
      unawaited(_ensureAdminProfile(user));
    }
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore
          .collection('community_profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (snapshot.exists && !forceServer) {
        _storeProfileCache(uid, snapshot);
        _cacheProfileRoleFromSnapshot(user, snapshot);
        unawaited(_refreshProfileInBackground(user));
        return snapshot;
      }
    } catch (_) {
      // No local snapshot yet; fall through to the server request.
    }
    return _refreshProfileInBackground(user);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _refreshProfileInBackground(
    User user,
  ) async {
    final existing = _profileRefreshRequests[user.uid];
    if (existing != null) return existing;
    final request = firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    _profileRefreshRequests[user.uid] = request;
    try {
      final snapshot = await request;
      if (auth.currentUser?.uid == user.uid) {
        _storeProfileCache(user.uid, snapshot);
        _cacheProfileRoleFromSnapshot(user, snapshot);
      }
      return snapshot;
    } finally {
      if (identical(_profileRefreshRequests[user.uid], request)) {
        _profileRefreshRequests.remove(user.uid);
      }
    }
  }

  void _cacheProfileRoleFromSnapshot(
    User user,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final role = _isAdmin(user.email) ? 'organizer' : data['role'] as String?;
    _cachedRole = accountRole(role);
    _cachedAccessRole = _isAdmin(user.email)
        ? accessAdmin
        : (data['accessRole'] as String? ??
              (role == accessAdmin ? accessAdmin : accessNone));
    _cachedRoleUid = user.uid;
    final displayName = (data['displayName'] as String? ?? '').trim();
    final profileIsComplete =
        displayName.length >= 2 &&
        displayName.length <= 40 &&
        !displayName.contains('@') &&
        const {'dj', 'organizer', 'partygoer'}.contains(role);
    if (!profileIsComplete) return;
    // This one-time achievement check must not delay the profile's first
    // paint. The server-side operation is idempotent and can complete in the
    // background while the already available profile is rendered.
    unawaited(_claimProfileCompletionAchievement());
  }

  static void _storeProfileCache(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    _profileCache[uid] = snapshot;
    _profileCacheFetchedAt[uid] = DateTime.now();
  }

  static void clearProfileCache([String? uid]) {
    if (uid == null || uid.trim().isEmpty) {
      _profileCache.clear();
      _profileCacheFetchedAt.clear();
      return;
    }
    final normalizedUid = uid.trim();
    _profileCache.remove(normalizedUid);
    _profileCacheFetchedAt.remove(normalizedUid);
  }

  Future<void> _claimProfileCompletionAchievement() async {
    try {
      await callFirebaseCallable<void>('claimProfileCompletionAchievement');
    } catch (_) {
      // Profile loading remains available if the one-time reward check is unavailable.
    }
  }

  /// Warms the signed-in user's profile while the startup screen is visible.
  /// The profile screen can therefore render from the fast Firestore path
  /// instead of waiting for its first network round trip.
  Future<void> preloadOwnProfile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await Future.wait<void>([
        profile().then<void>((_) {}),
        getPublicProfile(user.uid).then<void>((_) {}),
      ]);
    } catch (_) {
      // Startup preloading is opportunistic and must never block app launch.
    }
  }

  /// Warms the first HUHS controller response during the startup screen.
  /// This is opportunistic and only runs after the signed-in account's role
  /// has been loaded, so regular users do not make an admin request.
  Future<void> preloadWordPressAdmin() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await profile();
      if (!isAdmin) return;
      await wordPressAdminRequest(path: '/huhs/v1/admin?action=dashboard');
    } catch (_) {
      // Admin preloading must never delay or break app startup.
    }
  }

  Future<void> signOut() async {
    // Public profile/achievement responses are safe to share between users,
    // but retaining them across an account switch makes the next session
    // appear to have stale community state. Clear both the per-user entries
    // and the in-flight/list cache at the session boundary.
    clearPublicProfileCache();
    clearProfileCache();
    _cachedRole = '';
    _cachedAccessRole = accessNone;
    _cachedRoleUid = null;
    resetBiometricSession();
    // Firebase sign-out alone leaves Google Sign-In's last account selected,
    // so the next Google registration silently reuses the previous account.
    try {
      await GoogleSignIn().signOut();
    } finally {
      await auth.signOut();
    }
  }

  /// Refreshes the restored Auth session without treating transient network
  /// failures or a missing Firestore profile as account deletion.
  Future<Map<String, bool>> refreshCurrentSession() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const {'active': true, 'emailVerifiedChanged': false};
    }
    final wasVerified = user.emailVerified;
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      if (!{
        'user-not-found',
        'user-disabled',
        'invalid-user-token',
        'user-token-expired',
      }.contains(error.code)) {
        rethrow;
      }
      await _clearDeletedAccountState(user.uid);
      return {
        'active': false,
        'deleted': error.code == 'user-not-found',
        'emailVerifiedChanged': false,
      };
    }
    // A Google-fiokkal (vagy barmilyen kulso szolgaltatoval) regisztralt
    // felhasznalo Auth-fiokja egy UJ bejelentkezessel ujra letrejon, UGYANAZZAL a
    // UID-dal. Ezert a torlest nem az Auth hibaja jelzi, hanem a szerveroldali
    // `deleted_user_ids` jelzo. Enelkul a torolt felhasznalo visszajott, es a
    // felulet erthetetlen hibakat dobalt (minden `isRegistered()` szabaly tiltja).
    if (await isAccountMarkedDeleted(user.uid)) {
      await _clearDeletedAccountState(user.uid);
      return {
        'active': false,
        'deleted': true,
        'emailVerifiedChanged': false,
      };
    }
    final refreshed = auth.currentUser;
    final emailVerifiedChanged =
        !wasVerified && refreshed?.emailVerified == true;
    if (emailVerifiedChanged) {
      try {
        await syncEmailChange();
      } catch (_) {
        // Retry on the next session refresh; verification itself succeeded.
      }
    }
    return {
      'active': refreshed != null,
      'emailVerifiedChanged': emailVerifiedChanged,
    };
  }

  /// Igaz, ha a szerver a felhasznalot toroltkent tartja nyilvan.
  ///
  /// A `deleted_user_ids` sor kizarolag a sajat UID-ra olvashato (lasd
  /// `firestore.rules`). Hálózati vagy jogosultsagi hiba eseten **false**-t adunk:
  /// egy atmeneti hiba soha nem zárhat ki egy legitim felhasznalot.
  Future<bool> isAccountMarkedDeleted(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return false;
    try {
      final snapshot = await firestore
          .collection('deleted_user_ids')
          .doc(trimmed)
          .get();
      return snapshot.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheProfileRole() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await profile();
    } catch (_) {}
  }

  Future<void> _ensureAdminProfile(User user) async {
    if (!_isAdmin(user.email)) return;
    await firestore.collection('community_profiles').doc(user.uid).set({
      'role': 'organizer',
      'accessRole': accessAdmin,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
