import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Base fill
        Positioned.fill(
          child: isDark
              ? const ColoredBox(color: AppColors.darkBg)
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.lightBgStart,
                        AppColors.lightBgMid,
                        AppColors.lightBgEnd,
                      ],
                    ),
                  ),
                ),
        ),

        // Grid overlay (dark only)
        if (isDark)
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

        // Animated orbs
        Positioned(
          top: -size.height * 0.1,
          left: -size.width * 0.2,
          child: _Orb(
            width: size.width * 0.8,
            height: size.width * 0.8,
            color: isDark
                ? AppColors.primaryEnd.withValues(alpha: 0.15)
                : AppColors.primaryEnd.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.05,
          right: -size.width * 0.15,
          child: _Orb(
            width: size.width * 0.7,
            height: size.width * 0.7,
            color: isDark
                ? AppColors.primaryStart.withValues(alpha: 0.08)
                : AppColors.primaryStart.withValues(alpha: 0.05),
          ),
        ),

        // Diagonal wash (dark only)
        if (isDark)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Content
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Orb extends StatefulWidget {
  const _Orb({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [widget.color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 0.5;

    const spacing = 50.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
