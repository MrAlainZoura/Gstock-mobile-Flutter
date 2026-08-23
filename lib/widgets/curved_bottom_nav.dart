import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class CurvedNavItem {
  const CurvedNavItem({
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool enabled;
}

/// Barre courbe : l’onglet actif flotte au-dessus d’une encoche arrondie animée.
class CurvedBottomNav extends StatefulWidget {
  const CurvedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedNavItem> items;

  @override
  State<CurvedBottomNav> createState() => _CurvedBottomNavState();
}

class _CurvedBottomNavState extends State<CurvedBottomNav>
    with SingleTickerProviderStateMixin {
  static const _fabSize = 58.0;
  static const _notchRadius = 36.0;
  static const _barHeight = 64.0;
  static const _animDuration = Duration(milliseconds: 420);

  late AnimationController _controller;
  late Animation<double> _curve;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.currentIndex.toDouble();
    _from = _to;
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(covariant CurvedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.currentIndex
        .clamp(0, math.max(0, widget.items.length - 1))
        .toDouble();
    if (next != _to || oldWidget.items.length != widget.items.length) {
      _from = _animatedIndex;
      _to = next;
      _controller.forward(from: 0);
    }
  }

  double get _animatedIndex {
    if (!_controller.isAnimating &&
        _controller.status != AnimationStatus.forward) {
      return _to;
    }
    return _from + (_to - _from) * _curve.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final selected = widget.currentIndex.clamp(0, count - 1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _animatedIndex;
        return SizedBox(
          width: double.infinity,
          height: _barHeight + _fabSize / 2 + bottom,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cx = constraints.maxWidth / count * (t + 0.5);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight + bottom,
                    child: CustomPaint(
                      painter: _NotchBarPainter(
                        index: t,
                        itemCount: count,
                        color: AppColors.black,
                        notchRadius: _notchRadius,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottom),
                        child: Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: _BarItem(
                                  item: widget.items[i],
                                  selected: i == selected,
                                  onTap: widget.items[i].enabled
                                      ? () => widget.onTap(i)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: cx - _fabSize / 2,
                    top: 0,
                    child: IgnorePointer(
                      child: _FloatingTab(item: widget.items[selected]),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CurvedNavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: selected ? 0 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: item.enabled
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: item.enabled
                    ? AppColors.white
                    : AppColors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingTab extends StatelessWidget {
  const _FloatingTab({required this.item});

  final CurvedNavItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _CurvedBottomNavState._fabSize,
      height: _CurvedBottomNavState._fabSize,
      decoration: BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.white, width: 3),
      ),
      child: Icon(item.icon, color: AppColors.white, size: 26),
    );
  }
}

class _NotchBarPainter extends CustomPainter {
  _NotchBarPainter({
    required this.index,
    required this.itemCount,
    required this.color,
    required this.notchRadius,
  });

  final double index;
  final int itemCount;
  final Color color;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = notchRadius;
    final cx = (size.width / itemCount * (index + 0.5))
        .clamp(r + 4, size.width - r - 4);
    const corner = 22.0;
    final path = Path();

    path.moveTo(0, corner);
    path.quadraticBezierTo(0, 0, corner, 0);
    path.lineTo(cx - r, 0);
    path.arcToPoint(
      Offset(cx + r, 0),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(size.width - corner, 0);
    path.quadraticBezierTo(size.width, 0, size.width, corner);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path, AppColors.black.withValues(alpha: 0.45), 10, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NotchBarPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.color != color;
  }
}
