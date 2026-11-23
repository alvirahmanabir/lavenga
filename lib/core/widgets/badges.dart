import 'package:material_ui/material_ui.dart';

import '../../domain/enums.dart';
import '../theme/app_tokens.dart';
import 'status_badge.dart';

/// Thin wrappers mapping each independent status enum to label + icon + tone.

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      BookingStatus.pendingReview => (Icons.schedule, StatusTone.warning),
      BookingStatus.confirmed => (Icons.check_circle, StatusTone.success),
      BookingStatus.inProgress => (Icons.play_circle, StatusTone.info),
      BookingStatus.completed => (Icons.task_alt, StatusTone.neutral),
      BookingStatus.rejected => (Icons.block, StatusTone.error),
      BookingStatus.cancelled => (Icons.cancel, StatusTone.error),
      BookingStatus.expired => (Icons.timer_off, StatusTone.neutral),
      BookingStatus.noShow => (Icons.person_off, StatusTone.error),
    };
    return StatusBadge(label: status.label, icon: icon, tone: tone);
  }
}

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge(this.status, {super.key});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      PaymentStatus.unpaid => (Icons.payments_outlined, StatusTone.warning),
      PaymentStatus.pendingVerification => (Icons.hourglass_top, StatusTone.info),
      PaymentStatus.partiallyPaid => (Icons.timelapse, StatusTone.info),
      PaymentStatus.paid => (Icons.verified, StatusTone.success),
      PaymentStatus.failed => (Icons.error, StatusTone.error),
      PaymentStatus.refunded => (Icons.undo, StatusTone.neutral),
      PaymentStatus.partiallyRefunded => (Icons.undo, StatusTone.neutral),
    };
    return StatusBadge(label: status.label, icon: icon, tone: tone);
  }
}

class TransactionStatusBadge extends StatelessWidget {
  const TransactionStatusBadge(this.status, {super.key});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      TransactionStatus.initiated => (Icons.hourglass_empty, StatusTone.neutral),
      TransactionStatus.pendingVerification => (Icons.hourglass_top, StatusTone.info),
      TransactionStatus.verified => (Icons.verified, StatusTone.success),
      TransactionStatus.failed => (Icons.error, StatusTone.error),
      TransactionStatus.cancelled => (Icons.cancel, StatusTone.neutral),
      TransactionStatus.timedOut => (Icons.timer_off, StatusTone.error),
    };
    return StatusBadge(label: status.label, icon: icon, tone: tone);
  }
}

class RefundStatusBadge extends StatelessWidget {
  const RefundStatusBadge(this.status, {super.key});
  final RefundStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      RefundStatus.requested => (Icons.outbox, StatusTone.warning),
      RefundStatus.underManagerReview => (Icons.rate_review, StatusTone.warning),
      RefundStatus.rejectedByManager => (Icons.block, StatusTone.error),
      RefundStatus.forwardedToAdmin => (Icons.forward_to_inbox, StatusTone.info),
      RefundStatus.approved => (Icons.thumb_up_alt_outlined, StatusTone.success),
      RefundStatus.rejectedByAdmin => (Icons.block, StatusTone.error),
      RefundStatus.processing => (Icons.sync, StatusTone.info),
      RefundStatus.refunded => (Icons.check_circle, StatusTone.success),
      RefundStatus.failed => (Icons.error, StatusTone.error),
    };
    return StatusBadge(label: status.label, icon: icon, tone: tone);
  }
}

class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge(this.status, {super.key});
  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      TicketStatus.open => (Icons.mark_email_unread_outlined, StatusTone.info),
      TicketStatus.awaitingCustomer => (Icons.reply, StatusTone.warning),
      TicketStatus.awaitingStaff => (Icons.hourglass_top, StatusTone.warning),
      TicketStatus.escalated => (Icons.priority_high, StatusTone.error),
      TicketStatus.resolved => (Icons.check_circle, StatusTone.success),
      TicketStatus.closed => (Icons.lock_outline, StatusTone.neutral),
    };
    return StatusBadge(label: status.label, icon: icon, tone: tone);
  }
}

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge(this.status, {super.key});
  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      AccountStatus.active => (Icons.check_circle, StatusTone.success),
      AccountStatus.suspended => (Icons.pause_circle, StatusTone.warning),
      AccountStatus.blacklisted => (Icons.block, StatusTone.error),
      AccountStatus.deactivated => (Icons.power_settings_new, StatusTone.neutral),
    };
    return StatusBadge(
      label: status.name[0].toUpperCase() + status.name.substring(1),
      icon: icon,
      tone: tone,
    );
  }
}
