import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification background channels/settings (does NOT ask for permissions yet)
  await NotificationService().initialize();

  runApp(const PlanApp());
}
