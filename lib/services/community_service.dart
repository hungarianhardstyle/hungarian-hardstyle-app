import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/community_post.dart';

class CommunityService {
  static const cloudName = 'fjxo93em';
  static const uploadPreset = 'Hun_hs_Mobile';

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Dio _dio;

  CommunityService({FirebaseAuth? auth, FirebaseFirestore? firestore, Dio? dio})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance,
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
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName.trim());
    await firestore.collection('community_profiles').doc(user.uid).set({
      'displayName': displayName.trim(),
      'role': role,
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signIn({required String email, required String password}) {
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) return;
    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    final result = await auth.signInWithCredential(credential);
    final user = result.user!;
    await firestore.collection('community_profiles').doc(user.uid).set({
      'displayName': user.displayName ?? 'Hungarian Hardstyle user',
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final displayName = isAnonymous
        ? 'Unknown User ${_anonymousNumber(user.uid)}'
        : (profile.data()?['displayName'] as String? ??
              user.displayName ??
              'HUHS user');
    await firestore.collection('live_feed_posts').add({
      'authorId': user.uid,
      'authorName': displayName,
      'text': trimmed,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadImage(Uint8List bytes) async {
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
    return url;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> profile() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A profil megtekintéséhez regisztráció szükséges.');
    }
    return firestore.collection('community_profiles').doc(user.uid).get();
  }

  Future<void> signOut() => auth.signOut();

  static String _anonymousNumber(String uid) {
    final value = uid.codeUnits.fold<int>(17, (hash, code) => hash * 31 + code);
    return (value.abs() % 9000 + 1000).toString();
  }
}
