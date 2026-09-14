import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum FirebaseCallableFailure { auth, unknown }

Future<void>? _firebaseRuntimeInitialization;
bool _firebaseCoreReady = false;
final List<String> _firebaseRuntimeEvents = <String>[];

List<String> get firebaseRuntimeDiagnostics =>
    List<String>.unmodifiable(_firebaseRuntimeEvents);

void _recordFirebaseRuntimeEvent(String event) {
  _firebaseRuntimeEvents.add(event);
  if (kDebugMode) debugPrint('Firebase runtime: $event');
}

void recordFirebaseRequestStarted(String service) {
  final event =
      'request:$service:sequence=${_firebaseRuntimeEvents.length}';
  _recordFirebaseRuntimeEvent(event);
}

String sanitizeFirebaseDiagnosticMessage(String message) {
  final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  final sanitized = compact.replaceAll(
    RegExp(r'[A-Za-z0-9_.-]{40,}'),
    '[redacted]',
  );
  return sanitized.length > 160 ? '${sanitized.substring(0, 160)}…' : sanitized;
}

Future<void> initializeFirebaseRuntime() {
  return _firebaseRuntimeInitialization ??= () async {
    _recordFirebaseRuntimeEvent('firebaseInitializationStarted');
    try {
      await Firebase.initializeApp();
      _firebaseCoreReady = true;
      _recordFirebaseRuntimeEvent('firebaseInitializationCompleted');
    } catch (error) {
      _recordFirebaseRuntimeEvent(
        'firebaseRuntimeInitFailed:${error.runtimeType}',
      );
      if (kDebugMode) {
        debugPrint('Firebase runtime init failed: ${error.runtimeType}');
      }
    }
  }();
}

FirebaseCallableFailure classifyFirebaseCallableFailure(
  FirebaseFunctionsException error,
) {
  final text = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();
  if (text.contains('auth token') ||
      text.contains('authentication required') ||
      text.contains('token expired') ||
      text.contains('sign in')) {
    return FirebaseCallableFailure.auth;
  }
  return FirebaseCallableFailure.unknown;
}

Future<void>? _authRefreshInFlight;

Future<void> _refreshAuthOnce() {
  return _authRefreshInFlight ??= () async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } finally {
      _authRefreshInFlight = null;
    }
  }();
}

/// Retries an expired Auth token once without affecting Firebase Auth state.
Future<HttpsCallableResult<T>> callFirebaseCallable<T>(
  String name, {
  Object? parameters,
}) async {
  await initializeFirebaseRuntime();
  if (!_firebaseCoreReady) {
    throw StateError('A Firebase szolgáltatás még nem áll készen.');
  }
  recordFirebaseRequestStarted('callable:$name');
  final callable = FirebaseFunctions.instance.httpsCallable(name);
  try {
    return await callable.call<T>(parameters);
  } on FirebaseFunctionsException catch (error) {
    if (error.code != 'unauthenticated') {
      rethrow;
    }
    switch (classifyFirebaseCallableFailure(error)) {
      case FirebaseCallableFailure.auth:
        await _refreshAuthOnce();
        return callable.call<T>(parameters);
      case FirebaseCallableFailure.unknown:
        rethrow;
    }
  }
}
