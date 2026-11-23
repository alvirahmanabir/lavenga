# Backend integration guide (Supabase + SSLCommerz)

The app is frontend-only. All data flows through the 14 repository interfaces in
`lib/domain/repositories/`; `lib/core/di/providers.dart` is the single place that binds
them to the mock implementations in `lib/data/mock/`. To go live, write Supabase
implementations and change those bindings. No screen imports the mock layer.

## Suggested tables
users/profiles (role, status), studios, spaces, space_categories, bookings, booking_items,
booking_pricing_snapshots, holds, payments, payment_transactions, refund_requests,
refund_transactions, discounts, coupons, favorites, reviews, support_tickets,
support_messages, notifications, audit_logs, platform_settings, banners.
Money is stored as integer paisa; timestamps as `timestamptz` (UTC).

## Row-level security
- Customers: read/write only rows where `customer_id = auth.uid()`.
- Managers: rows whose `studio_id` is in their `manager_studios` scope, plus per-permission checks.
- Admins: full access via a role claim. Every privileged mutation writes an audit_logs row.
- Passwords, gateway secrets and service keys never reach the client.

## Concurrency (double-booking)
Enforce in the database, not the client:
```sql
create extension if not exists btree_gist;
alter table booking_items add constraint no_overlap
  exclude using gist (space_id with =, tstzrange(starts_at, ends_at) with &&)
  where (status in ('hold','pending_review','confirmed','in_progress'));
```
Creating an order inserts items with a hold (`hold_expires_at = now() + interval '10 minutes'`);
a conflict raises a unique/exclusion error, mapped to `SlotConflict`. A scheduled job expires holds.

## SSLCommerz flow
1. Client calls an Edge Function `payments/initiate` with booking id and kind (advance/full/balance).
   The function recomputes the amount server-side and calls SSLCommerz init with the store secret.
2. Client opens the returned gateway URL; the gateway redirects to success/fail/cancel URLs (never trusted).
3. SSLCommerz IPN hits an Edge Function, which calls the Order Validation API with `val_id`,
   checks amount, currency and tran_id, then marks the payment verified and updates the booking.
4. The client polls/subscribes to the payment row; receipts appear only once verified.
Refunds use the gateway refund API, triggered by an admin-only function.

## Replacing mocks
Implement `AuthRepository` with Supabase Auth, `BookingRepository.createOrder` with an RPC, and
`PaymentRepository` with the Edge Functions above. The `GatewayOutcome` type already models
success, failure, cancelled, and pending verification.
