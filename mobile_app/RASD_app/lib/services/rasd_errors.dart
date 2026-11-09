import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/glass_widgets.dart';

/// One place that turns any error into a short, clear message for the user.
///
/// Every screen uses this class, so the same problem always shows the same
/// wording. Technical details (error codes, stack traces) are never shown to
/// the user; they only go to the debug log through [debugPrint].
class RasdErrors {
  RasdErrors._();

  /// Message used when we do not know what went wrong.
  static const String generic =
      'Something went wrong. Please try again. If it keeps happening, contact support.';

  static const String noConnection =
      'Check your internet connection and try again.';

  /// Returns the message to show under the title of the pop-up.
  ///
  /// [credentialMessage] replaces the "wrong email or password" text. It is
  /// used by Change Password, where only the current password can be wrong.
  static String message(Object error, {String? credentialMessage}) {
    debugPrint('RASD error: $error');

    // Errors from Firebase Authentication (sign up, log in, change password).
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email or phone number is already registered.';
        case 'invalid-email':
          return 'Enter a valid email, like name@example.com.';
        case 'weak-password':
          return 'Choose a stronger password with at least 8 characters, '
              'an uppercase letter, a lowercase letter, a number and a special character.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return credentialMessage ??
              'The email or password is not correct. Check them and try again.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a few minutes before trying again.';
        case 'network-request-failed':
          return noConnection;
        case 'requires-recent-login':
          return 'For your security, log in again and then repeat this step.';
      }
      return generic;
    }

    // Errors sent back by our own cloud functions. The functions write clear
    // messages for the problems the user can fix, so those are shown as they are.
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'invalid-argument':
        case 'already-exists':
        case 'failed-precondition':
        case 'not-found':
        case 'permission-denied':
          final text = (error.message ?? '').trim();
          if (text.isNotEmpty && text.toUpperCase() != 'INTERNAL') return text;
          return generic;
        case 'unauthenticated':
          return 'Your session has ended. Please log in again.';
        case 'unavailable':
        case 'deadline-exceeded':
          return noConnection;
        case 'resource-exhausted':
          return 'Too many attempts. Wait a few minutes before trying again.';
      }
      return generic;
    }

    // Other Firebase errors (database, storage).
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthorized':
          return 'You do not have permission to do this.';
        case 'unavailable':
        case 'network-error':
          return noConnection;
        case 'canceled':
          return 'The action was cancelled.';
      }
      return generic;
    }

    // Messages written by our own code with StateError (already user friendly).
    if (error is StateError) {
      final text = error.message.trim();
      return text.isEmpty ? generic : text;
    }

    return generic;
  }

  /// Short title for the pop-up. [fallback] is used for unknown errors.
  static String title(Object error, {String fallback = 'Something went wrong'}) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Could not sign up';
        case 'too-many-requests':
          return 'Too many attempts';
        case 'network-request-failed':
          return 'No connection';
      }
    }
    if (error is FirebaseFunctionsException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return 'No connection';
    }
    return fallback;
  }
}

/// Shows an error in the centre pop-up used across the app.
///
/// [title] describes what the user was trying to do, for example
/// "Could not log in". The text under it comes from [RasdErrors.message].
Future<void> showRasdError(
  BuildContext context,
  Object error, {
  String title = 'Something went wrong',
  String? credentialMessage,
}) {
  return showCenterMessage(
    context,
    RasdErrors.message(error, credentialMessage: credentialMessage),
    success: false,
    title: RasdErrors.title(error, fallback: title),
  );
}
