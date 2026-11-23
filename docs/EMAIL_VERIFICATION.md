# Email verification (planned for the backend phase)

Frontend status: **no OTP step on sign-up or sign-in.** `AuthConfig.requireEmailVerification`
(`lib/core/config/auth_config.dart`) is `false`, so registration creates a verified account and
signs the user in immediately.

## Turning it on later
1. Set `requireEmailVerification = true`.
2. Backend: on sign-up, Supabase Auth (or your own Edge Function) generates a random 6-digit code
   with a cryptographically secure RNG, stores only its hash with a ~10 minute expiry and attempt
   limit, and emails it through an SMTP/transactional provider (Resend, SES, Postmark…).
3. Implement `AuthRepository.register` (returns an unverified user), `verifyOtp` (checks the hash,
   expiry and attempts, marks the email verified, opens the session) and `resendOtp` (rate limited).
4. The existing `/auth/otp` screen (`OtpScreen`) already handles `mode=register` and `mode=verify`;
   registration and login route to it automatically once the flag is true.

## Password reset
Reset still uses a code screen (`mode=reset`), because it needs proof of email ownership. In the
mock the code is `123456`; in production send a random code (or a magic link) by email the same way.
