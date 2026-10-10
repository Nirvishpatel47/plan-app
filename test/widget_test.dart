import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plan/app.dart';
import 'package:plan/database/database_helper.dart';
import 'package:plan/models/task.dart';
import 'package:plan/repositories/task_repository.dart';
import 'package:plan/state/plan_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseHelper dbHelper;
  late TaskRepository repository;
  late PlanNotifier notifier;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_date ON tasks(date)');

    dbHelper = DatabaseHelper();
    dbHelper.setDatabaseForTesting(db);
    repository = TaskRepository(databaseHelper: dbHelper);
    notifier = PlanNotifier(repository: repository);
  });

  tearDown(() async {
    notifier.dispose();
    await db.close();
  });

  testWidgets('Fresh install shows clean Today empty state', (tester) async {
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No tasks for today.'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets('Task creation, completion toggle, and editing flow', (tester) async {
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pumpAndSettle();

    // Tap Add task
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    // Type task name in editor dialog
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'Read research paper');
    await tester.pump();

    // Tap Add button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    // Verify task is now shown on Today screen
    expect(find.text('Read research paper'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Toggle checkbox to complete
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, true);

    // Toggle checkbox back to incomplete
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Tapping the task title text directly also ticks it
    await tester.tap(find.text('Read research paper'));
    await tester.pumpAndSettle();
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, true);

    // Untick it by tapping text again
    await tester.tap(find.text('Read research paper'));
    await tester.pumpAndSettle();
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, false);

    // Tap dedicated edit icon on the side to open edit section
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Read updated paper');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Read updated paper'), findsOneWidget);
  });

  testWidgets('Calendar navigation and future task planning', (tester) async {
    await tester.pumpWidget(PlanApp(notifier: notifier));
    await tester.pumpAndSettle();

    // Switch to Calendar tab
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('No tasks planned for this date.'), findsOneWidget);

    // Add task for the selected date on calendar
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Plan future milestone');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Plan future milestone'), findsOneWidget);

    // Switch back to Today tab and verify independence
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });
}
