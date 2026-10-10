import 'package:flutter/widgets.dart';
import 'plan_notifier.dart';

class PlanScope extends InheritedNotifier<PlanNotifier> {
  const PlanScope({
    super.key,
    required PlanNotifier super.notifier,
    required super.child,
  });

  static PlanNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlanScope>();
    assert(scope != null, 'No PlanScope found in context');
    return scope!.notifier!;
  }

  static PlanNotifier read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PlanScope>();
    assert(scope != null, 'No PlanScope found in context');
    return scope!.notifier!;
  }
}
