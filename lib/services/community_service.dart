import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

import '../models/community_post.dart';
import 'wordpress_service.dart';

class CommunityService {
  static const cloudName = 'fjxo93em';
  static const uploadPreset = 'Hun_hs_Mobile';
  static const adminEmail = 'djdeeroy@gmail.com';
  static const firestoreDatabaseId = 'hungarian-hardstyle';
  static const accessNone = 'none';
  static const accessModerator = 'moderator';
  static const accessAdmin = 'admin';
  static const maxUploadBytes = 5 * 1024 * 1024;
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
          final user = auth.currentUser;
          final blocked = <String>{};
          if (user != null && !user.isAnonymous) {
            final blockedSnapshot = await firestore
                .collection('community_profiles')
                .doc(user.uid)
                .collection('blocked_users')
                .get();
            blocked.addAll(blockedSnapshot.docs.map((doc) => doc.id));
          }
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
    await FirebaseFunctions.instance
        .httpsCallable('deletePrivateConversation')
        .call({'conversationId': conversationId});
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
  }) async {
    final user = auth.currentUser;
    final trimmed = maskProfanity(text.trim());
    if (user == null || user.isAnonymous) {
      throw StateError('Privát üzenet küldéséhez regisztráció szükséges.');
    }
    if (otherUserId.isEmpty || otherUserId == user.uid) {
      throw ArgumentError('Érvénytelen címzett.');
    }
    if (trimmed.isEmpty || trimmed.length > 2000) {
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

    final otherProfile = await firestore
        .collection('community_profiles')
        .doc(otherUserId)
        .get();
    if (!otherProfile.exists) throw StateError('A felhasználó nem található.');
    final ownProfile = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final ownData = ownProfile.data() ?? const <String, dynamic>{};
    final otherData = otherProfile.data() ?? const <String, dynamic>{};
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
      'lastMessage': trimmed,
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await conversation.collection('messages').add({
      'senderId': user.uid,
      'recipientId': otherUserId,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
    Map<String, String>? socialLinks,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName.trim());
      final accountRole = _isAdmin(normalizedEmail)
          ? 'organizer'
          : this.accountRole(role);
      await firestore.collection('community_profiles').doc(user.uid).set({
        'displayName': displayName.trim(),
        'role': accountRole,
        'accessRole': _isAdmin(user.email) ? accessAdmin : accessNone,
        'email': normalizedEmail,
        ...?(socialLinks == null ? null : {'socialLinks': socialLinks}),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Save the profile before sending the mail. Otherwise a profile-write
      // failure can surface as a false registration error after the mail was
      // already delivered.
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      await user.reload();
      if (auth.currentUser?.emailVerified != true) {
        await auth.signOut();
        throw StateError(
          'Erősítsd meg az e-mail-címedet a kapott levélben, majd próbáld újra.',
        );
      }
      await _ensureAdminProfile(user);
      await _cacheProfileRole();
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> resendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Nincs ellenőrizhető e-mailes fiók.');
    }
    await user.sendEmailVerification();
  }

  Future<void> resendEmailVerificationForCredentials({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await credential.user!.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    } finally {
      await auth.signOut();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
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

  String _authError(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'A megadott e-mail-cím vagy jelszó hibás.',
    'invalid-email' => 'Érvénytelen e-mail-cím.',
    'email-already-in-use' => 'Ez az e-mail-cím már használatban van.',
    'weak-password' => 'A jelszó túl gyenge.',
    'requires-recent-login' => 'A módosításhoz jelentkezz be újra.',
    'network-request-failed' => 'Hálózati hiba. Próbáld újra később.',
    _ => 'A bejelentkezés nem sikerült. Próbáld újra.',
  };

  Future<bool> signInWithGoogle({
    String? role,
    String? displayName,
    Map<String, String>? socialLinks,
    Future<String?> Function()? requestDisplayName,
  }) async {
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) return false;
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      final result = await auth.signInWithCredential(credential);
      final user = result.user!;
      final profile = firestore.collection('community_profiles').doc(user.uid);
      try {
        final existing = await profile.get();
        final existingData = existing.data() ?? const <String, dynamic>{};
        var chosenDisplayName = displayName?.trim() ?? '';
        final savedDisplayName = (existingData['displayName'] as String? ?? '')
            .trim();
        if (chosenDisplayName.isEmpty && savedDisplayName.isEmpty) {
          chosenDisplayName = (await requestDisplayName?.call() ?? '').trim();
          if (chosenDisplayName.isEmpty) {
            await signOut();
            return false;
          }
        }
        final existingRole = existingData['role'] as String?;
        final existingAccessRole =
            existingData['accessRole'] as String? ??
            (existingRole == accessAdmin ? accessAdmin : accessNone);
        await profile.set({
          if (!existing.exists ||
              ((existingData['displayName'] as String?) ?? '').trim().isEmpty)
            'displayName': (displayName?.trim().isNotEmpty == true
                ? displayName!.trim()
                : (savedDisplayName.isNotEmpty
                      ? savedDisplayName
                      : chosenDisplayName)),
          'email': user.email,
          if (_isAdmin(user.email)) 'role': 'organizer',
          if (_isAdmin(user.email)) 'accessRole': accessAdmin,
          if (!_isAdmin(user.email) && existingRole == null && role != null)
            'role': role,
          if (!_isAdmin(user.email) &&
              existingRole == null &&
              socialLinks != null)
            'socialLinks': socialLinks,
          if (!_isAdmin(user.email) && existingData['accessRole'] == null)
            'accessRole': existingAccessRole,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _cachedRole = _isAdmin(user.email)
            ? 'organizer'
            : accountRole(existingRole ?? role);
        _cachedAccessRole = _isAdmin(user.email)
            ? accessAdmin
            : existingAccessRole;
      } catch (_) {
        // Authentication remains successful if Firestore is temporarily unavailable.
      }
      await _ensureAdminProfile(user);
      await _cacheProfileRole();
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_failed' || error.code == '10') {
        throw StateError(
          'A Google-belépés Firebase-beállítása hiányos. Engedélyezd a Google szolgáltatót, add hozzá az Android SHA-1/SHA-256 kulcsot, majd töltsd le újra a google-services.json fájlt.',
        );
      }
      rethrow;
    }
  }

  bool _isAdmin(String? email) => email?.trim().toLowerCase() == adminEmail;

  bool get isOwner => _isAdmin(auth.currentUser?.email);

  bool get isAdmin =>
      _isAdmin(auth.currentUser?.email) ||
      _cachedAccessRole == accessAdmin ||
      _cachedRole == accessAdmin;

  String get cachedAccountRole => accountRole(_cachedRole);

  bool get canModerate => isAdmin || _cachedAccessRole == accessModerator;

  String accountRole(String? value) {
    if (value == accessAdmin || value == 'organizer') return 'organizer';
    if (value == 'dj' || value == 'partygoer') return value!;
    return 'partygoer';
  }

  Future<void> publishPost({
    required String text,
    Uint8List? imageBytes,
    bool pinned = false,
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
    if (imageBytes != null) {
      imageUrl = await uploadImage(imageBytes, filename: 'chat.jpg');
    }
    final profile = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final profileData = profile.data() ?? const <String, dynamic>{};
    final displayName = isAnonymous
        ? 'Unknown User ${_anonymousNumber(user.uid)}'
        : (profileData['displayName'] as String? ??
              user.displayName ??
              'HUHS user');
    await firestore.collection('live_feed_posts').add({
      'authorId': user.uid,
      'authorName': displayName,
      'authorImageUrl': isAnonymous ? '' : resolveProfileImage(profileData),
      'authorRole': isAnonymous
          ? ''
          : accountRole(profileData['role'] as String?),
      'authorAccessRole': isAnonymous
          ? ''
          : (profileData['accessRole'] == accessAdmin ||
                    profileData['accessRole'] == accessModerator
                ? profileData['accessRole'] as String
                : accessNone),
      'text': trimmed,
      'imageUrl': imageUrl,
      'reactions': <String, int>{},
      'reactionBy': <String, String>{},
      'pinned': pinned,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleReaction({
    required String postId,
    required String emoji,
  }) async {
    final user = await ensureAnonymousUser();
    final reference = firestore.collection('live_feed_posts').doc(postId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? <String, dynamic>{};
      final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map? ?? <String, dynamic>{},
      );
      final reactionBy = Map<String, dynamic>.from(
        data['reactionBy'] as Map? ?? <String, dynamic>{},
      );
      final previous = reactionBy[user.uid] as String?;
      if (previous == emoji) {
        final count = (reactions[emoji] as num?)?.toInt() ?? 0;
        if (count <= 1) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = count - 1;
        }
        reactionBy.remove(user.uid);
      } else {
        if (previous != null) {
          final count = (reactions[previous] as num?)?.toInt() ?? 0;
          if (count <= 1) {
            reactions.remove(previous);
          } else {
            reactions[previous] = count - 1;
          }
        }
        reactions[emoji] = ((reactions[emoji] as num?)?.toInt() ?? 0) + 1;
        reactionBy[user.uid] = emoji;
      }
      transaction.update(reference, {
        'reactions': reactions,
        'reactionBy': reactionBy,
      });
    });
  }

  Future<void> deletePost(String postId) async {
    if (!isAdmin && _cachedAccessRole == accessNone) {
      await _cacheProfileRole();
    }
    if (!isAdmin) {
      throw StateError('Csak admin törölhet Chat-üzenetet.');
    }
    await firestore.collection('live_feed_posts').doc(postId).delete();
  }

  Future<void> updatePostText({
    required String postId,
    required String text,
  }) async {
    if (!isAdmin) {
      throw StateError('Csak admin szerkeszthet Chat-üzenetet.');
    }
    final trimmed = maskProfanity(text.trim());
    if (trimmed.isEmpty) throw ArgumentError('Az üzenet nem lehet üres.');
    await firestore.collection('live_feed_posts').doc(postId).update({
      'text': trimmed,
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
  }

  Future<void> claimArtist(int artistId) async {
    if (auth.currentUser?.emailVerified != true) {
      throw StateError('Hitelesített e-mailes fiók szükséges.');
    }
    await FirebaseFunctions.instance.httpsCallable('claimArtistProfile').call({
      'artistId': artistId,
    });
  }

  Future<bool> isArtistClaimed(int artistId) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getArtistClaimStatus')
        .call({'artistId': artistId});
    return (result.data as Map?)?['claimed'] == true;
  }

  Future<List<int>> myClaimedArtists() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getMyClaimedArtists')
        .call();
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String userId) {
    return firestore.collection('community_profiles').doc(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReports() {
    if (!isAdmin) return const Stream.empty();
    return firestore
        .collection('chat_reports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRegisteredProfiles() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return const Stream.empty();
    return firestore.collection('community_profiles').limit(200).snapshots();
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
    await _attendance(eventId).doc(user.uid).set({
      'eventId': eventId,
      'state': state,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final planned = firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('planned_events')
        .doc('$eventId');
    if (state == 'attending') {
      await planned.set({
        'eventId': eventId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'state': state,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await planned.delete();
    }
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
    if (viewer == null || viewer.isAnonymous || userId.isEmpty) return;
    final connections = await firestore
        .collection('community_profiles')
        .doc(userId)
        .collection('connections')
        .get();
    final stale = <String>[];
    for (final connection in connections.docs) {
      final profile = await firestore
          .collection('community_profiles')
          .doc(connection.id)
          .get();
      if (!profile.exists) stale.add(connection.id);
    }
    if (stale.isEmpty) return;
    final batch = firestore.batch();
    for (final otherUserId in stale) {
      batch.delete(
        firestore
            .collection('community_profiles')
            .doc(userId)
            .collection('connections')
            .doc(otherUserId),
      );
    }
    await batch.commit();
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
    final result = <Map<String, String>>[];
    for (final connection in connections.docs) {
      if (!attendeeIds.contains(connection.id)) continue;
      final data = connection.data();
      var name = (data['displayName'] as String? ?? '').trim();
      var image = (data['imageUrl'] as String? ?? '').trim();
      if (name.isEmpty || image.isEmpty) {
        final profile = await firestore
            .collection('community_profiles')
            .doc(connection.id)
            .get();
        final profileData = profile.data() ?? const <String, dynamic>{};
        name = name.isEmpty
            ? (profileData['displayName'] as String? ?? '').trim()
            : name;
        image = image.isEmpty ? resolveProfileImage(profileData) : image;
      }
      result.add({'id': connection.id, 'name': name, 'image': image});
    }
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
    final ownConnection = firestore
        .collection('community_profiles')
        .doc(user.uid)
        .collection('connections')
        .doc(otherUserId);
    final otherConnection = firestore
        .collection('community_profiles')
        .doc(otherUserId)
        .collection('connections')
        .doc(user.uid);
    if ((await ownConnection.get()).exists ||
        (await otherConnection.get()).exists) {
      return;
    }
    final requestRef = firestore
        .collection('connection_requests')
        .doc('${user.uid}_$otherUserId');
    final existing = await requestRef.get();
    if (existing.data()?['status'] == 'pending') {
      await requestRef.update({
        'notificationRequestedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    if (existing.exists) await requestRef.delete();
    final profile = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final profileData = profile.data() ?? const <String, dynamic>{};
    final senderName =
        (profileData['displayName'] as String? ??
                user.displayName ??
                user.email ??
                'Felhasználó')
            .trim();
    await requestRef.set({
      'from': user.uid,
      'to': otherUserId,
      'fromName': senderName,
      'fromImageUrl': resolveProfileImage(profileData, user.photoURL ?? ''),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'notificationRequestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondConnection(String fromUserId, bool accept) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Regisztráció szükséges.');
    }
    final status = accept ? 'accepted' : 'rejected';
    final requestRef = firestore
        .collection('connection_requests')
        .doc('${fromUserId}_${user.uid}');
    final requestSnapshot = await requestRef.get();
    if (!requestSnapshot.exists) {
      throw StateError('Az ismerős-kérés már nem érhető el.');
    }
    final batch = firestore.batch();
    batch.update(requestRef, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (accept) {
      batch.set(
        firestore
            .collection('community_profiles')
            .doc(user.uid)
            .collection('connections')
            .doc(fromUserId),
        {
          'userId': fromUserId,
          'displayName': requestSnapshot.data()?['fromName'] ?? '',
          'imageUrl': requestSnapshot.data()?['fromImageUrl'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      final targetProfile = await firestore
          .collection('community_profiles')
          .doc(user.uid)
          .get();
      final targetData = targetProfile.data() ?? const <String, dynamic>{};
      batch.set(
        firestore
            .collection('community_profiles')
            .doc(fromUserId)
            .collection('connections')
            .doc(user.uid),
        {
          'userId': user.uid,
          'displayName': targetData['displayName'] ?? '',
          'imageUrl': resolveProfileImage(targetData, user.photoURL ?? ''),
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  Future<void> removeConnection(String otherUserId) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || otherUserId == user.uid) {
      throw StateError('Regisztráció szükséges.');
    }
    final batch = firestore.batch();
    batch.delete(
      firestore
          .collection('community_profiles')
          .doc(user.uid)
          .collection('connections')
          .doc(otherUserId),
    );
    batch.delete(
      firestore
          .collection('community_profiles')
          .doc(otherUserId)
          .collection('connections')
          .doc(user.uid),
    );
    final requestRefs = [
      firestore
          .collection('connection_requests')
          .doc('${user.uid}_$otherUserId'),
      firestore
          .collection('connection_requests')
          .doc('${otherUserId}_${user.uid}'),
    ];
    final requestSnapshots = await Future.wait(
      requestRefs.map((reference) => reference.get()),
    );
    for (var index = 0; index < requestRefs.length; index++) {
      if (requestSnapshots[index].exists) batch.delete(requestRefs[index]);
    }
    await batch.commit();
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

  Future<void> deleteUser(String userId) async {
    if (!isAdmin) {
      throw StateError('Csak admin törölhet felhasználót.');
    }
    await FirebaseFunctions.instance.httpsCallable('deleteCommunityUser').call(
      <String, dynamic>{'uid': userId},
    );
  }

  Future<void> deleteOwnProfile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Nincs törölhető profil.');
    }
    await FirebaseFunctions.instance.httpsCallable('deleteCommunityUser').call(
      <String, dynamic>{'uid': user.uid},
    );
    await _clearDeletedAccountState();
  }

  Future<void> _clearDeletedAccountState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      'biometric_unlock',
      'device_code_unlock',
      'authenticator_unlock',
      'fcm_token',
      'fcm_token_refresh_v3',
    ]) {
      await prefs.remove(key);
    }
    await _secureStorage.delete(key: _totpSecretKey);
    _cachedRole = '';
    _cachedAccessRole = accessNone;
    resetBiometricSession();
    await auth.signOut();
  }

  Future<dynamic> wordPressAdminRequest({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (!isAdmin) {
      throw StateError('Csak admin használhatja a WordPress vezérlőközpontot.');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('wordPressAdminRequest')
        .call({'path': path, 'method': method, 'body': ?body});
    return result.data;
  }

  Future<List<Map<String, dynamic>>> wordPressSubmissions() async {
    if (!isAdmin) {
      throw StateError('Csak admin tekintheti meg a beküldéseket.');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('listWordPressSubmissions')
        .call();
    final items = result.data is List ? result.data as List : const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> manageWordPressSubmission({
    required int id,
    required String action,
  }) async {
    if (!isAdmin) {
      throw StateError('Csak admin kezelheti a beküldéseket.');
    }
    await FirebaseFunctions.instance
        .httpsCallable('manageWordPressSubmission')
        .call({'id': id, 'action': action});
  }

  Future<void> updateWordPressSubmission({
    required int id,
    required String title,
    required String content,
  }) async {
    if (!isAdmin) throw StateError('Csak admin szerkeszthet beküldést.');
    await FirebaseFunctions.instance
        .httpsCallable('updateWordPressSubmission')
        .call({'id': id, 'title': title, 'content': content});
  }

  Future<String> uploadImage(
    Uint8List bytes, {
    String filename = 'upload.jpg',
  }) async {
    if (bytes.isEmpty || bytes.length > maxUploadBytes) {
      throw StateError('A kép legfeljebb 5 MB lehet.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': uploadPreset,
      }),
    );
    final url = response.data?['secure_url'];
    if (url is! String || url.isEmpty) {
      throw StateError('A kép feltöltése sikertelen.');
    }
    return url;
  }

  String resolveProfileImage(
    Map<String, dynamic> data, [
    String fallback = '',
  ]) {
    for (final key in const ['profileSourceImageUrl', 'profileImageUrl']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback.trim();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> profile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A profil megtekintéséhez regisztráció szükséges.');
    }
    if (_isAdmin(user.email)) {
      await _ensureAdminProfile(user);
    }
    var snapshot = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final role = _isAdmin(user.email) ? 'organizer' : data['role'] as String?;
    _cachedRole = accountRole(role);
    _cachedAccessRole = _isAdmin(user.email)
        ? accessAdmin
        : (data['accessRole'] as String? ??
              (role == accessAdmin ? accessAdmin : accessNone));
    return snapshot;
  }

  Future<void> signOut() async {
    _cachedRole = '';
    _cachedAccessRole = accessNone;
    resetBiometricSession();
    await auth.signOut();
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

  static String _anonymousNumber(String uid) {
    final value = uid.codeUnits.fold<int>(17, (hash, code) => hash * 31 + code);
    return (value.abs() % 9000 + 1000).toString();
  }
}
