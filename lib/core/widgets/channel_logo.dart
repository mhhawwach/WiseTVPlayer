import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../utils/image_cache_manager.dart';

/// Fast-loading channel/movie logo with shimmer placeholder.
/// Constrains memory by capping decode width to [AppConstants.imageCacheWidth].
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    super.key,
    required this.url,
    this.width = 80,
    this.height = 54,
    this.radius = 8.0,
    this.fit = BoxFit.contain,
  });

  final String url;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? _placeholder()
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: fit,
              memCacheWidth: AppConstants.imageCacheWidth,
              cacheManager: AppImageCacheManager(),
              placeholder: (_, __) => _shimmer(),
              errorWidget: (_, __, ___) => _placeholder(),
            ),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          width: width,
          height: height,
          color: AppColors.shimmerBase,
        ),
      );

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.tv, color: AppColors.textMuted, size: 24),
      );
}
