import 'package:flutter/material.dart';
import 'screens/main_navigation_screen.dart';
import 'state/plan_notifier.dart';
import 'state/plan_scope.dart';
import 'theme/app_theme.dart';

class PlanApp extends StatefulWidget {
  final PlanNotifier? notifier;

  const PlanApp({super.key, this.notifier});

  @override
  State<PlanApp> createState() => _PlanAppState();
}

class _PlanAppState extends State<PlanApp> {
  late final PlanNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = widget.notifier ?? PlanNotifier();
    _notifier.initialize();
  }

  @override
  void dispose() {
    if (widget.notifier == null) {
      _notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlanScope(
      notifier: _notifier,
      child: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'Plan',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _notifier.appSettings.themeMode,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
