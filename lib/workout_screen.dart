import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app_background.dart';
import 'format.dart';
import 'sound_service.dart';
import 'store.dart';
import 'timer_engine.dart';

/// شاشة التمرين: دائرة العدّ التنازلي وأزرار التحكم.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final WorkoutEngine _engine = WorkoutEngine();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    WakelockPlus.enable().catchError((_) {}); // إبقاء الشاشة مضاءة
    // نربط الصوت قبل البدء حتى لا تضيع نغمة البداية
    await SoundService.instance.attach(_engine);
    if (!mounted) return;
    _engine.start(AppStore.instance.config);
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    SoundService.instance.detach();
    _engine.dispose();
    super.dispose();
  }

  // ---------- الألوان والنصوص حسب المرحلة ----------

  List<Color> _colors(WorkoutPhase p) {
    switch (p) {
      case WorkoutPhase.rest:
        return const [Color(0xFFFF8A65), Color(0xFFFF6F43)];
      case WorkoutPhase.finished:
        return const [Color(0xFF2EC4A6), Color(0xFF1FA88C)];
      default:
        return const [Color(0xFF5B6BF5), Color(0xFF7C5BFF)];
    }
  }

  String _title(WorkoutPhase p) {
    switch (p) {
      case WorkoutPhase.rest:
        return 'راحة';
      case WorkoutPhase.finished:
        return 'أحسنت! انتهى التمرين';
      default:
        return 'تمرين';
    }
  }

  // ---------- الحوارات والخروج ----------

  /// يوقف المؤقت أثناء السؤال، ويستأنفه إن اختار المستخدم المتابعة.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String ok,
  }) async {
    final wasRunning = _engine.isRunning;
    _engine.pause();
    final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('متابعة التمرين'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ok),
              ),
            ],
          ),
        ) ??
        false;
    if (!result && wasRunning && mounted) _engine.resume();
    return result;
  }

  Future<void> _onClose() async {
    if (_engine.isFinished) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await _confirm(
      title: 'إنهاء التمرين؟',
      body: 'سيتوقف العدّاد وتعود إلى شاشة الضبط.',
      ok: 'إنهاء',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _onRestart() async {
    final ok = await _confirm(
      title: 'إعادة التمرين؟',
      body: 'سيبدأ التمرين من الجولة الأولى.',
      ok: 'إعادة',
    );
    if (ok && mounted) _engine.start(AppStore.instance.config);
  }

  // ---------- الواجهة ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        final e = _engine;
        return PopScope(
          canPop: e.isFinished || e.isIdle,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onClose();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: BackgroundScaffold(
              dim: 0,
              body: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    // لون المرحلة شبه شفاف فوق الصورة
                    colors: [
                      for (final c in _colors(e.phase)) c.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      children: [
                        _header(e),
                        Expanded(child: _ring(e)),
                        _footerInfo(e),
                        const SizedBox(height: 24),
                        _controls(e),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(WorkoutEngine e) {
    final cfg = AppStore.instance.config;
    final pillText = e.isFinished
        ? '${cfg.rounds} جولات'
        : 'الجولة ${e.isIdle ? 1 : e.round} / ${cfg.rounds}';
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pillText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // لموازنة زر الإغلاق وتوسيط الشارة
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _title(e.phase),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _ring(WorkoutEngine e) {
    final cfg = AppStore.instance.config;
    final secs = e.isIdle ? cfg.workSeconds : e.remainingSeconds;
    // الدائرة ممتلئة عند بداية المرحلة وتفرغ مع مرور الوقت
    final fraction = (e.isIdle || e.isFinished) ? 1.0 : 1 - e.progress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          340.0,
        );
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(fraction: fraction, stroke: size * 0.045),
              child: Center(
                child: e.isFinished
                    ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.45)
                    : Padding(
                        padding: EdgeInsets.all(size * 0.14),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            secs >= 60 ? formatTime(secs) : '$secs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footerInfo(WorkoutEngine e) {
    final store = AppStore.instance;
    final text = e.isFinished
        ? 'المدة الكلية ${formatTime(store.totalSeconds)}'
        : 'المتبقي للتمرين  ${formatTime(e.isIdle ? store.totalSeconds : e.totalRemainingSeconds)}';
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _controls(WorkoutEngine e) {
    if (e.isFinished) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PillButton(
            label: 'رجوع',
            icon: Icons.arrow_forward_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          _PillButton(
            label: 'إعادة',
            icon: Icons.replay_rounded,
            filled: true,
            onTap: () => _engine.start(AppStore.instance.config),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(icon: Icons.replay_rounded, size: 64, onTap: _onRestart),
        _CircleButton(
          icon: e.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 92,
          filled: true,
          onTap: e.isIdle ? null : _engine.toggle,
        ),
        // في الواجهة العربية "التالي" يشير لليسار
        _CircleButton(
          icon: Icons.skip_previous_rounded,
          size: 64,
          onTap: e.isIdle ? null : _engine.skip,
        ),
      ],
    );
  }
}

/// ترسم حلقة العدّ: مسار خافت وقوس أبيض يمثل الوقت المتبقي.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.stroke});

  final double fraction; // الجزء المتبقي من 0 إلى 1
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rect.center, rect.width / 2, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.stroke != stroke;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.2),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.5,
              color: filled ? const Color(0xFF3B3F6B) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? const Color(0xFF1B6F5F) : Colors.white;
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
