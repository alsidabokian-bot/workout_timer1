import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'timer_engine.dart';

/// يشغّل صفير العدّ الأخير ونغمات البداية والنهاية، مع اهتزاز اختياري.
/// يلتزم بخياري الصوت والاهتزاز في [AppStore] لحظة كل حدث.
///
/// الاستخدام: `SoundService.instance.attach(engine)` عند فتح شاشة التمرين،
/// و`detach()` عند إغلاقها.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  // اسم الملف داخل assets/sounds/ لكل نغمة
  static const _beep = 'beep.wav';
  static const _go = 'go.wav';
  static const _rest = 'rest.wav';
  static const _finish = 'finish.wav';

  final Map<String, AudioPlayer> _players = {};
  StreamSubscription<EngineEvent>? _sub;
  bool _ready = false;
  bool _disposed = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      final context = AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          // يخفض صوت الموسيقى لحظة التنبيه ثم يعيده، دون إيقافها
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      );
      for (final file in [_beep, _go, _rest, _finish]) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setAudioContext(context);
        await player.setSource(AssetSource('sounds/$file'));
        _players[file] = player;
      }
      _ready = true;
    } catch (_) {
      // فشل تهيئة الصوت لا يوقف التمرين؛ يبقى المؤقت والاهتزاز يعملان.
    }
  }

  /// يبدأ الاستماع لأحداث المؤقت.
  Future<void> attach(WorkoutEngine engine) async {
    await init();
    await _sub?.cancel();
    _sub = engine.events.listen(_onEvent);
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// معاينة نغمة البداية والاهتزاز (لزر التجربة في الإعدادات).
  Future<void> preview() async {
    await init(); // قد تُفتح الإعدادات قبل أي تمرين فلا تكون النغمات محمّلة بعد
    _onEvent(const EngineEvent(EngineEventType.workStart));
  }

  void _onEvent(EngineEvent e) {
    switch (e.type) {
      case EngineEventType.countdown:
        _play(_beep);
        _haptic(HapticFeedback.lightImpact);
        break;
      case EngineEventType.workStart:
        _play(_go);
        _haptic(HapticFeedback.heavyImpact);
        break;
      case EngineEventType.restStart:
        _play(_rest);
        _haptic(HapticFeedback.mediumImpact);
        break;
      case EngineEventType.finished:
        _play(_finish);
        _finishHaptics();
        break;
    }
  }

  void _play(String file) {
    if (!AppStore.instance.soundEnabled || !_ready) return;
    final player = _players[file];
    if (player == null) return;
    // play يعيد النغمة من البداية في كل مرة، ولا ننتظره حتى لا يتأخر العدّ
    player.play(AssetSource('sounds/$file')).catchError((_) {});
  }

  void _haptic(Future<void> Function() action) {
    if (!AppStore.instance.vibrationEnabled) return;
    action().catchError((_) {});
  }

  /// ثلاث نبضات قوية عند انتهاء التمرين.
  Future<void> _finishHaptics() async {
    for (var i = 0; i < 3; i++) {
      if (_disposed || !AppStore.instance.vibrationEnabled) return;
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await detach();
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
