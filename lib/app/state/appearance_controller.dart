import 'package:flutter/material.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({this.read, this.write});
  final Future<String?> Function()? read;
  final Future<void> Function(String)? write;
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool _changed = false;
  Future<void> initialize() async {
    try {
      final saved = await read?.call();
      if (_changed || saved == null) return;
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
      notifyListeners();
    } on Object {
      // A storage read failure must not prevent authentication or app startup.
    }
  }

  Future<void> setMode(ThemeMode value) async {
    _changed = true;
    await write?.call(value.name);
    _mode = value;
    notifyListeners();
  }
}
