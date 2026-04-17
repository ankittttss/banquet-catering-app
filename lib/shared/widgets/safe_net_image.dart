import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network image that works reliably on Flutter web (Unsplash + many other
/// hosts don't send CORS headers, which breaks CachedNetworkImage's fetch).
/// Uses the browser's native `<img>` via [Image.network] on web and
/// [CachedNetworkImage] on native for real caching.
class SafeNetImage extends StatelessWidget {
  const SafeNetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? placeholder;

  @override
  Widget build(BuildContext context) {
    final error = errorBuilder ?? (_) => const SizedBox.shrink();
    final place = placeholder ?? (_) => const SizedBox.shrink();

    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (ctx, _, __) => error(ctx),
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : place(ctx),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      errorWidget: (ctx, _, __) => error(ctx),
      placeholder: (ctx, _) => place(ctx),
    );
  }
}
