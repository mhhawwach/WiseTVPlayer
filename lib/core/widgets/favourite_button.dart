import 'package:flutter/material.dart';

import '../storage/storage_service.dart';

/// A D-pad-reachable Favourite toggle for detail screens. Works on every remote
/// (no coloured button required), reflects current state, and persists via
/// [StorageService]. Stores the same map shape the Favourites screen reads.
class FavouriteButton extends StatefulWidget {
  const FavouriteButton({
    super.key,
    required this.type, // 'vod' | 'series' | 'live'
    required this.id,
    required this.name,
    required this.icon,
    this.ext,
    this.width,
    this.autofocus = false,
  });

  final String type;
  final int id;
  final String name;
  final String icon;
  final String? ext;
  final double? width;
  final bool autofocus;

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  late bool _fav = StorageService.isFavourite(widget.type, widget.id);

  void _toggle() {
    StorageService.toggleFavourite(widget.type, widget.id, {
      'type': widget.type,
      'id': widget.id,
      'name': widget.name,
      'icon': widget.icon,
      if (widget.ext != null && widget.ext!.isNotEmpty) 'ext': widget.ext,
    });
    final nowFav = StorageService.isFavourite(widget.type, widget.id);
    setState(() => _fav = nowFav);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content:
            Text(nowFav ? '★ Added to Favourites' : 'Removed from Favourites'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: _toggle,
      autofocus: widget.autofocus,
      icon: Icon(
        _fav ? Icons.star_rounded : Icons.star_border_rounded,
        size: 20,
        color: _fav ? const Color(0xFFFBC02D) : null,
      ),
      label: Text(_fav ? 'Favourited' : 'Favourite'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
    return widget.width != null ? SizedBox(width: widget.width, child: btn) : btn;
  }
}
