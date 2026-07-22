import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/community_post.dart';

class CommunityService {
  static const cloudName = 'fjxo93em';
  static const uploadPreset = 'Hun_hs_Mobile';
  static const adminEmail = 'djdeeroy@gmail.com';
  static const firestoreDatabaseId = 'hungarian-hardstyle';
  static const accessNone = 'none';
  static const accessModerator = 'moderator';
  static const accessAdmin = 'admin';
  static const maxUploadBytes = 5 * 1024 * 1024;

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
        .map(
          (snapshot) => snapshot.docs
              .map(CommunityPost.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName.trim());
      final accountRole = _isAdmin(email)
          ? 'organizer'
          : this.accountRole(role);
      await firestore.collection('community_profiles').doc(user.uid).set({
        'displayName': displayName.trim(),
        'role': accountRole,
        'accessRole': _isAdmin(user.email) ? accessAdmin : accessNone,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await _ensureAdminProfile(user);
      await _cacheProfileRole();
    } on FirebaseAuthException catch (error) {
      throw StateError(_authError(error.code));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
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
    'network-request-failed' => 'Hálózati hiba. Próbáld újra később.',
    _ => 'A bejelentkezés nem sikerült. Próbáld újra.',
  };

  Future<void> signInWithGoogle({String? role}) async {
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) return;
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
        final existingRole = existingData['role'] as String?;
        final existingAccessRole =
            existingData['accessRole'] as String? ??
            (existingRole == accessAdmin ? accessAdmin : accessNone);
        await profile.set({
          'displayName': user.displayName ?? 'Hungarian Hardstyle user',
          'email': user.email,
          if (_isAdmin(user.email)) 'role': 'organizer',
          if (_isAdmin(user.email)) 'accessRole': accessAdmin,
          if (!_isAdmin(user.email) && existingRole == null && role != null)
            'role': role,
          if (!_isAdmin(user.email) && existingData['accessRole'] == null)
            'accessRole': existingAccessRole,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _cachedRole = _isAdmin(user.email)
            ? 'organizer'
            : (existingRole == accessAdmin
                  ? 'organizer'
                  : (existingRole ?? role ?? ''));
        _cachedAccessRole = _isAdmin(user.email)
            ? accessAdmin
            : existingAccessRole;
      } catch (_) {
        // Authentication remains successful if Firestore is temporarily unavailable.
      }
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

  bool get isAdmin =>
      _isAdmin(auth.currentUser?.email) ||
      _cachedAccessRole == accessAdmin ||
      _cachedRole == accessAdmin;

  bool get canModerate => isAdmin || _cachedAccessRole == accessModerator;

  String accountRole(String? value) {
    if (value == accessAdmin || value == 'organizer') return 'organizer';
    if (value == 'dj' || value == 'partygoer') return value!;
    return 'partygoer';
  }

  Future<void> publishPost({
    required String text,
    Uint8List? imageBytes,
  }) async {
    final user = await ensureAnonymousUser();
    final isAnonymous = user.isAnonymous;
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageBytes == null) {
      throw ArgumentError('A bejegyzés szövege vagy képe kötelező.');
    }
    if (isAnonymous && imageBytes != null) {
      throw StateError('Névtelen felhasználó nem tölthet fel képet.');
    }

    String imageUrl = '';
    if (imageBytes != null) {
      imageUrl = await uploadImage(imageBytes);
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
      'authorImageUrl': isAnonymous
          ? ''
          : (profileData['profileImageUrl'] as String? ?? ''),
      'authorRole': isAnonymous
          ? ''
          : accountRole(profileData['role'] as String?),
      'authorAccessRole': isAnonymous
          ? ''
          : (profileData['accessRole'] as String? ?? accessNone),
      'text': trimmed,
      'imageUrl': imageUrl,
      'reactions': <String, int>{},
      'reactionBy': <String, String>{},
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
    if (!canModerate) {
      throw StateError('Csak admin törölhet Chat-üzenetet.');
    }
    await firestore.collection('live_feed_posts').doc(postId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProfiles() {
    if (!isAdmin) return const Stream.empty();
    return firestore
        .collection('community_profiles')
        .orderBy('displayName')
        .snapshots();
  }

  Future<void> setUserRole(String userId, String role) async {
    await setAccountRole(userId, role);
  }

  Future<void> setAccountRole(String userId, String role) async {
    if (!isAdmin) throw StateError('Csak admin módosíthat szerepkört.');
    await firestore.collection('community_profiles').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAccessRole(String userId, String accessRole) async {
    if (!isAdmin) throw StateError('Csak admin adhat jogosultsĂˇgot.');
    await firestore.collection('community_profiles').doc(userId).set({
      'accessRole': accessRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteUser(String userId) async {
    if (!isAdmin) throw StateError('Csak admin törölhet felhasználót.');
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
    await signOut();
  }

  Future<String> uploadImage(Uint8List bytes, {bool faceFocus = false}) async {
    if (bytes.isEmpty || bytes.length > maxUploadBytes) {
      throw StateError('A kĂ©p legfeljebb 5 MB lehet.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'feed.jpg'),
        'upload_preset': uploadPreset,
      }),
    );
    final url = response.data?['secure_url'];
    if (url is! String || url.isEmpty) {
      throw StateError('A kép feltöltése sikertelen.');
    }
    if (!faceFocus) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_fill,g_face,w_800,h_800,q_auto,f_auto/',
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> profile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A profil megtekintéséhez regisztráció szükséges.');
    }
    var snapshot = await firestore
        .collection('community_profiles')
        .doc(user.uid)
        .get();
    if (_isAdmin(user.email)) {
      await _ensureAdminProfile(user);
      snapshot = await firestore
          .collection('community_profiles')
          .doc(user.uid)
          .get();
    }
    final data = snapshot.data() ?? const <String, dynamic>{};
    final role = data['role'] as String?;
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
