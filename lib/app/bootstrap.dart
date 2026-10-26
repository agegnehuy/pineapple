import 'package:flutter/widgets.dart';
import 'package:myoccasio/app/app.dart';
import 'package:myoccasio/app/app_dependencies.dart';
import 'package:myoccasio/app/config/app_config.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final dependencies = AppDependencies.production(config);
  runApp(MyOccasioApp(dependencies: dependencies));
}
