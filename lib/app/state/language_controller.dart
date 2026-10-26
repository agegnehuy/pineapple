import 'package:flutter/foundation.dart';

class LanguageController extends ChangeNotifier {
  LanguageController({this.read, this.write});
  final Future<String?> Function()? read;
  final Future<void> Function(String)? write;
  String _code = 'en';
  String get code => _code;
  bool _changed = false;
  Future<void> initialize() async {
    try {
      final saved = await read?.call();
      if (_changed || !const {'en', 'fr'}.contains(saved)) return;
      _code = saved!;
      notifyListeners();
    } on Object {
      // Display preferences must not prevent account access.
    }
  }

  Future<void> setLanguage(String value) async {
    if (!const {'en', 'fr'}.contains(value)) throw ArgumentError.value(value);
    _changed = true;
    await write?.call(value);
    _code = value;
    notifyListeners();
  }
}
