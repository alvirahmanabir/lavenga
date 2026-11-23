import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/enums.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/catalogue_repositories.dart';
import '../../domain/repositories/engagement_repositories.dart';

const double kAdminMaxWidth = 840;

/// Centers admin content with a readable maximum width on tablets.
class AdminBody extends StatelessWidget {
  const AdminBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kAdminMaxWidth),
          child: child,
        ),
      );
}

// ---- Providers (all refresh on every mock mutation) ------------------------

final adminStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) {
  ref.watch(dbVersionProvider);
  final actor = ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).dashboard(actor);
});

final discountsProvider = FutureProvider.autoDispose<List<Discount>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(discountRepositoryProvider).listDiscounts();
});

final couponsProvider = FutureProvider.autoDispose<List<Coupon>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(discountRepositoryProvider).listCoupons();
});

/// Key: (role, search text).
final usersProvider =
    FutureProvider.autoDispose.family<List<AppUser>, (UserRole?, String)>((ref, key) {
  ref.watch(dbVersionProvider);
  return ref.watch(userRepositoryProvider).listUsers(role: key.$1, query: key.$2);
});

final userByIdProvider = FutureProvider.autoDispose.family<AppUser, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(userRepositoryProvider).getUser(id);
});

final allSpacesProvider = FutureProvider.autoDispose<List<StudioSpace>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).listSpaces(const SpaceQuery(includeInactive: true));
});

final adminPaymentsProvider =
    FutureProvider.autoDispose.family<List<Payment>, String>((ref, query) {
  ref.watch(dbVersionProvider);
  final actor = ref.watch(currentUserProvider);
  return ref.watch(paymentRepositoryProvider).listForStaff(actor: actor, query: query);
});

/// Key: (sensitiveOnly, role, loginsOnly).
final auditProvider =
    FutureProvider.autoDispose.family<List<AuditLog>, (bool, UserRole?, bool)>((ref, key) {
  ref.watch(dbVersionProvider);
  return ref
      .watch(adminRepositoryProvider)
      .auditLogs(sensitiveOnly: key.$1, role: key.$2, loginsOnly: key.$3);
});

// ---- Small shared widgets --------------------------------------------------

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$label, $value',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.terracotta),
                const SizedBox(height: AppSpacing.sm),
                Text(value, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: text.bodySmall),
                if (hint != null) Text(hint!, style: text.bodySmall?.copyWith(color: AppColors.mutedText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays tiles out two per row on phones and more on wide screens.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 4 : 2;
      const gap = AppSpacing.md;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in children) SizedBox(width: w, child: t)],
      );
    });
  }
}

String moneyOf(Money m) => m.format();

/// Parses a taka amount typed by the user; null if invalid.
Money? parseMoney(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    return Money.parse(s);
  } on FormatException {
    return null;
  }
}

/// Parses a percent such as "12.5" into basis points; null if invalid.
int? parsePercentBp(String? s) {
  if (s == null) return null;
  final v = double.tryParse(s.trim());
  if (v == null) return null;
  return (v * 100).round();
}

String percentText(int bp) => (bp / 100).toStringAsFixed(bp % 100 == 0 ? 0 : 2);

/// Confirms the form and returns [fallback] text for empty optional values.
String? requiredField(String? v, [String label = 'This field']) =>
    (v == null || v.trim().isEmpty) ? '$label is required' : null;
