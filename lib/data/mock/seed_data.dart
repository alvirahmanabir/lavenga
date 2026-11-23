import '../../core/money/money.dart';
import '../../core/utils/time_format.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/services/payment_calculator.dart';
import '../../domain/services/pricing_service.dart';
import 'mock_database.dart';

String _img(String seed, [int w = 900, int h = 700]) =>
    'https://picsum.photos/seed/$seed/$w/$h';

/// Demo credentials, shown on the login screen in development.
const demoPassword = 'Lavenga@123';
const demoCustomerEmail = 'ayesha@example.com';
const demoManagerEmail = 'manager@lavenga.app';
const demoAdminEmail = 'admin@lavenga.app';
const demoOtp = '123456';

void seedDatabase(MockDatabase db, DateTime now) {
  DateTime at(int days, int minute) =>
      studioDayStart(now.add(Duration(days: days))).add(Duration(minutes: minute));

  // ---- Studios ----------------------------------------------------------
  db.studios = [
    Studio(
      id: 'st_1',
      name: 'Lumen House',
      description:
          'A daylight-first photography house in Banani with five sets built for fashion, portrait and product work.',
      address: 'House 14, Road 11, Banani',
      area: 'Banani',
      city: 'Dhaka',
      imageUrl: _img('lumen-house', 1000, 700),
      createdAt: now.subtract(const Duration(days: 400)),
    ),
    Studio(
      id: 'st_2',
      name: 'Reel & Echo Studios',
      description:
          'Sound-treated rooms and cinema sets in Dhanmondi for podcasts, interviews, ads and short films.',
      address: 'Road 8/A, Dhanmondi',
      area: 'Dhanmondi',
      city: 'Dhaka',
      imageUrl: _img('reel-echo', 1000, 700),
      createdAt: now.subtract(const Duration(days: 300)),
    ),
    Studio(
      id: 'st_3',
      name: 'Terra Cotta Lofts',
      description:
          'Warm, lived-in lofts and a garden courtyard in Gulshan for lifestyle shoots, weddings and events.',
      address: 'Plot 22, Road 90, Gulshan 2',
      area: 'Gulshan 2',
      city: 'Dhaka',
      imageUrl: _img('terra-cotta', 1000, 700),
      createdAt: now.subtract(const Duration(days: 200)),
    ),
  ];

  db.categories = const [
    SpaceCategory(id: 'cat_photo', name: 'Photography', icon: 'camera'),
    SpaceCategory(id: 'cat_video', name: 'Videography', icon: 'videocam'),
    SpaceCategory(id: 'cat_podcast', name: 'Podcast & audio', icon: 'mic'),
    SpaceCategory(id: 'cat_product', name: 'Product shoots', icon: 'inventory'),
    SpaceCategory(id: 'cat_fashion', name: 'Fashion', icon: 'fashion'),
    SpaceCategory(id: 'cat_film', name: 'Cinematic & film', icon: 'movie'),
    SpaceCategory(id: 'cat_event', name: 'Weddings & events', icon: 'event'),
  ];

  // ---- Spaces -----------------------------------------------------------
  StudioSpace sp(
    String n,
    String code,
    String studio,
    String name,
    String cat,
    int rateTaka, {
    int disc = 0,
    required int cap,
    required String dims,
    required String desc,
    required List<String> facilities,
    required List<String> equipment,
    List<String> rules = const [
      'No food or drink on set surfaces',
      'Shoes off on the white floor',
      'Overtime is charged per 30 minutes',
    ],
    int open = 540,
    int close = 1260,
    int min = 60,
    int max = 480,
    int buffer = 30,
    int pop = 0,
    List<int> closed = const [],
    int created = 120,
  }) =>
      StudioSpace(
        id: 'sp_$n',
        code: code,
        studioId: studio,
        name: name,
        categoryId: cat,
        description: desc,
        images: [_img('$code-1'), _img('$code-2'), _img('$code-3')],
        facilities: facilities,
        equipment: equipment,
        rules: rules,
        capacity: cap,
        dimensions: dims,
        hourlyRate: Money.taka(rateTaka),
        discountBp: disc,
        hours: OperatingHours(openMinute: open, closeMinute: close, closedWeekdays: closed),
        minMinutes: min,
        maxMinutes: max,
        bufferMinutes: buffer,
        popularity: pop,
        createdAt: now.subtract(Duration(days: created)),
      );

  const fCommon = ['Air conditioning', 'Wi-Fi', 'Changing room', 'Parking'];
  db.spaces = [
    sp('1', 'LV-CYC-01', 'st_1', 'The White Cyclorama', 'cat_photo', 2800,
        cap: 12, dims: '24 × 20 ft, 12 ft ceiling', pop: 94, created: 380,
        desc: 'A seamless white cyclorama wall with a polished floor, built for clean catalogue, portrait and product-on-model work.',
        facilities: [...fCommon, 'Makeup station', 'Backdrop stands'],
        equipment: ['Profoto B10 ×4', 'C-stand set', 'Reflector kit', 'Tethering station']),
    sp('2', 'LV-FSH-02', 'st_1', 'Marble Atelier', 'cat_fashion', 3200,
        disc: 1000, cap: 10, dims: '20 × 18 ft', pop: 88, created: 300,
        desc: 'Veined marble walls, brass fixtures and tall arched windows. A quiet, editorial set for fashion and jewellery.',
        facilities: [...fCommon, 'Steamer & rack', 'Lounge seating'],
        equipment: ['Continuous LED ×3', 'Light modifiers', 'Posing furniture']),
    sp('3', 'LV-PRD-03', 'st_1', 'Tabletop Studio', 'cat_product', 1500,
        cap: 6, dims: '14 × 12 ft', pop: 70, min: 60, max: 360, created: 250,
        desc: 'A compact product set with a sweep table, overhead rig and neutral surfaces for packshots and flat lays.',
        facilities: ['Air conditioning', 'Wi-Fi', 'Prop storage'],
        equipment: ['Overhead boom', 'Light tent', 'Copy stand', 'Surface kit (12)']),
    sp('4', 'LV-PRT-04', 'st_1', 'Golden Hour Terrace', 'cat_photo', 2200,
        disc: 2000, cap: 14, dims: '30 × 16 ft rooftop', pop: 76, open: 480, close: 1140, created: 90,
        desc: 'A west-facing rooftop terrace with climbing plants and warm brick. Best at late afternoon; closes before dark.',
        facilities: ['Wi-Fi', 'Washroom', 'Seating area', 'Parking'],
        equipment: ['Reflectors', 'Diffusion frames', 'Battery lights ×2'],
        rules: ['Weather may affect outdoor sets; reschedule is by request', 'No glass items on the terrace']),
    sp('5', 'LV-NEO-05', 'st_1', 'Neon Alley Set', 'cat_fashion', 2600,
        cap: 8, dims: '22 × 14 ft', pop: 81, created: 60,
        desc: 'Wet-look floor, brick walls and programmable neon signage for street and nightlife looks.',
        facilities: [...fCommon, 'Haze machine permitted'],
        equipment: ['RGB tube lights ×6', 'Haze machine', 'Gels & flags']),
    sp('6', 'RE-POD-01', 'st_2', 'Soundproof Podcast Room', 'cat_podcast', 1800,
        cap: 5, dims: '12 × 10 ft, treated', pop: 92, max: 360, created: 280,
        desc: 'A fully treated room with four mics, a mixer and a camera rig. Record audio and multi-cam video in one session.',
        facilities: ['Air conditioning', 'Wi-Fi', 'Green room', 'Tea & water'],
        equipment: ['Shure SM7B ×4', 'RØDECaster Pro', 'Sony FX30 ×2', 'Acoustic panels']),
    sp('7', 'RE-INT-02', 'st_2', 'Interview Lounge', 'cat_video', 2400,
        disc: 500, cap: 8, dims: '18 × 15 ft', pop: 73, created: 220,
        desc: 'A two-chair interview set with bookshelf backdrop and soft key light. Teleprompter on request.',
        facilities: [...fCommon, 'Green room'],
        equipment: ['ARRI SkyPanel', 'Lavalier mics ×3', 'Teleprompter', 'Sony FX3']),
    sp('8', 'RE-GRN-03', 'st_2', 'Green Screen Stage', 'cat_video', 3500,
        cap: 15, dims: '28 × 24 ft, 14 ft grid', pop: 66, created: 190,
        desc: 'A chroma-green cyclorama with a lighting grid for ads, music videos and virtual production tests.',
        facilities: [...fCommon, 'Makeup station', 'Client lounge'],
        equipment: ['Aputure 600d ×4', 'Dolly & track', 'Grip package', 'Monitor cart']),
    sp('9', 'RE-FLM-04', 'st_2', 'Noir Film Set', 'cat_film', 4500,
        disc: 1500, cap: 20, dims: '30 × 26 ft, 16 ft ceiling', pop: 97, min: 120, max: 600, created: 150,
        desc: 'A dressed 1960s apartment set with practical lamps and period furniture. Built for cinematic scenes.',
        facilities: [...fCommon, 'Catering corner', 'Costume room'],
        equipment: ['Practical lighting kit', 'Fog machine', 'Slider', 'Cine lenses (on request)'],
        rules: ['Set dressing may not be moved off the marked floor plan', 'Smoking and open flames are not allowed']),
    sp('10', 'RE-VOC-05', 'st_2', 'Voice-over Booth', 'cat_podcast', 1200,
        cap: 2, dims: '8 × 7 ft, isolated', pop: 58, max: 240, created: 100,
        desc: 'A single-person isolation booth for voice-over, dubbing and audiobook recording.',
        facilities: ['Air conditioning', 'Wi-Fi', 'Tea & water'],
        equipment: ['Neumann TLM 103', 'UAD Apollo interface', 'Monitor headphones']),
    sp('11', 'TC-LIV-01', 'st_3', 'Mediterranean Living Room', 'cat_photo', 2500,
        cap: 10, dims: '22 × 18 ft', pop: 84, created: 180,
        desc: 'Terracotta walls, linen sofas and big south windows. A warm lifestyle and family-portrait set.',
        facilities: [...fCommon, 'Props library', 'Kitchenette'],
        equipment: ['Reflectors', 'Soft boxes ×2', 'Props & plants']),
    sp('12', 'TC-KIT-02', 'st_3', 'Farmhouse Kitchen', 'cat_product', 2000,
        cap: 8, dims: '16 × 14 ft', pop: 69, created: 170,
        desc: 'A working farmhouse kitchen with gas hob and wooden counters for food, cookware and cooking videos.',
        facilities: ['Working kitchen', 'Air conditioning', 'Wi-Fi', 'Refrigerator'],
        equipment: ['Overhead rig', 'LED panels ×2', 'Cookware set']),
    sp('13', 'TC-EVT-03', 'st_3', 'Garden Courtyard', 'cat_event', 5000,
        disc: 1000, cap: 60, dims: '60 × 40 ft open courtyard', pop: 79, min: 120, max: 720, buffer: 60, created: 140,
        desc: 'A walled garden courtyard with a pergola and string lights for engagement shoots, mehndi and small weddings.',
        facilities: ['Washrooms', 'Parking (20 cars)', 'Bridal room', 'Generator backup'],
        equipment: ['Chairs (60)', 'Pergola lighting', 'Sound system'],
        rules: ['Outside caterers must be pre-approved', 'Music stops by 10:00 PM']),
    sp('14', 'TC-BRD-04', 'st_3', 'Bridal Suite', 'cat_event', 3800,
        cap: 12, dims: '20 × 16 ft', pop: 62, closed: const [7], created: 110,
        desc: 'A bright dressing suite with vanity mirrors and a daybed. Popular for getting-ready photography.',
        facilities: [...fCommon, 'Vanity mirrors', 'Garment racks'],
        equipment: ['Ring lights ×2', 'Steamer', 'Reflectors']),
  ];

  // ---- People -----------------------------------------------------------
  const allPerms = StaffPermission.values;
  db.users = [
    AppUser(
      id: 'u_admin',
      role: UserRole.admin,
      fullName: 'Sara Karim',
      email: demoAdminEmail,
      phone: '+8801700000001',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 500)),
    ),
    AppUser(
      id: 'u_mgr1',
      role: UserRole.manager,
      fullName: 'Nabila Rahman',
      email: demoManagerEmail,
      phone: '+8801700000002',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 300)),
      manager: const ManagerProfile(
        studioIds: ['st_1', 'st_2'],
        permissions: {...allPerms},
      ),
    ),
    AppUser(
      id: 'u_mgr2',
      role: UserRole.manager,
      fullName: 'Tanvir Ahmed',
      email: 'tanvir@lavenga.app',
      phone: '+8801700000003',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 150)),
      manager: const ManagerProfile(
        studioIds: ['st_3'],
        permissions: {
          StaffPermission.manageSpaces,
          StaffPermission.confirmBookings,
          StaffPermission.viewCustomers,
          StaffPermission.handleSupport,
        },
      ),
    ),
    AppUser(
      id: 'u_c1',
      role: UserRole.customer,
      fullName: 'Ayesha Siddiqua',
      email: demoCustomerEmail,
      phone: '+8801711000001',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 220)),
      customer: CustomerProfile(
        address: 'Flat 4B, Road 5, Dhanmondi, Dhaka',
        gender: Gender.female,
        dateOfBirth: DateTime.utc(1994, 3, 12),
        discountBp: 500,
        avatarUrl: _img('ayesha', 200, 200),
      ),
    ),
    AppUser(
      id: 'u_c2',
      role: UserRole.customer,
      fullName: 'Rafiq Hasan',
      email: 'rafiq@example.com',
      phone: '+8801711000002',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 180)),
      customer: const CustomerProfile(address: 'Uttara Sector 7, Dhaka'),
    ),
    AppUser(
      id: 'u_c3',
      role: UserRole.customer,
      fullName: 'Mim Chowdhury',
      email: 'mim@example.com',
      phone: '+8801711000003',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 120)),
      customer: const CustomerProfile(gender: Gender.female),
    ),
    AppUser(
      id: 'u_c4',
      role: UserRole.customer,
      fullName: 'Sadman Karim',
      phone: '+8801811000004',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 80)),
      customer: const CustomerProfile(),
    ),
    AppUser(
      id: 'u_c5',
      role: UserRole.customer,
      fullName: 'Farzana Islam',
      email: 'farzana@example.com',
      phone: '+8801711000005',
      password: demoPassword,
      createdAt: now.subtract(const Duration(days: 60)),
      customer: const CustomerProfile(),
    ),
    AppUser(
      id: 'u_c6',
      role: UserRole.customer,
      fullName: 'Imran Hossain',
      email: 'imran@example.com',
      phone: '+8801711000006',
      password: demoPassword,
      status: AccountStatus.blacklisted,
      createdAt: now.subtract(const Duration(days: 90)),
      customer: const CustomerProfile(blacklistReason: 'Repeated no-shows without notice'),
    ),
  ];
  AppUser user(String id) => db.users.firstWhere((u) => u.id == id);
  StudioSpace space(String id) => db.spaces.firstWhere((s) => s.id == id);

  // ---- Discounts and coupons ---------------------------------------------
  db.discounts = [
    Discount(
      id: 'd_1',
      name: 'Welcome 10%',
      kind: DiscountKind.percentage,
      value: 1000,
      scope: DiscountScope.global,
      minBooking: Money.taka(2000),
      maxDiscount: Money.taka(1000),
      startsAt: now.subtract(const Duration(days: 90)),
      endsAt: now.add(const Duration(days: 180)),
    ),
    Discount(
      id: 'd_2',
      name: 'Flat ৳500 off',
      kind: DiscountKind.fixed,
      value: Money.taka(500).minor,
      scope: DiscountScope.global,
      minBooking: Money.taka(3000),
      startsAt: now.subtract(const Duration(days: 30)),
      endsAt: now.add(const Duration(days: 60)),
    ),
    Discount(
      id: 'd_3',
      name: 'Podcast Pro 15%',
      kind: DiscountKind.percentage,
      value: 1500,
      scope: DiscountScope.category,
      targetIds: const ['cat_podcast'],
      startsAt: now.subtract(const Duration(days: 10)),
      endsAt: now.add(const Duration(days: 90)),
    ),
    Discount(
      id: 'd_4',
      name: 'Eid Special 20%',
      kind: DiscountKind.percentage,
      value: 2000,
      scope: DiscountScope.global,
      startsAt: now.subtract(const Duration(days: 120)),
      endsAt: now.subtract(const Duration(days: 30)),
    ),
    Discount(
      id: 'd_5',
      name: 'Noir Night 12%',
      kind: DiscountKind.percentage,
      value: 1200,
      scope: DiscountScope.space,
      targetIds: const ['sp_9'],
      maxDiscount: Money.taka(2500),
      startsAt: now.subtract(const Duration(days: 5)),
      endsAt: now.add(const Duration(days: 45)),
    ),
  ];
  db.coupons = [
    const Coupon(id: 'cp_1', code: 'WELCOME10', discountId: 'd_1', usageLimit: 500, redemptions: {'u_c2': 1}),
    const Coupon(id: 'cp_2', code: 'FLAT500', discountId: 'd_2', usageLimit: 100, perCustomerLimit: 2),
    const Coupon(id: 'cp_3', code: 'PODCAST15', discountId: 'd_3', perCustomerLimit: 3),
    const Coupon(id: 'cp_4', code: 'EID20', discountId: 'd_4'),
    const Coupon(id: 'cp_5', code: 'NOIR12', discountId: 'd_5', usageLimit: 3, redemptions: {'u_c3': 1, 'u_c4': 1, 'u_c5': 1}),
  ];

  db.settings = PlatformSettings(
    banners: [
      HomeBanner(
        id: 'bn_1',
        title: 'Shoot something beautiful',
        subtitle: 'Fourteen sets across three studios, bookable by the hour.',
        imageUrl: _img('banner-1', 1000, 500),
      ),
      HomeBanner(
        id: 'bn_2',
        title: 'Podcast season is open',
        subtitle: 'Use PODCAST15 for 15% off audio rooms.',
        imageUrl: _img('banner-2', 1000, 500),
      ),
      HomeBanner(
        id: 'bn_3',
        title: 'Weddings in the courtyard',
        subtitle: 'Garden Courtyard now with 10% off.',
        imageUrl: _img('banner-3', 1000, 500),
      ),
    ],
    featuredSpaceIds: const ['sp_1', 'sp_9', 'sp_13', 'sp_6', 'sp_11'],
  );

  // ---- Bookings, payments, refunds --------------------------------------
  var bookingCount = 0;
  Booking mk({
    required String customer,
    required List<(String, int, int, int)> items, // space, dayOffset, startMinute, minutes
    required BookingStatus status,
    String? coupon,
    String? cancelReason,
    int createdDaysAgo = 3,
    DateTime? holdExpiresAt,
  }) {
    bookingCount++;
    final id = 'bk_$bookingCount';
    final c = user(customer);
    final inputs = <QuoteInput>[];
    final bookingItems = <BookingItem>[];
    for (var i = 0; i < items.length; i++) {
      final (spaceId, day, startMin, minutes) = items[i];
      final s = space(spaceId);
      final start = at(day, startMin);
      final schedule = BookingSchedule(start: start, end: start.add(Duration(minutes: minutes)));
      inputs.add(QuoteInput(itemId: '${id}_i$i', space: s, schedule: schedule));
      final studio = db.studios.firstWhere((st) => st.id == s.studioId);
      bookingItems.add(BookingItem(
        id: '${id}_i$i',
        spaceId: s.id,
        spaceCode: s.code,
        spaceName: s.name,
        studioId: s.studioId,
        studioName: studio.name,
        schedule: schedule,
        hourlyRate: s.hourlyRate,
        spaceDiscountBp: s.discountBp,
        imageUrl: s.images.first,
      ));
    }
    final quote = PricingService.quote(
      items: inputs,
      settings: db.settings,
      customerId: customer,
      now: now.subtract(Duration(days: createdDaysAgo)),
      customerDiscountBp: c.customer?.discountBp ?? 0,
      couponCode: coupon,
      coupons: db.coupons,
      discounts: db.discounts,
    );
    final created = now.subtract(Duration(days: createdDaysAgo));
    final booking = Booking(
      id: id,
      reference: 'LV-${(2610 + bookingCount).toString()}-${(100 + bookingCount * 7)}',
      customerId: customer,
      customerName: c.fullName,
      items: bookingItems,
      pricing: quote.pricing,
      status: status,
      paymentStatus: PaymentStatus.unpaid,
      cancelReason: cancelReason,
      holdExpiresAt: holdExpiresAt,
      createdAt: created,
      updatedAt: created,
      timeline: [
        TimelineEvent(at: created, title: 'Order placed', actor: c.fullName),
        if (status != BookingStatus.pendingReview && status != BookingStatus.expired)
          TimelineEvent(
            at: created.add(const Duration(hours: 5)),
            title: status.label,
            actor: status == BookingStatus.cancelled && cancelReason != null
                ? 'Nabila Rahman'
                : 'Nabila Rahman',
            note: cancelReason,
          ),
      ],
    );
    db.bookings.add(booking);
    return booking;
  }

  var payCount = 0;
  Payment pay(Booking b, PaymentKind kind, Money amount,
      {TransactionStatus status = TransactionStatus.verified,
      PaymentMethod method = PaymentMethod.bkash,
      int daysAgo = 3}) {
    payCount++;
    final id = 'pay_$payCount';
    final p = Payment(
      id: id,
      bookingId: b.id,
      bookingRef: b.reference,
      customerId: b.customerId,
      kind: kind,
      amount: amount,
      createdAt: now.subtract(Duration(days: daysAgo)),
      transactions: [
        PaymentTransaction(
          id: '${id}_t1',
          paymentId: id,
          amount: amount,
          method: method,
          status: status,
          gatewayRef: 'SSL${900000 + payCount * 137}',
          at: now.subtract(Duration(days: daysAgo)),
          failureReason: status == TransactionStatus.failed ? 'Insufficient balance' : null,
        ),
      ],
    );
    db.payments.add(p);
    return p;
  }

  var refundCount = 0;
  RefundRequest refund(
    Booking b,
    Money requested,
    RefundStatus status, {
    String reason = 'Plans changed',
    Money? approved,
    String? managerNote,
    String? adminNote,
  }) {
    refundCount++;
    final id = 'rf_$refundCount';
    final c = user(b.customerId);
    final created = now.subtract(Duration(days: 2));
    final events = <TimelineEvent>[
      TimelineEvent(at: created, title: 'Refund requested', actor: c.fullName, note: reason),
      if (status != RefundStatus.requested)
        TimelineEvent(at: created.add(const Duration(hours: 4)), title: 'Reviewed by manager', actor: 'Nabila Rahman', note: managerNote),
      if (status == RefundStatus.forwardedToAdmin ||
          status == RefundStatus.approved ||
          status == RefundStatus.processing ||
          status == RefundStatus.refunded)
        TimelineEvent(at: created.add(const Duration(hours: 5)), title: 'Forwarded to administrator', actor: 'Nabila Rahman'),
      if (status == RefundStatus.approved || status == RefundStatus.refunded)
        TimelineEvent(at: created.add(const Duration(hours: 20)), title: 'Approved', actor: 'Sara Karim', note: adminNote),
      if (status == RefundStatus.refunded)
        TimelineEvent(at: created.add(const Duration(hours: 22)), title: 'Refund completed', actor: 'Sara Karim'),
    ];
    final r = RefundRequest(
      id: id,
      bookingId: b.id,
      bookingRef: b.reference,
      customerId: b.customerId,
      customerName: c.fullName,
      reason: reason,
      requested: requested,
      approved: approved,
      status: status,
      managerNote: managerNote,
      adminNote: adminNote,
      customerNote: status == RefundStatus.refunded ? 'Refunded to your original payment method.' : null,
      timeline: events,
      transactions: status == RefundStatus.refunded
          ? [
              RefundTransaction(
                id: '${id}_t1',
                refundId: id,
                amount: approved ?? requested,
                status: TransactionStatus.verified,
                gatewayRef: 'RFD${700000 + refundCount * 91}',
                at: created.add(const Duration(hours: 22)),
              ),
            ]
          : const [],
      createdAt: created,
      updatedAt: created.add(const Duration(hours: 22)),
    );
    db.refunds.add(r);
    return r;
  }

  // Headline demo bookings
  final b1 = mk(customer: 'u_c1', items: [('sp_1', 2, 600, 120)], status: BookingStatus.confirmed);
  pay(b1, PaymentKind.advance, b1.pricing.advanceRequired, daysAgo: 2);

  final b2 = mk(customer: 'u_c1', items: [('sp_6', 4, 720, 120), ('sp_10', 4, 900, 60)], status: BookingStatus.pendingReview, createdDaysAgo: 1);
  pay(b2, PaymentKind.advance, b2.pricing.advanceRequired, daysAgo: 1, method: PaymentMethod.card);

  final b3 = mk(customer: 'u_c1', items: [('sp_4', -9, 960, 120)], status: BookingStatus.completed, createdDaysAgo: 14);
  pay(b3, PaymentKind.full, b3.pricing.total, daysAgo: 13);

  final b4 = mk(customer: 'u_c2', items: [('sp_9', -5, 600, 180)], status: BookingStatus.completed, createdDaysAgo: 10, coupon: 'WELCOME10');
  pay(b4, PaymentKind.full, b4.pricing.total, daysAgo: 9, method: PaymentMethod.card);

  final b5 = mk(customer: 'u_c3', items: [('sp_11', 4, 840, 120)], status: BookingStatus.confirmed, createdDaysAgo: 4);
  pay(b5, PaymentKind.full, b5.pricing.total, daysAgo: 4, method: PaymentMethod.nagad);
  refund(b5, Money.fromMinor(b5.pricing.total.minor ~/ 2), RefundStatus.underManagerReview,
      reason: 'Family event moved to another date');

  final b6 = mk(customer: 'u_c2', items: [('sp_2', 6, 660, 120)], status: BookingStatus.cancelled, createdDaysAgo: 5, cancelReason: 'Cancelled by customer before confirmation');
  pay(b6, PaymentKind.advance, b6.pricing.advanceRequired, status: TransactionStatus.failed, daysAgo: 5);

  final b7 = mk(customer: 'u_c4', items: [('sp_13', 10, 600, 240)], status: BookingStatus.confirmed, createdDaysAgo: 6);
  pay(b7, PaymentKind.advance, b7.pricing.advanceRequired, daysAgo: 6, method: PaymentMethod.bank);
  refund(b7, b7.pricing.advanceRequired, RefundStatus.forwardedToAdmin,
      reason: 'Venue no longer needed', managerNote: 'Within refund window; recommend approval.');

  final b8 = mk(customer: 'u_c3', items: [('sp_5', -2, 1080, 60)], status: BookingStatus.completed, createdDaysAgo: 6);
  pay(b8, PaymentKind.full, b8.pricing.total, daysAgo: 5);

  final b9 = mk(customer: 'u_c5', items: [('sp_7', 3, 780, 120)], status: BookingStatus.cancelled, createdDaysAgo: 7, cancelReason: 'Equipment maintenance — studio could not host');
  pay(b9, PaymentKind.advance, b9.pricing.advanceRequired, daysAgo: 7);
  refund(b9, b9.pricing.advanceRequired, RefundStatus.approved,
      reason: 'Studio cancelled', approved: b9.pricing.advanceRequired,
      managerNote: 'Studio-initiated cancellation.', adminNote: 'Approved in full.');

  final b10 = mk(customer: 'u_c5', items: [('sp_3', -15, 600, 120)], status: BookingStatus.cancelled, createdDaysAgo: 20, cancelReason: 'Customer requested cancellation by phone');
  pay(b10, PaymentKind.full, b10.pricing.total, daysAgo: 19);
  refund(b10, b10.pricing.total, RefundStatus.refunded,
      reason: 'Cancelled well ahead', approved: Money.fromMinor(b10.pricing.total.minor ~/ 2),
      managerNote: 'Eligible for 50%.', adminNote: 'Approved at 50% per policy.');

  mk(customer: 'u_c4', items: [('sp_8', 1, 600, 120)], status: BookingStatus.expired, createdDaysAgo: 2);

  // Historic completed bookings that carry reviews (also feed reports).
  final historic = <(String, String, int, int, String)>[
    ('u_c2', 'sp_1', 5, -20, 'Clean white wall and great light. Staff set up everything before we arrived.'),
    ('u_c3', 'sp_1', 4, -26, 'Spacious and well kept. Parking was tight on a Friday.'),
    ('u_c1', 'sp_2', 5, -32, 'The marble set looked exactly like the photos. Worth every taka.'),
    ('u_c5', 'sp_6', 5, -18, 'Audio was spotless on the first take. Mics and mixer were ready to go.'),
    ('u_c2', 'sp_6', 4, -40, 'Great sound treatment. Room is small for four guests.'),
    ('u_c3', 'sp_9', 5, -28, 'Feels like a real 60s apartment. The practical lamps made our scene.'),
    ('u_c4', 'sp_9', 4, -45, 'Beautiful set. Fog machine needed an operator, which we hadn\'t expected.'),
    ('u_c1', 'sp_11', 5, -35, 'Warm, golden, easy. The kitchenette saved us.'),
    ('u_c5', 'sp_13', 4, -50, 'Lovely courtyard. Plan for mosquitoes in the evening.'),
    ('u_c2', 'sp_4', 3, -22, 'Lovely terrace but it was hazy. Rescheduling took a couple of messages.'),
  ];
  var reviewCount = 0;
  for (final (cust, spId, rating, day, comment) in historic) {
    final b = mk(
      customer: cust,
      items: [(spId, day, 600, 120)],
      status: BookingStatus.completed,
      createdDaysAgo: -day + 3,
    );
    pay(b, PaymentKind.full, b.pricing.total, daysAgo: -day + 2);
    reviewCount++;
    db.reviews.add(Review(
      id: 'rv_$reviewCount',
      bookingId: b.id,
      itemId: b.items.first.id,
      spaceId: spId,
      customerId: cust,
      customerName: user(cust).fullName,
      rating: rating,
      comment: comment,
      createdAt: at(day + 1, 600),
    ));
  }
  // Two reviews on headline completed bookings.
  db.reviews.add(Review(
    id: 'rv_${++reviewCount}',
    bookingId: b4.id,
    itemId: b4.items.first.id,
    spaceId: 'sp_9',
    customerId: 'u_c2',
    customerName: user('u_c2').fullName,
    rating: 5,
    comment: 'Shot our short film here in one day. The set dressing is superb.',
    createdAt: at(-4, 600),
  ));
  db.reviews.add(Review(
    id: 'rv_${++reviewCount}',
    bookingId: b8.id,
    itemId: b8.items.first.id,
    spaceId: 'sp_5',
    customerId: 'u_c3',
    customerName: user('u_c3').fullName,
    rating: 4,
    comment: 'Fun neon look. Wish the session could have been longer than an hour.',
    createdAt: at(-1, 600),
  ));
  // b3 (Ayesha, Golden Hour Terrace) intentionally has no review yet.

  // Recompute payment status from ledgers, then space ratings.
  for (var i = 0; i < db.bookings.length; i++) {
    final b = db.bookings[i];
    final pays = db.payments.where((p) => p.bookingId == b.id).toList();
    final refunded = db.refunds
        .where((r) => r.bookingId == b.id)
        .fold(Money.zero, (sum, r) => sum + r.refunded);
    db.bookings[i] = b.copyWith(
      paymentStatus: PaymentCalculator.statusFor(
        total: b.pricing.total,
        payments: pays,
        refunded: refunded,
      ),
    );
  }
  for (var i = 0; i < db.spaces.length; i++) {
    final s = db.spaces[i];
    final rs = db.reviews.where((r) => r.spaceId == s.id).toList();
    if (rs.isNotEmpty) {
      final avg = rs.fold<int>(0, (a, r) => a + r.rating) / rs.length;
      db.spaces[i] = s.copyWith(ratingAvg: avg, ratingCount: rs.length);
    }
  }

  // ---- Support, favourites, notifications, audit ------------------------
  SupportMessage msg(String id, AppUser u, String body, int hoursAgo) => SupportMessage(
        id: id,
        senderId: u.id,
        senderName: u.fullName,
        senderRole: u.role,
        body: body,
        at: now.subtract(Duration(hours: hoursAgo)),
      );
  db.tickets = [
    SupportTicket(
      id: 'tk_1',
      reference: 'TK-1041',
      customerId: 'u_c1',
      customerName: 'Ayesha Siddiqua',
      category: 'Booking change',
      subject: 'Can I move my session to the afternoon?',
      status: TicketStatus.awaitingStaff,
      bookingId: b1.id,
      bookingRef: b1.reference,
      messages: [
        msg('m1', user('u_c1'), 'Hi, my model can only come in the afternoon. Is it possible to shift my booking by three hours?', 20),
      ],
      createdAt: now.subtract(const Duration(hours: 20)),
      updatedAt: now.subtract(const Duration(hours: 20)),
    ),
    SupportTicket(
      id: 'tk_2',
      reference: 'TK-1038',
      customerId: 'u_c2',
      customerName: 'Rafiq Hasan',
      category: 'Invoice',
      subject: 'Need an invoice for my Noir Film Set booking',
      status: TicketStatus.resolved,
      bookingId: b4.id,
      bookingRef: b4.reference,
      unreadForCustomer: true,
      messages: [
        msg('m2', user('u_c2'), 'Could you share an invoice with our company name?', 96),
        msg('m3', user('u_mgr1'), 'Of course. We have added the company name to your receipt; you can download it from the booking page.', 90),
      ],
      createdAt: now.subtract(const Duration(hours: 96)),
      updatedAt: now.subtract(const Duration(hours: 90)),
    ),
    SupportTicket(
      id: 'tk_3',
      reference: 'TK-1044',
      customerId: 'u_c3',
      customerName: 'Mim Chowdhury',
      category: 'Refund',
      subject: 'Question about my refund request',
      status: TicketStatus.escalated,
      bookingId: b5.id,
      bookingRef: b5.reference,
      messages: [
        msg('m4', user('u_c3'), 'I requested a refund two days ago and have not heard back. How long does it take?', 30),
        msg('m5', user('u_mgr1'), 'Thanks for your patience. Your request is with our review team. We have escalated it so you get an answer soon.', 26),
      ],
      createdAt: now.subtract(const Duration(hours: 30)),
      updatedAt: now.subtract(const Duration(hours: 26)),
    ),
  ];

  db.favorites = [
    CustomerFavorite(userId: 'u_c1', spaceId: 'sp_1', at: now.subtract(const Duration(days: 30))),
    CustomerFavorite(userId: 'u_c1', spaceId: 'sp_9', at: now.subtract(const Duration(days: 12))),
    CustomerFavorite(userId: 'u_c1', spaceId: 'sp_13', at: now.subtract(const Duration(days: 3))),
  ];
  db.viewed = {
    'u_c1': ['sp_11', 'sp_6', 'sp_2'],
  };

  AppNotification note(String id, String uid, String title, String body, String type,
          String? ref, int hoursAgo, {bool read = false}) =>
      AppNotification(
        id: id,
        userId: uid,
        title: title,
        body: body,
        type: type,
        refId: ref,
        read: read,
        createdAt: now.subtract(Duration(hours: hoursAgo)),
      );
  db.notifications = [
    note('nt_1', 'u_c1', 'Booking confirmed', '${b1.reference} is confirmed for The White Cyclorama.', 'booking', b1.id, 40),
    note('nt_2', 'u_c1', 'Payment received', 'We received your advance for ${b1.reference}.', 'payment', b1.id, 47, read: true),
    note('nt_3', 'u_c1', 'Share your experience', 'How was Golden Hour Terrace? Leave a review.', 'booking', b3.id, 120),
    note('nt_4', 'u_mgr1', 'Booking awaiting review', '${b2.reference} needs confirmation.', 'booking', b2.id, 22),
    note('nt_5', 'u_admin', 'Refund awaiting approval', '${db.refunds[1].bookingRef} was forwarded by Nabila Rahman.', 'refund', db.refunds[1].id, 18),
  ];

  AuditLog log(String id, String actor, UserRole role, String name, String action, String target,
          int hoursAgo, {String? detail, bool sensitive = false}) =>
      AuditLog(
        id: id,
        actorId: actor,
        actorName: name,
        actorRole: role,
        action: action,
        target: target,
        detail: detail,
        sensitive: sensitive,
        at: now.subtract(Duration(hours: hoursAgo)),
      );
  db.audit = [
    log('au_1', 'u_admin', UserRole.admin, 'Sara Karim', 'login', 'Session', 2),
    log('au_2', 'u_mgr1', UserRole.manager, 'Nabila Rahman', 'login', 'Session', 3),
    log('au_3', 'u_admin', UserRole.admin, 'Sara Karim', 'Blacklisted customer', 'Imran Hossain', 70,
        detail: 'Repeated no-shows without notice', sensitive: true),
    log('au_4', 'u_admin', UserRole.admin, 'Sara Karim', 'Approved refund', db.refunds[3].bookingRef, 90,
        detail: 'Approved at 50% per policy', sensitive: true),
    log('au_5', 'u_mgr1', UserRole.manager, 'Nabila Rahman', 'Confirmed booking', b1.reference, 46),
    log('au_6', 'u_admin', UserRole.admin, 'Sara Karim', 'Changed manager permissions', 'Tanvir Ahmed', 200,
        detail: 'Removed refund and payment access', sensitive: true),
  ];
}
