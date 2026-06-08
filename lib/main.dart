import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await Services.create();
  runApp(SudokiesApp(services: services));
}
