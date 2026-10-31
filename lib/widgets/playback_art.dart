import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../config/app_brand.dart';

class PlaybackArt extends StatefulWidget {
  const PlaybackArt({super.key, required this.playing, this.size = 220});
  final bool playing;
  final double size;
  @override
  State<PlaybackArt> createState() => _PlaybackArtState();
}

class _PlaybackArtState extends State<PlaybackArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  void _update() {
    if (widget.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_animation.isAnimating) _animation.repeat(reverse: true);
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant PlaybackArt old) {
    super.didUpdateWidget(old);
    _update();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.playing ? 'Hymn playing' : 'Hymn artwork',
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(
                alpha: .12 + .12 * _animation.value,
              ),
              blurRadius: 14 + 14 * _animation.value,
              spreadRadius: 2 + 3 * _animation.value,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size * .67,
              height: widget.size * .67,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .15),
                  width: 1,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                AppBrand.logo,
                width: widget.size * .9,
                height: widget.size * .9,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
