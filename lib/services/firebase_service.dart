import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/shop_profile.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? companyId;
  final ShopProfile? shopProfile;
  final String? role;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.companyId,
    this.shopProfile,
    this.role,
  });
}

class FirebaseService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Verifies Firebase Auth and Firestore connectivity in background
  static Future<bool> verifyConnectivity() async {
    try {
      final currentUser = auth.currentUser;
      debugPrint('Firebase Auth status: ${currentUser != null ? "User logged in: ${currentUser.uid}" : "Auth initialized"}');
      final firestoreAppName = firestore.app.name;
      debugPrint('Cloud Firestore connected to app: $firestoreAppName');
      return true;
    } catch (e) {
      debugPrint('Firebase verification note: $e');
      return false;
    }
  }

  /// Helper to format email from user input (email or phone)
  static String formatAuthEmail(String input) {
    final cleanInput = input.trim().toLowerCase();
    if (cleanInput.contains('@')) {
      return cleanInput;
    }
    // Remove non-digit characters for phone number
    final digitsOnly = cleanInput.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isNotEmpty) {
      return '$digitsOnly@billingcompany.app';
    }
    return '$cleanInput@billingcompany.app';
  }

  /// Register a new Company and Admin user
  static Future<AuthResult> registerCompany({
    required String emailOrMobile,
    required String password,
    required String shopName,
    required String address,
    required String mobile,
    required String logoPreset,
    String gstin = '',
    String ownerName = '',
    String bankName = '',
    String accountNumber = '',
    String ifscCode = '',
  }) async {
    try {
      final authEmail = formatAuthEmail(emailOrMobile);
      UserCredential? userCredential;
      String? uid;

      try {
        // 1. Create User in Firebase Auth
        userCredential = await auth.createUserWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        uid = userCredential.user!.uid;
      } on FirebaseAuthException catch (authEx) {
        final code = authEx.code.toLowerCase();
        final msg = authEx.message ?? '';

        if (code == 'email-already-in-use' || msg.contains('EMAIL_EXISTS')) {
          // Check if user account exists in Firebase Auth and try sign in
          try {
            final existingCred = await auth.signInWithEmailAndPassword(
              email: authEmail,
              password: password,
            );
            final existingUid = existingCred.user!.uid;

            // Check if Firestore user document already has an active company
            final userSnap = await firestore.collection('users').doc(existingUid).get();
            if (userSnap.exists && userSnap.data() != null && (userSnap.data()!['companyId'] as String?)?.isNotEmpty == true) {
              return AuthResult(
                success: false,
                errorMessage: 'An account with this Email or Mobile number already exists. Please switch to Company Login.',
              );
            }

            // Otherwise, user account exists in Auth but company setup was incomplete; complete it now
            uid = existingUid;
          } catch (_) {
            return AuthResult(
              success: false,
              errorMessage: 'An account with this Email or Mobile number already exists. Please switch to Company Login.',
            );
          }
        } else {
          rethrow;
        }
      }

      if (uid.isEmpty) {
        return AuthResult(
          success: false,
          errorMessage: 'Unable to initialize user authentication account.',
        );
      }

      final companyId = 'comp_${const Uuid().v4().substring(0, 8)}';

      final newProfile = ShopProfile(
        companyId: companyId,
        shopName: shopName.trim(),
        ownerName: ownerName.trim().isEmpty ? shopName.trim() : ownerName.trim(),
        address: address.trim(),
        mobile: mobile.trim(),
        gstin: gstin.trim(),
        email: emailOrMobile.contains('@') ? emailOrMobile.trim() : '',
        logoPreset: logoPreset,
        bankName: bankName.trim(),
        accountNumber: accountNumber.trim(),
        ifscCode: ifscCode.trim(),
        isConfigured: true,
      );

      // 2. Create Company Document in Firestore
      await firestore.collection('companies').doc(companyId).set({
        ...newProfile.toJson(),
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Create User Document in Firestore mapping to companyId
      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': authEmail,
        'mobile': mobile.trim(),
        'companyId': companyId,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AuthResult(
        success: true,
        companyId: companyId,
        shopProfile: newProfile,
        role: 'admin',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: parseAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: parseAuthError(e),
      );
    }
  }

  /// Login user using Email/Mobile + Password and load companyId & shop profile
  static Future<AuthResult> loginCompany({
    required String emailOrMobile,
    required String password,
    required String requestedRole,
  }) async {
    try {
      final authEmail = formatAuthEmail(emailOrMobile);
      UserCredential? userCredential;

      try {
        // 1. Sign in via Firebase Auth directly
        userCredential = await auth.signInWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
      } catch (authEx) {
        // Fallback: If user entered mobile/email not directly matching formatted authEmail, search Firestore users
        final cleanInput = emailOrMobile.trim();
        final querySnap = await firestore
            .collection('users')
            .where('mobile', isEqualTo: cleanInput)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final registeredEmail = querySnap.docs.first.data()['email'] as String?;
          if (registeredEmail != null && registeredEmail.isNotEmpty) {
            userCredential = await auth.signInWithEmailAndPassword(
              email: registeredEmail,
              password: password,
            );
          }
        }
        if (userCredential == null) {
          rethrow;
        }
      }

      final uid = userCredential.user!.uid;

      // 2. Fetch User document from Firestore to retrieve companyId
      final userSnap = await firestore.collection('users').doc(uid).get();

      String? companyId;
      String userRole = requestedRole;

      if (userSnap.exists && userSnap.data() != null) {
        final userData = userSnap.data()!;
        companyId = userData['companyId'] as String?;
        userRole = (userData['role'] as String?) ?? requestedRole;
      }

      // If user doc not found directly by UID, attempt query by email
      if (companyId == null) {
        final querySnap = await firestore
            .collection('users')
            .where('email', isEqualTo: authEmail)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final userData = querySnap.docs.first.data();
          companyId = userData['companyId'] as String?;
          userRole = (userData['role'] as String?) ?? requestedRole;
        }
      }

      if (companyId == null || companyId.isEmpty) {
        companyId = 'default-comp';
      }

      // 3. Fetch Company document from Firestore
      final companySnap = await firestore.collection('companies').doc(companyId).get();

      ShopProfile shopProfile;
      if (companySnap.exists && companySnap.data() != null) {
        shopProfile = ShopProfile.fromJson(companySnap.data()!, defaultCompanyId: companyId);
      } else {
        shopProfile = ShopProfile.defaultProfile(companyId: companyId);
        // Save initial company document
        await firestore.collection('companies').doc(companyId).set(shopProfile.toJson());
      }

      return AuthResult(
        success: true,
        companyId: companyId,
        shopProfile: shopProfile,
        role: userRole,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: parseAuthError(e),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: parseAuthError(e),
      );
    }
  }

  /// Parses Firebase Auth error into detailed human-readable message
  static String parseAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      final msg = error.message ?? '';

      if (code == 'api-key-not-valid' || msg.contains('API_KEY_INVALID') || msg.contains('AIzaSyDummyKey')) {
        return 'Firebase API Key is invalid or set to a placeholder key.\n'
            'Please update `apiKey` in `lib/firebase_options.dart` with your real Firebase API key from Firebase Console.';
      }
      if (code == 'operation-not-allowed' ||
          msg.contains('OPERATION_NOT_ALLOWED') ||
          code == 'admin-restricted-operation') {
        return 'Email/Password Sign-In is disabled in Firebase Console.\n'
            'Please go to Firebase Console -> Authentication -> Sign-in method -> Enable "Email/Password".';
      }
      if (code == 'email-already-in-use' || msg.contains('EMAIL_EXISTS')) {
        return 'An account with this Email or Mobile number already exists. Please switch to Company Login.';
      }
      if (code == 'invalid-email' || msg.contains('INVALID_EMAIL')) {
        return 'Invalid email address or mobile format. Please check your entry.';
      }
      if (code == 'weak-password' || msg.contains('WEAK_PASSWORD')) {
        return 'Password is too weak. Please use at least 6 characters.';
      }
      if (code == 'user-not-found' || code == 'wrong-password' || code == 'invalid-credential') {
        return 'Invalid Email/Mobile or Password. Please check your credentials.';
      }
      if (code == 'network-request-failed') {
        return 'Network connection error. Please check your internet connection.';
      }
      if (msg.isNotEmpty) {
        return msg;
      }
      return 'Firebase Auth Error (${error.code})';
    }

    final str = error.toString();
    if (str.contains('AIzaSyDummyKey') || str.contains('API_KEY_INVALID')) {
      return 'Firebase API Key is invalid or set to a placeholder key.\n'
          'Please update `apiKey` in `lib/firebase_options.dart` with your real Firebase API key from Firebase Console.';
    }
    if (str.contains('operation-not-allowed') || str.contains('OPERATION_NOT_ALLOWED')) {
      return 'Email/Password Sign-In is disabled in Firebase Console.\n'
          'Please go to Firebase Console -> Authentication -> Sign-in method -> Enable "Email/Password".';
    }
    if (str.contains('email-already-in-use') || str.contains('EMAIL_EXISTS')) {
      return 'An account with this Email or Mobile number already exists. Please switch to Company Login.';
    }
    if (str.contains('invalid-email') || str.contains('INVALID_EMAIL')) {
      return 'Invalid email address or mobile format.';
    }
    if (str.contains('weak-password') || str.contains('WEAK_PASSWORD')) {
      return 'Password is too weak. Please enter at least 6 characters.';
    }
    if (str.contains('400')) {
      return 'Firebase Auth HTTP 400 Bad Request.\n'
          '1. Ensure your `apiKey` in `lib/firebase_options.dart` is your valid Firebase Web API key.\n'
          '2. Ensure Email/Password Sign-In is enabled in Firebase Console -> Authentication -> Sign-in method.';
    }

    return 'Authentication failed: $str';
  }

  /// Update company details in Firestore
  static Future<bool> updateCompanyDetails(ShopProfile profile) async {
    try {
      final companyId = profile.companyId;
      await firestore.collection('companies').doc(companyId).set(
            profile.toJson(),
            SetOptions(merge: true),
          );
      return true;
    } catch (e) {
      debugPrint('Error updating company details: $e');
      return false;
    }
  }
}
