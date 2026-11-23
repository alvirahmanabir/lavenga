import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../errors/app_failure.dart';
import '../theme/app_tokens.dart';
import 'state_views.dart';

/// Renders an [AsyncValue] with the app's loading, error and retry states.
/// Keeps showing previous data while refreshing, so lists never flash blank.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) {
      return ErrorState(failure: toFailure(value.error!), onRetry: onRetry);
    }
    return loading ?? const ListSkeleton();
  }
}

/// Generic loading skeleton: a few card-shaped blocks.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 150, radius: AppRadii.card),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 200),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: 120),
        ],
      ),
    );
  }
}
