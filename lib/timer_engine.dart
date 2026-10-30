import 'dart:async';
import 'package:flutter/widgets.dart';

/// مراحل التمرين.
enum WorkoutPhase { idle, work, rest, finished }

/// أحداث يرسلها المؤقت لتشغيل الأصوات (المرحلة 3).
enum EngineEventType { workStart, restStart, countdown, finished }

class EngineEvent {
  const EngineEvent(this.type, [this.second = 0]);
  final EngineEventType type;

  /// للحدث `countdown` فقط: الرقم المعروض (3 أو 2 أو 1).
  final int second;
}

class WorkoutConfig {
  const WorkoutConfig({
    required this.workSeconds,
    required this.restSeconds,
    required this.rounds,
  });

  final int workSeconds;
  final int restSeconds;
  final int rounds;
}

/// محرك المؤقت: تمرين ← راحة ← تمرين ... حسب عدد الجولات.
///
/// الوقت المتبقي يُحسب من ساعة الجهاز (وقت انتهاء المرحلة) وليس من عدّاد
/// داخلي، فيبقى دقيقًا حتى لو توقف التطبيق في الخلفية، ويُصحَّح تلقائيًا
/// عند العودة إليه.
class WorkoutEngine extends ChangeNotifier with WidgetsBindingObserver {
  WorkoutEngine({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  WorkoutConfig _config = const WorkoutConfig(
    workSeconds: 30,
    restSeconds: 10,
    rounds: 5,
  );
  WorkoutPhase _phase = WorkoutPhase.idle;
  int _round = 1;
  bool _running = false;
  int _phaseTotalMs = 0;
  int _pausedRemainingMs = 0; // يُستخدم أثناء الإيقاف المؤقت فقط
  DateTime? _phaseEnd; // يُستخدم أثناء العمل فقط
  int _lastBeepSecond = -1;
  Timer? _ticker;
  bool _observing = false;

  // ---------- الحالة ----------

  Stream<EngineEvent> get events => _events.stream;
  WorkoutPhase get phase => _phase;
  int get round => _round;
  int get totalRounds => _config.rounds;
  bool get isRunning => _running;
  bool get isIdle => _phase == WorkoutPhase.idle;
  bool get isFinished => _phase == WorkoutPhase.finished;
  bool get isPaused => !_running && _inPhase;

  bool get _inPhase =>
      _phase == WorkoutPhase.work || _phase == WorkoutPhase.rest;

  /// الوقت المتبقي في المرحلة الحالية بالملّي ثانية.
  int get remainingMs {
    if (_running && _phaseEnd != null) {
      final ms = _phaseEnd!.difference(_clock()).inMilliseconds;
      return ms < 0 ? 0 : (ms > _phaseTotalMs ? _phaseTotalMs : ms);
    }
    return _pausedRemainingMs;
  }

  /// الرقم المعروض على العدّاد (يُقرَّب للأعلى: 3 ثم 2 ثم 1).
  int get remainingSeconds => (remainingMs / 1000).ceil();

  /// تقدّم المرحلة الحالية من 0 إلى 1 (لرسم الدائرة).
  double get progress {
    if (_phaseTotalMs == 0) return 0;
    return 1 - remainingMs / _phaseTotalMs;
  }

  /// الوقت المتبقي للتمرين كله بالثواني.
  int get totalRemainingSeconds {
    if (!_inPhase) return 0;
    final left = _config.rounds - _round;
    final future = _phase == WorkoutPhase.work
        ? left * (_config.workSeconds + _config.restSeconds)
        : left * _config.workSeconds +
            (left - 1) * _config.restSeconds;
    return remainingSeconds + future;
  }

  // ---------- التحكم ----------

  /// يبدأ تمرينًا جديدًا من الجولة الأولى.
  void start(WorkoutConfig config) {
    _config = WorkoutConfig(
      workSeconds: config.workSeconds < 1 ? 1 : config.workSeconds,
      restSeconds: config.restSeconds < 0 ? 0 : config.restSeconds,
      rounds: config.rounds < 1 ? 1 : config.rounds,
    );
    _round = 1;
    _setPhase(WorkoutPhase.work);
    _running = true;
    _phaseEnd = _clock().add(Duration(milliseconds: _phaseTotalMs));
    _pausedRemainingMs = _phaseTotalMs;
    _startTicker();
    _emitPhaseStart();
    notifyListeners();
  }

  void pause() {
    if (!_running) return;
    _pausedRemainingMs = remainingMs;
    _running = false;
    _phaseEnd = null;
    _stopTicker();
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    _running = true;
    _phaseEnd = _clock().add(Duration(milliseconds: _pausedRemainingMs));
    _startTicker();
    notifyListeners();
  }

  void toggle() => _running ? pause() : resume();

  /// ينتقل فورًا إلى المرحلة التالية (من تمرين إلى راحة وهكذا).
  void skip() {
    if (!_inPhase) return;
    final wasRunning = _running;
    if (!_advance()) {
      _finish();
      return;
    }
    _pausedRemainingMs = _phaseTotalMs;
    if (wasRunning) {
      _phaseEnd = _clock().add(Duration(milliseconds: _phaseTotalMs));
      _emitPhaseStart();
    }
    notifyListeners();
  }

  /// يوقف التمرين ويعيد المؤقت للحالة الابتدائية.
  void reset() {
    _stopTicker();
    _running = false;
    _phase = WorkoutPhase.idle;
    _round = 1;
    _phaseTotalMs = 0;
    _pausedRemainingMs = 0;
    _phaseEnd = null;
    _lastBeepSecond = -1;
    notifyListeners();
  }

  // ---------- المنطق الداخلي ----------

  void _setPhase(WorkoutPhase p) {
    _phase = p;
    final seconds =
        p == WorkoutPhase.work ? _config.workSeconds : _config.restSeconds;
    _phaseTotalMs = seconds * 1000;
    _lastBeepSecond = -1;
  }

  /// ينتقل للمرحلة التالية. يُرجع false إذا انتهى التمرين.
  bool _advance() {
    if (_phase == WorkoutPhase.work) {
      if (_round >= _config.rounds) return false; // لا راحة بعد آخر جولة
      if (_config.restSeconds > 0) {
        _setPhase(WorkoutPhase.rest);
        return true;
      }
      _round++;
      _setPhase(WorkoutPhase.work);
      return true;
    }
    _round++;
    _setPhase(WorkoutPhase.work);
    return true;
  }

  void _tick() {
    if (!_running || _phaseEnd == null) return;
    final now = _clock();
    var end = _phaseEnd!;

    if (now.isBefore(end)) {
      _checkBeep(end.difference(now).inMilliseconds);
      notifyListeners();
      return;
    }

    // انتهت المرحلة. قد تنتهي أكثر من مرحلة إذا غاب التطبيق طويلًا،
    // فنتقدم حتى نصل للمرحلة الصحيحة ونرسل صوت بدايتها فقط.
    var advanced = false;
    while (!now.isBefore(end)) {
      if (!_advance()) {
        _finish();
        return;
      }
      end = end.add(Duration(milliseconds: _phaseTotalMs));
      advanced = true;
    }
    _phaseEnd = end;
    if (advanced) _emitPhaseStart();
    _checkBeep(end.difference(now).inMilliseconds);
    notifyListeners();
  }

  /// صفير في آخر 3 ثوانٍ، مرة واحدة لكل ثانية.
  /// لا يصفّر عند بداية مرحلة قصيرة حتى لا يتكرر مع نغمة البداية.
  void _checkBeep(int remainingMs) {
    final sec = (remainingMs / 1000).ceil();
    if (sec >= 1 &&
        sec <= 3 &&
        sec * 1000 < _phaseTotalMs &&
        sec != _lastBeepSecond) {
      _lastBeepSecond = sec;
      _events.add(EngineEvent(EngineEventType.countdown, sec));
    }
  }

  void _emitPhaseStart() {
    _events.add(EngineEvent(
      _phase == WorkoutPhase.work
          ? EngineEventType.workStart
          : EngineEventType.restStart,
    ));
  }

  void _finish() {
    _stopTicker();
    _running = false;
    _phase = WorkoutPhase.finished;
    _pausedRemainingMs = 0;
    _phaseEnd = null;
    _events.add(const EngineEvent(EngineEventType.finished));
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// عند عودة التطبيق من الخلفية نصحّح الوقت فورًا.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    _stopTicker();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _events.close();
    super.dispose();
  }
}
