
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../theme/glass_widgets.dart';

/// Converts Firebase and application errors into user-friendly messages.
class RasdErrors {
  RasdErrors._();

  /// Returns the currently selected language.
  static bool get _isArabic => AuthStore.arabic.value;

  /// Default message for unexpected errors.
  static String get generic => _isArabic
      ? 'حدث خطأ غير متوقع. حاول مرة أخرى. إذا استمرت المشكلة، تواصل مع الدعم.'
      : 'Something went wrong. Please try again. If it keeps happening, contact support.';

  /// Message shown when the connection is unavailable.
  static String get noConnection => _isArabic
      ? 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'
      : 'Check your internet connection and try again.';

  /// Translates known application and backend messages.
  static String _localize(String text) {
    if (!_isArabic) return text;

    final normalized = text.trim();

    const translations = <String, String>{
      // General messages.
      'Something went wrong':
      'حدث خطأ غير متوقع.',
      'Could not log in':
      'تعذر تسجيل الدخول',
      'Could not sign up':
      'تعذر إنشاء الحساب',
      'Could not continue':
      'تعذرت المتابعة',
      'No connection':
      'لا يوجد اتصال',
      'Too many attempts':
      'محاولات كثيرة',
      'This field is required.':
      'هذا الحقل مطلوب.',
      'Enter a valid email, like name@example.com.':
      'أدخل بريدًا إلكترونيًا صحيحًا مثل name@example.com.',

      // Authentication and account messages.
      'Please sign in.':
      'يرجى تسجيل الدخول أولًا.',
      'Sign in first.':
      'سجل الدخول أولًا.',
      'Please log in.':
      'يرجى تسجيل الدخول.',
      'Please log in again.':
      'يرجى تسجيل الدخول مرة أخرى.',
      'Log in first, then try again.':
      'سجل الدخول أولًا، ثم حاول مرة أخرى.',
      'Your session has ended. Please log in again.':
      'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.',
      'Recent sign-in required.':
      'يجب تسجيل الدخول مرة أخرى مؤخرًا لإكمال هذه العملية.',
      'Verified email required.':
      'يجب التحقق من البريد الإلكتروني أولًا.',
      'A verified email is required.':
      'يجب أن يكون البريد الإلكتروني مؤكدًا.',
      'Your email is not verified yet. Open the verification link we sent you, then tap Continue.':
      'لم يتم التحقق من بريدك الإلكتروني بعد. افتح رابط التحقق المرسل إليك، ثم اضغط على متابعة.',
      'Open the verification email we sent you, then log in again.':
      'افتح رسالة التحقق المرسلة إلى بريدك الإلكتروني، ثم سجل الدخول مرة أخرى.',
      'Your email is verified, but your profile is not complete. Close the app, open it again and finish signing up.':
      'تم التحقق من بريدك الإلكتروني، لكن ملفك الشخصي غير مكتمل. أغلق التطبيق وافتحه مجددًا لإكمال التسجيل.',
      'Profile already exists.':
      'الملف الشخصي موجود بالفعل.',
      'User profile not authorized.':
      'لا تملك صلاحية استخدام هذا الملف الشخصي.',
      'Account deletion could not be completed.':
      'تعذر إكمال حذف الحساب.',

      // Farm messages.
      'Farm not found.':
      'لم يتم العثور على المزرعة.',
      'Farm is no longer available.':
      'لم تعد المزرعة متاحة.',
      'Farm is unavailable or not owned by this account.':
      'المزرعة غير متاحة أو لا يملك هذا الحساب صلاحية إدارتها.',
      'You do not have access to this farm.':
      'ليس لديك صلاحية الوصول إلى هذه المزرعة.',
      'You have no farms yet. Add a farm first.':
      'ليس لديك مزارع حتى الآن. أضف مزرعة أولًا.',
      'Choose a farm first, then add the palm.':
      'اختر المزرعة أولًا، ثم أضف النخلة.',
      'This farm no longer exists.':
      'هذه المزرعة لم تعد موجودة.',
      'This farm is being deleted. Try again later.':
      'يتم حذف هذه المزرعة حاليًا. حاول مرة أخرى لاحقًا.',

      // Farmer messages.
      'Only farm owners can invite farmers.':
      'يمكن لمالكي المزارع فقط دعوة المزارعين.',
      'Only farm owners can search for farmers.':
      'يمكن لمالكي المزارع فقط البحث عن المزارعين.',
      'Only farm owners can cancel invitations.':
      'يمكن لمالكي المزارع فقط إلغاء الدعوات.',
      'Only farm owners can remove farmers.':
      'يمكن لمالكي المزارع فقط إزالة المزارعين.',
      'Only farmers can accept invitations.':
      'يمكن للمزارعين فقط قبول الدعوات.',
      'Only farmers can reject invitations.':
      'يمكن للمزارعين فقط رفض الدعوات.',
      'Only farmers can access this information.':
      'يمكن للمزارعين فقط الوصول إلى هذه المعلومات.',
      'This account is not registered as a Farmer.':
      'هذا الحساب غير مسجل بدور مزارع.',
      'This farmer is already assigned to a farm.':
      'هذا المزارع مرتبط بمزرعة بالفعل.',
      'Farmer is already assigned to another farm.':
      'هذا المزارع مرتبط بمزرعة أخرى.',
      'Farmer account not found.':
      'لم يتم العثور على حساب المزارع.',
      'Farmer account not found or invalid.':
      'لم يتم العثور على حساب المزارع أو أن بياناته غير صالحة.',
      'Farmer account is unavailable.':
      'حساب المزارع غير متاح.',
      'Farmer is not assigned to this farm.':
      'هذا المزارع غير مرتبط بهذه المزرعة.',
      'Unable to assign farmer. Please try again.':
      'تعذر ربط المزارع بالمزرعة. حاول مرة أخرى.',
      'Unable to remove farmer. Please try again.':
      'تعذرت إزالة المزارع. حاول مرة أخرى.',
      'Unable to look up farmer account.':
      'تعذر البحث عن حساب المزارع.',
      'Enter at least two characters.':
      'أدخل حرفين على الأقل للبحث.',

      // Invitation messages.
      'Invitation not found.':
      'لم يتم العثور على الدعوة.',
      'Invitation is unavailable.':
      'الدعوة غير متاحة.',
      'Invitation data is unavailable.':
      'بيانات الدعوة غير متاحة.',
      'This invitation does not belong to you.':
      'هذه الدعوة لا تخص حسابك.',
      'This farmer already has a pending invitation.':
      'لدى هذا المزارع دعوة معلقة بالفعل.',
      'You cannot cancel this invitation.':
      'ليس لديك صلاحية إلغاء هذه الدعوة.',
      'You cannot view this invitation.':
      'ليس لديك صلاحية عرض هذه الدعوة.',
      'Unable to reject invitation. Please try again.':
      'تعذر رفض الدعوة. حاول مرة أخرى.',
      'Unable to cancel invitation. Please try again.':
      'تعذر إلغاء الدعوة. حاول مرة أخرى.',
      'Unable to generate invitation ID.':
      'تعذر إنشاء معرّف الدعوة.',

      // Common validation messages.
      'Invalid role.':
      'نوع الحساب غير صالح.',
      'Invalid language.':
      'اللغة المختارة غير صالحة.',
      'Unexpected profile fields.':
      'تحتوي بيانات الملف الشخصي على حقول غير متوقعة.',
      'Invalid profile changes.':
      'تعديلات الملف الشخصي غير صالحة.',
      'Invalid notification setting.':
      'إعداد الإشعارات غير صالح.',
      'Invalid fullName.':
      'الاسم الكامل غير صالح.',
      'Invalid phoneNumber.':
      'رقم الجوال غير صالح.',
      'Invalid farmId.':
      'معرّف المزرعة غير صالح.',
      'Invalid farmerId.':
      'معرّف المزارع غير صالح.',
      'Invalid invitationId.':
      'معرّف الدعوة غير صالح.',
      'Invalid name.':
      'الاسم غير صالح.',
      'Expected an object.':
      'صيغة البيانات المرسلة غير صحيحة.',
      'Invalid profile.':
      'بيانات الملف الشخصي غير صالحة.',
    };

    return translations[normalized] ?? text;
  }

  /// Returns a user-friendly message for the provided error.
  static String message(
      Object error, {
        String? credentialMessage,
      }) {
    // Keep technical details in debug logs.
    debugPrint('RASD error: $error');

    // Firebase Authentication errors.
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return _isArabic
              ? 'هذا البريد الإلكتروني أو رقم الجوال مسجل بالفعل.'
              : 'This email or phone number is already registered.';

        case 'invalid-email':
          return _isArabic
              ? 'أدخل بريدًا إلكترونيًا صحيحًا مثل name@example.com.'
              : 'Enter a valid email, like name@example.com.';

        case 'weak-password':
          return _isArabic
              ? 'اختر كلمة مرور أقوى تتكون من 8 أحرف على الأقل، وتحتوي على حرف كبير وحرف صغير ورقم ورمز خاص.'
              : 'Choose a stronger password with at least 8 characters, '
              'an uppercase letter, a lowercase letter, a number and a special character.';

        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          if (credentialMessage != null &&
              credentialMessage.trim().isNotEmpty) {
            return _localize(credentialMessage);
          }

          return _isArabic
              ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة. تحقق منهما وحاول مرة أخرى.'
              : 'The email or password is not correct. Check them and try again.';

        case 'user-disabled':
          return _isArabic
              ? 'تم تعطيل هذا الحساب. تواصل مع الدعم.'
              : 'This account has been disabled. Contact support.';

        case 'too-many-requests':
          return _isArabic
              ? 'محاولات كثيرة جدًا. انتظر بضع دقائق ثم حاول مرة أخرى.'
              : 'Too many attempts. Wait a few minutes before trying again.';

        case 'network-request-failed':
          return noConnection;

        case 'requires-recent-login':
          return _isArabic
              ? 'لحماية حسابك، سجل الدخول مرة أخرى ثم أعد تنفيذ هذه العملية.'
              : 'For your security, log in again and then repeat this step.';
      }

      return generic;
    }

    // Firebase Cloud Functions errors.
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'invalid-argument':
        case 'already-exists':
        case 'failed-precondition':
        case 'not-found':
        case 'permission-denied':
          final text = (error.message ?? '').trim();

          if (text.isNotEmpty &&
              text.toUpperCase() != 'INTERNAL') {
            return _localize(text);
          }

          return generic;

        case 'unauthenticated':
          return _isArabic
              ? 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.'
              : 'Your session has ended. Please log in again.';

        case 'unavailable':
        case 'deadline-exceeded':
          return noConnection;

        case 'resource-exhausted':
          return _isArabic
              ? 'محاولات كثيرة جدًا. انتظر بضع دقائق ثم حاول مرة أخرى.'
              : 'Too many attempts. Wait a few minutes before trying again.';
      }

      return generic;
    }

    // Realtime Database and Storage errors.
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthorized':
          return _isArabic
              ? 'ليس لديك صلاحية لتنفيذ هذه العملية.'
              : 'You do not have permission to do this.';

        case 'unavailable':
        case 'network-error':
          return noConnection;

        case 'canceled':
          return _isArabic
              ? 'تم إلغاء العملية.'
              : 'The action was cancelled.';
      }

      return generic;
    }

    // Application errors raised using StateError.
    if (error is StateError) {
      final text = error.message.trim();

      if (text.isEmpty) {
        return generic;
      }

      return _localize(text);
    }

    return generic;
  }

  /// Returns a localized title for the error dialog.
  static String title(
      Object error, {
        String fallback = 'Something went wrong',
      }) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return _isArabic
              ? 'تعذر إنشاء الحساب'
              : 'Could not sign up';

        case 'too-many-requests':
          return _isArabic
              ? 'محاولات كثيرة'
              : 'Too many attempts';

        case 'network-request-failed':
          return _isArabic
              ? 'لا يوجد اتصال'
              : 'No connection';
      }
    }

    if (error is FirebaseFunctionsException &&
        (error.code == 'unavailable' ||
            error.code == 'deadline-exceeded')) {
      return _isArabic
          ? 'لا يوجد اتصال'
          : 'No connection';
    }

    return _localize(fallback);
  }
}

/// Displays a localized error dialog using the app's design.
Future<void> showRasdError(
    BuildContext context,
    Object error, {
      String title = 'Something went wrong',
      String? credentialMessage,
    }) {
  return showCenterMessage(
    context,
    RasdErrors.message(
      error,
      credentialMessage: credentialMessage,
    ),
    success: false,
    title: RasdErrors.title(
      error,
      fallback: title,
    ),
  );
}
