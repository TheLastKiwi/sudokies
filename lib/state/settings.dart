import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-toggleable settings, persisted to shared_preferences.
class Settings extends ChangeNotifier {
  static const _kAutoPrune = 'set_auto_prune';
  static const _kFlagMistakes = 'set_flag_mistakes';
  static const _kShowTimer = 'set_show_timer';

  final SharedPreferences _prefs;

  bool _autoPrune;
  bool _flagMistakes;
  bool _showTimer;

  Settings(this._prefs)
      : _autoPrune = _prefs.getBool(_kAutoPrune) ?? false,
        _flagMistakes = _prefs.getBool(_kFlagMistakes) ?? false,
        _showTimer = _prefs.getBool(_kShowTimer) ?? true;

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings(prefs);
  }

  bool get autoPrune => _autoPrune;
  bool get flagMistakes => _flagMistakes;
  bool get showTimer => _showTimer;

  set autoPrune(bool v) {
    _autoPrune = v;
    _prefs.setBool(_kAutoPrune, v);
    notifyListeners();
  }

  set flagMistakes(bool v) {
    _flagMistakes = v;
    _prefs.setBool(_kFlagMistakes, v);
    notifyListeners();
  }

  set showTimer(bool v) {
    _showTimer = v;
    _prefs.setBool(_kShowTimer, v);
    notifyListeners();
  }
}
