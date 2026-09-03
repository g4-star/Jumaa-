import 'package:supabase_flutter/supabase_flutter.dart';

class MFAService {
  MFAService._();

  static final MFAService instance = MFAService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Returns true when the current user has a verified TOTP factor.
  Future<bool> hasVerifiedFactor() async {
    final factors = await _supabase.auth.mfa.listFactors();

    return factors.totp.any(
      (factor) => factor.status == FactorStatus.verified,
    );
  }

  /// Returns the first verified TOTP factor, if one exists.
  Future<Factor?> getVerifiedFactor() async {
    final factors = await _supabase.auth.mfa.listFactors();

    for (final factor in factors.totp) {
      if (factor.status == FactorStatus.verified) {
        return factor;
      }
    }

    return null;
  }

  /// Starts TOTP enrollment.
  Future<AuthMFAEnrollResponse> enroll() async {
    return await _supabase.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'JUMAA',
      friendlyName: 'JUMAA Authenticator',
    );
  }

  /// Verifies the code entered during first-time enrollment.
  Future<void> verifyEnrollment({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _supabase.auth.mfa.challenge(
      factorId: factorId,
    );

    await _supabase.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code,
    );

    await _supabase.auth.refreshSession();
  }

  /// Verifies an existing TOTP factor during login.
  Future<void> verifyLogin({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _supabase.auth.mfa.challenge(
      factorId: factorId,
    );

    await _supabase.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code,
    );

    await _supabase.auth.refreshSession();
  }
}
