import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialAuthProfile {
  const SocialAuthProfile({
    required this.providerUserId,
    required this.fullName,
    this.email,
  });

  final String providerUserId;
  final String fullName;
  final String? email;
}

class SocialAuthService {
  static const _googleServerClientId =
      '579062415072-ormq514hcc6jn1fvnhjl3oes9n3hkqcb.apps.googleusercontent.com';

  bool _googleInitialized = false;

  Future<SocialAuthProfile?> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    try {
      final account = await GoogleSignIn.instance.authenticate();
      return SocialAuthProfile(
        providerUserId: account.id,
        fullName: account.displayName ?? '',
        email: account.email,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  Future<SocialAuthProfile?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.cancelled) {
      return null;
    }

    if (result.status != LoginStatus.success) {
      throw Exception(
          result.message ?? 'Não foi possível autenticar no Facebook.');
    }

    final userData = await FacebookAuth.instance.getUserData(
      fields: 'id,name,email',
    );
    final providerUserId = userData['id']?.toString() ?? '';

    if (providerUserId.isEmpty) {
      throw Exception('Facebook não retornou ID da conta.');
    }

    return SocialAuthProfile(
      providerUserId: providerUserId,
      fullName: userData['name']?.toString() ?? '',
      email: userData['email']?.toString(),
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }

    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
    _googleInitialized = true;
  }
}
