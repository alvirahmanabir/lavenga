/// Auth behaviour switches.
///
/// [requireEmailVerification] is OFF for the frontend phase: registration
/// signs the user straight in and no code screen is shown. When the backend
/// is ready (Supabase Auth sending a confirmation email with a one-time
/// code), set it to true. Registration then routes to `/auth/otp` and
/// `AuthRepository.verifyOtp` / `resendOtp` are used. See
/// docs/EMAIL_VERIFICATION.md.
abstract final class AuthConfig {
  static const bool requireEmailVerification = false;
}
