import 'package:flutter/material.dart';
import 'theme.dart';

/// خلفية التطبيق: الصورة مع طبقة تعتيم لتبقى النصوص واضحة.
/// [dim] من 0 (بلا تعتيم) إلى 1 (أسود كامل).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.dim = 0.6});

  final Widget child;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.bgDark),
        Image.asset(
          'assets/images/bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
        child,
      ],
    );
  }
}

/// Scaffold شفاف فوق خلفية التطبيق.
class BackgroundScaffold extends StatelessWidget {
  const BackgroundScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.dim = 0.6,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      dim: dim,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
