import '../database/database_helper.dart';
import '../models/activity_history_entry.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final DatabaseHelper _databaseHelper;

  SettingsRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper();

  Future<AppSettings> getSettings() async {
    return await _databaseHelper.getAppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _databaseHelper.saveAppSettings(settings);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'settings_updated',
        entityType: 'settings',
        details: 'Updated app settings',
        timestamp: DateTime.now(),
      ),
    );
  }
}
