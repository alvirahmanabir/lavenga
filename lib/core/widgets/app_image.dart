import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// Cached network image with a tonal placeholder and a quiet error state so a
/// failed photo never blocks the page.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.aspectRatio,
    this.radius = AppRadii.card,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.width,
    this.height,
  });

  final String? url;
  final double? aspectRatio;
  final double radius;
  final BoxFit fit;
  final String? semanticLabel;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget fallback(IconData icon) => Container(
          color: const Color(0xFFEFE9DF),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.mutedText, size: 28),
        );

    Widget image = (url == null || url!.isEmpty)
        ? fallback(Icons.photo_outlined)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => const ColoredBox(color: Color(0xFFEFE9DF)),
            errorWidget: (_, __, ___) => fallback(Icons.broken_image_outlined),
          );

    if (aspectRatio != null) image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: image),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.radius = 24});
  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.first.isEmpty ? '?' : parts.first[0]) +
        (parts.length > 1 ? parts.last[0] : '');
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.ink,
      foregroundImage: (url == null || url!.isEmpty) ? null : CachedNetworkImageProvider(url!),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: AppColors.paper,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
