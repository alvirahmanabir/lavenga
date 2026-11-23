import '../../core/money/money.dart';
import '../models/booking.dart';
import '../models/catalogue.dart';
import '../models/promo_social.dart';
import 'discount_service.dart';
import 'payment_calculator.dart';

class QuoteInput {
  const QuoteInput({
    required this.itemId,
    required this.space,
    required this.schedule,
  });
  final String itemId;
  final StudioSpace space;
  final BookingSchedule schedule;
}

class QuoteResult {
  const QuoteResult({required this.pricing, this.coupon});
  final BookingPricingSnapshot pricing;

  /// Present when a code was supplied (valid or not) so the UI can explain.
  final CouponResult? coupon;
}

/// The only place order prices are calculated.
abstract final class PricingService {
  /// Gross price of one interval: hourly rate prorated by minutes,
  /// rounded half up to the paisa.
  static Money lineGross(Money hourlyRate, int minutes) =>
      Money.fromMinor((hourlyRate.minor * minutes + 30) ~/ 60);

  static QuoteResult quote({
    required List<QuoteInput> items,
    required PlatformSettings settings,
    required String customerId,
    required DateTime now,
    int customerDiscountBp = 0,
    String? couponCode,
    List<Coupon> coupons = const [],
    List<Discount> discounts = const [],
  }) {
    final lines = <PricingLine>[];
    for (final input in items) {
      final minutes = input.schedule.minutes;
      final gross = lineGross(input.space.hourlyRate, minutes);
      lines.add(PricingLine(
        itemId: input.itemId,
        label: input.space.name,
        minutes: minutes,
        gross: gross,
        spaceDiscount: gross.percent(input.space.discountBp),
      ));
    }

    final subtotal = lines.fold(Money.zero, (s, l) => s + l.gross);
    final spaceDiscount = lines.fold(Money.zero, (s, l) => s + l.spaceDiscount);
    final netAfterSpace = lines.fold(Money.zero, (s, l) => s + l.net);

    final customerDiscount = netAfterSpace.percent(customerDiscountBp);
    // Spread the customer discount across lines so coupon scoping stays exact.
    final weights = [for (final l in lines) l.net.minor];
    final customerShares = (customerDiscount.minor > 0 && netAfterSpace.isPositive)
        ? customerDiscount.allocate(weights)
        : [for (final _ in lines) Money.zero];

    final bases = <DiscountBase>[
      for (var i = 0; i < items.length; i++)
        DiscountBase(
          spaceId: items[i].space.id,
          categoryId: items[i].space.categoryId,
          amount: lines[i].net - customerShares[i],
        ),
    ];

    CouponResult? couponResult;
    var couponDiscount = Money.zero;
    if (couponCode != null && couponCode.trim().isNotEmpty) {
      couponResult = DiscountService.validate(
        code: couponCode,
        coupons: coupons,
        discounts: discounts,
        customerId: customerId,
        now: now,
        bases: bases,
      );
      if (couponResult.valid) couponDiscount = couponResult.amount;
    }

    final net = netAfterSpace - customerDiscount - couponDiscount;
    final fees = net.percent(settings.vatBp);
    final total = net + fees;
    final advance = PaymentCalculator.advanceAmount(total, settings.advanceBp);

    return QuoteResult(
      coupon: couponResult,
      pricing: BookingPricingSnapshot(
        lines: lines,
        subtotal: subtotal,
        spaceDiscount: spaceDiscount,
        customerDiscount: customerDiscount,
        couponDiscount: couponDiscount,
        couponCode: (couponResult?.valid ?? false) ? couponCode!.trim().toUpperCase() : null,
        fees: fees,
        total: total,
        advanceRequired: advance,
      ),
    );
  }
}
