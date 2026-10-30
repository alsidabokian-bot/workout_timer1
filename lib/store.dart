import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timer_engine.dart';

/// إعدادات التطبيق المحفوظة على الجهاز.
/// تُستدعى `init()` مرة واحدة في `main()` قبل تشغيل التطبيق.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  // حدود القيم المسموحة
  static const int minWork = 5;
  static const int maxWork = 3600;
  static const int minRest = 0;
  static const int maxRest = 600;
  static const int minRounds = 1;
  static const int maxRounds = 99;

  // القيم الافتراضية
  static const int defaultWork = 30;
  static const int defaultRest = 10;
  static const int defaultRounds = 5;

  static const _kWork = 'work_seconds';
  static const _kRest = 'rest_seconds';
  static const _kRounds = 'rounds';
  static const _kSound = 'sound_enabled';
  static const _kVibration = 'vibration_enabled';
  static const _kTheme = 'theme_mode';

  SharedPreferences? _prefs;

  int _workSeconds = defaultWork;
  int _restSeconds = defaultRest;
  int _rounds = defaultRounds;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;

  int get workSeconds => _workSeconds;
  int get restSeconds => _restSeconds;
  int get rounds => _rounds;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  ThemeMode get themeMode => _themeMode;

  /// الإعدادات الحالية بصيغة جاهزة للمؤقت.
  WorkoutConfig get config => WorkoutConfig(
        workSeconds: _workSeconds,
        restSeconds: _restSeconds,
        rounds: _rounds,
      );

  /// مدة التمرين الكلية بالثواني (لعرضها في شاشة الضبط).
  int get totalSeconds =>
      _rounds * _workSeconds + (_rounds - 1) * _restSeconds;

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      _workSeconds =
          _clamp(p.getInt(_kWork) ?? defaultWork, minWork, maxWork);
      _restSeconds =
          _clamp(p.getInt(_kRest) ?? defaultRest, minRest, maxRest);
      _rounds =
          _clamp(p.getInt(_kRounds) ?? defaultRounds, minRounds, maxRounds);
      _soundEnabled = p.getBool(_kSound) ?? true;
      _vibrationEnabled = p.getBool(_kVibration) ?? true;
      _themeMode = _decodeTheme(p.getString(_kTheme));
    } catch (_) {
      // إن تعذّرت القراءة نستخدم القيم الافتراضية ولا يتوقف التطبيق.
    }
  }

  void setWorkSeconds(int value) {
    _workSeconds = _clamp(value, minWork, maxWork);
    _prefs?.setInt(_kWork, _workSeconds);
    notifyListeners();
  }

  void setRestSeconds(int value) {
    _restSeconds = _clamp(value, minRest, maxRest);
    _prefs?.setInt(_kRest, _restSeconds);
    notifyListeners();
  }

  void setRounds(int value) {
    _rounds = _clamp(value, minRounds, maxRounds);
    _prefs?.setInt(_kRounds, _rounds);
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    _prefs?.setBool(_kSound, value);
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    _vibrationEnabled = value;
    _prefs?.setBool(_kVibration, value);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs?.setString(_kTheme, mode.name);
    notifyListeners();
  }

  /// إعادة أوقات التمرين إلى القيم الافتراضية (لا تمس الصوت والمظهر).
  void resetTimes() {
    setWorkSeconds(defaultWork);
    setRestSeconds(defaultRest);
    setRounds(defaultRounds);
  }

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  static ThemeMode _decodeTheme(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
