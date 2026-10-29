import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plan/app.dart';
import 'package:plan/database/database_helper.dart';
import 'package:plan/repositories/settings_repository.dart';
import 'package:plan/repositories/task_repository.dart';
import 'package:plan/repositories/time_entry_repository.dart';
import 'package:plan/state/plan_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseHelper dbHelper;
  late TaskRepository taskRepository;
  late TimeEntryRepository timeEntryRepository;
  late SettingsRepository settingsRepository;
  late PlanNotifier notifier;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper();
    dbHelper.setDatabaseForTesting(db);
    await dbHelper.createSchemaForTesting(db);

    taskRepository = TaskRepository(databaseHelper: dbHelper);
    timeEntryRepository = TimeEntryRepository(databaseHelper: dbHelper);
    settingsRepository = SettingsRepository(databaseHelper: dbHelper);

    notifier = PlanNotifier(
      taskRepository: taskRepository,
      timeEntryRepository: timeEntryRepository,
      settingsRepository: settingsRepository,
    );

    await notifier.initialize();
  });

  tearDown(() async {
    notifier.dispose();
    await db.close();
  });

  void setTestPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 4),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final stop = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(stop)) {
      await tester.runAsync(() => Future.delayed(step));
      await tester.pump();
    }
  }

  testWidgets('Fresh install shows clean Today empty state', (tester) async {
    setTestPhoneSize(tester);
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No tasks for today.'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Today'), findsOneWidget);
  });

  testWidgets('Task creation, completion toggle, and editing flow', (tester) async {
    setTestPhoneSize(tester);
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Add task
    await tester.tap(find.text('Add task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Type task name in editor dialog
    final inputFinder = find.byType(TextField).first;
    await tester.enterText(inputFinder, 'Read research paper');
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Add button
    final addButton = find.widgetWithText(ElevatedButton, 'Add');
    await tester.tap(addButton);
    await tester.pump();
    await pumpUntil(tester, () => notifier.todayTasks.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify task is now shown on Today screen
    expect(find.text('Read research paper'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Toggle checkbox to complete
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await pumpUntil(tester, () => notifier.todayTasks.first.isCompleted);
    await tester.pump(const Duration(milliseconds: 300));

    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, true);

    // Toggle checkbox back to incomplete
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await pumpUntil(tester, () => !notifier.todayTasks.first.isCompleted);
    await tester.pump(const Duration(milliseconds: 300));

    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Tapping the task title text directly also ticks it
    await tester.tap(find.text('Read research paper'));
    await tester.pump();
    await pumpUntil(tester, () => notifier.todayTasks.first.isCompleted);
    await tester.pump(const Duration(milliseconds: 300));
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, true);

    // Untick it by tapping text again
    await tester.tap(find.text('Read research paper'));
    await tester.pump();
    await pumpUntil(tester, () => !notifier.todayTasks.first.isCompleted);
    await tester.pump(const Duration(milliseconds: 300));
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Tap dedicated edit icon on the side to open edit section
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Edit Task'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Read updated paper');
    final saveButton = find.widgetWithText(ElevatedButton, 'Save');
    await tester.tap(saveButton);
    await tester.pump();
    await pumpUntil(tester, () => notifier.todayTasks.first.title == 'Read updated paper');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Read updated paper'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Time tracking tab and entry creation', (tester) async {
    setTestPhoneSize(tester);
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Time tab using bottom nav destination
    await tester.tap(find.widgetWithText(NavigationDestination, 'Time'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No time entries for this date.'), findsOneWidget);

    // Tap Log Time button
    await tester.tap(find.text('Log Time'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Log Time'), findsWidgets);

    // Enter Activity Title (second field)
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), 'Flutter Development');
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Log Time submit button
    final submitButton = find.widgetWithText(ElevatedButton, 'Log Time');
    await tester.tap(submitButton);
    await tester.pump();
    await pumpUntil(tester, () => notifier.selectedDateTimeEntries.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Flutter Development'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Calendar navigation and view mode toggle', (tester) async {
    setTestPhoneSize(tester);
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Calendar tab using bottom nav destination
    await tester.tap(find.widgetWithText(NavigationDestination, 'Calendar'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No tasks planned for this date.'), findsOneWidget);

    // Toggle to Day Timeline view mode
    await tester.tap(find.byIcon(Icons.view_day_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify hour slots e.g. 08:00 are rendered
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);

    // Switch back to Today tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No tasks for today.'), findsOneWidget);
  });
}
