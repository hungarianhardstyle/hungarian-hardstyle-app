import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'wordpress_service.dart';

class VotingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User _registeredUser() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A szavazáshoz regisztráció és bejelentkezés szükséges.');
    }
    return user;
  }

  Future<bool> hasVoted({required int seasonId, required String category}) async {
    final user = _registeredUser();
    final id = '${seasonId}_${category}_${user.uid}';
    return (await _firestore.collection('voting_votes').doc(id).get()).exists;
  }

  Future<void> submitVote({
    required int seasonId,
    required String category,
    required int candidateId,
    required bool newsletterConsent,
    required WordpressService wordpress,
  }) async {
    final user = _registeredUser();
    final id = '${seasonId}_${category}_${user.uid}';
    if (newsletterConsent && user.email != null && user.email!.trim().isNotEmpty) {
      await wordpress.subscribeNewsletter(email: user.email!, consent: true);
    }
    final ref = _firestore.collection('voting_votes').doc(id);
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(ref)).exists) {
        throw StateError('Ebben a kategóriában már szavaztál.');
      }
      transaction.set(ref, {
        'seasonId': seasonId,
        'category': category,
        'candidateId': candidateId,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
