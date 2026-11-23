import '../../core/money/money.dart';
import '../enums.dart';
import '../models/promo_social.dart';

/// Base amount of one cart line after space and customer discounts, with the
/// space and category it belongs to (used to scope coupons).
class DiscountBase {
  const DiscountBase({
    required this.spaceId,
    required this.categoryId,
    required this.amount,
  });
  final String spaceId;
  final String categoryId;
  final Money amount;
}

class CouponResult {
  const CouponResult.ok({
    required this.coupon,
    required this.discount,
    required this.amount,
  })  : valid = true,
        message = 'Coupon applied';

  const CouponResult.invalid(this.message)
      : valid = false,
        coupon = null,
        discount = null,
        amount = Money.zero;

  final bool valid;
  final String message;
  final Coupon? coupon;
  final Discount? discount;
  final Money amount;
}

/// Single place where discounts are validated and calculated.
/// Eligibility is advisory in the client; the backend re-validates.
abstract final class DiscountService {
  static Money eligibleBase(Discount d, List<DiscountBase> bases) {
    final eligible = bases.where((b) => switch (d.scope) {
          DiscountScope.global || DiscountScope.customer => true,
          DiscountScope.space => d.targetIds.contains(b.spaceId),
          DiscountScope.category => d.targetIds.contains(b.categoryId),
        });
    return eligible.fold(Money.zero, (sum, b) => sum + b.amount);
  }

  /// Discount amount for [eligibleBase], honouring max cap and never
  /// exceeding the eligible base itself.
  static Money amountFor(Discount d, Money eligibleBase) {
    var amount = d.kind == DiscountKind.percentage
        ? eligibleBase.percent(d.value)
        : Money.fromMinor(d.value);
    if (d.maxDiscount != null) amount = amount.clampMax(d.maxDiscount!);
    return amount.clampMax(eligibleBase).clampMin(Money.zero);
  }

  static CouponResult validate({
    required String code,
    required List<Coupon> coupons,
    required List<Discount> discounts,
    required String customerId,
    required DateTime now,
    required List<DiscountBase> bases,
  }) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return const CouponResult.invalid('Enter a code');

    Coupon? coupon;
    for (final c in coupons) {
      if (c.code.toUpperCase() == normalized) coupon = c;
    }
    if (coupon == null) return const CouponResult.invalid('We could not find that code');
    if (!coupon.active) return const CouponResult.invalid('This code is no longer active');

    Discount? discount;
    for (final d in discounts) {
      if (d.id == coupon.discountId) discount = d;
    }
    if (discount == null || !discount.active) {
      return const CouponResult.invalid('This code is no longer active');
    }
    if (now.isBefore(discount.startsAt)) {
      return const CouponResult.invalid('This code is not valid yet');
    }
    if (now.isAfter(discount.endsAt)) {
      return const CouponResult.invalid('This code has expired');
    }
    if (coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
      return const CouponResult.invalid('This code has reached its usage limit');
    }
    if (coupon.usedBy(customerId) >= coupon.perCustomerLimit) {
      return const CouponResult.invalid('You have already used this code');
    }

    final orderBase = bases.fold(Money.zero, (sum, b) => sum + b.amount);
    if (orderBase < discount.minBooking) {
      return CouponResult.invalid(
        'Minimum booking value for this code is ${discount.minBooking.format()}',
      );
    }
    final eligible = eligibleBase(discount, bases);
    if (!eligible.isPositive) {
      return const CouponResult.invalid('This code does not apply to the selected spaces');
    }
    return CouponResult.ok(
      coupon: coupon,
      discount: discount,
      amount: amountFor(discount, eligible),
    );
  }
}
