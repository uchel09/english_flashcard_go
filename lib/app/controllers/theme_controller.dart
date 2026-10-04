import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/services/notification_service.dart';
import '../data/services/theme_service.dart';

class AccentColorOption {
  final String name;
  final Color color;

  const AccentColorOption({
    required this.name,
    required this.color,
  });
}

class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final ThemeService _themeService;

  ThemeController({ThemeService? themeService})
      : _themeService = themeService ?? ThemeService();

  static const List<AccentColorOption> accentColors = [
    AccentColorOption(name: 'Indigo', color: Colors.indigo),
    AccentColorOption(name: 'Biru', color: Colors.blue),
    AccentColorOption(name: 'Teal', color: Colors.teal),
    AccentColorOption(name: 'Hijau', color: Colors.green),
    AccentColorOption(name: 'Oranye', color: Colors.deepOrange),
    AccentColorOption(name: 'Ungu', color: Colors.deepPurple),
  ];

  final RxBool isDarkMode = false.obs;
  final Rx<ThemeMode> themeModeRx = ThemeMode.system.obs;
  final Rx<Color> accentColor = Rx<Color>(Colors.indigo);
  final RxString cardStyle = 'elevated'.obs;
  final RxString deckStyle = 'standard'.obs;
  final RxString defaultSourceLang = 'id'.obs;

  // Reminder settings
  final RxBool isReminderEnabled = false.obs;
  final RxInt reminderHour = 19.obs;
  final RxInt reminderMinute = 0.obs;

  // TTS settings (Speech rate, Pitch, Voice)
  final RxDouble ttsSpeechRate = 0.5.obs;
  final RxDouble ttsPitch = 1.0.obs;
  final RxnString ttsVoiceName = RxnString();
  final RxnString ttsVoiceLocale = RxnString();

  // Onboarding
  final RxBool hasCompletedOnboarding = false.obs;

  ThemeMode get themeMode => themeModeRx.value;

  ThemeData get activeTheme =>
      isDarkMode.value ? darkTheme : lightTheme;

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor.value,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: _buildCardTheme(Brightness.light),
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor.value,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: _buildCardTheme(Brightness.dark),
      );

  CardThemeData _buildCardTheme(Brightness brightness) {
    switch (cardStyle.value) {
      case 'outlined':
        return CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: brightness == Brightness.light
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),
          ),
        );
      case 'flat':
        return CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      case 'elevated':
      default:
        return CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadThemeSettings();
  }

  Future<void> loadThemeSettings() async {
    final preferences = await _themeService.readPreferences();
    if (preferences != null) {
      accentColor.value = Color(preferences.accentColorValue);
      cardStyle.value = preferences.cardStyle;
      deckStyle.value = preferences.deckStyle;
      defaultSourceLang.value = preferences.defaultSourceLang;
      switch (preferences.themeMode) {
        case 'light':
          themeModeRx.value = ThemeMode.light;
          isDarkMode.value = false;
          break;
        case 'dark':
          themeModeRx.value = ThemeMode.dark;
          isDarkMode.value = true;
          break;
        case 'system':
        default:
          themeModeRx.value = ThemeMode.system;
          isDarkMode.value = preferences.isDarkMode;
          break;
      }

      isReminderEnabled.value = preferences.isReminderEnabled;
      reminderHour.value = preferences.reminderHour;
      reminderMinute.value = preferences.reminderMinute;

      ttsSpeechRate.value = preferences.ttsSpeechRate;
      ttsPitch.value = preferences.ttsPitch;
      ttsVoiceName.value = preferences.ttsVoiceName;
      ttsVoiceLocale.value = preferences.ttsVoiceLocale;
      hasCompletedOnboarding.value = preferences.hasCompletedOnboarding;

      if (isReminderEnabled.value && Get.isRegistered<NotificationService>()) {
        NotificationService.to.scheduleDailyReminder(
          hour: reminderHour.value,
          minute: reminderMinute.value,
        );
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeRx.value = mode;
    isDarkMode.value = mode == ThemeMode.dark;
    Get.changeThemeMode(mode);
    Get.changeTheme(activeTheme);
    await _saveThemeSettings();
  }

  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleDarkMode() async {
    if (themeModeRx.value == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setAccentColor(Color color) async {
    accentColor.value = color;
    Get.changeTheme(activeTheme);
    await _saveThemeSettings();
  }

  Future<void> setCardStyle(String style) async {
    cardStyle.value = style;
    Get.changeTheme(activeTheme);
    await _saveThemeSettings();
  }

  Future<void> setDeckStyle(String style) async {
    deckStyle.value = style;
    Get.changeTheme(activeTheme);
    await _saveThemeSettings();
  }

  Future<void> setDefaultSourceLang(String lang) async {
    defaultSourceLang.value = lang;
    await _saveThemeSettings();
  }

  Future<void> setReminderSettings(bool enabled, int hour, int minute) async {
    isReminderEnabled.value = enabled;
    reminderHour.value = hour;
    reminderMinute.value = minute;
    await _saveThemeSettings();

    if (Get.isRegistered<NotificationService>()) {
      if (enabled) {
        await NotificationService.to.requestPermissions();
        await NotificationService.to.scheduleDailyReminder(
          hour: hour,
          minute: minute,
        );
      } else {
        await NotificationService.to.cancelReminder();
      }
    }
  }

  Future<void> setTtsSpeechRate(double rate) async {
    ttsSpeechRate.value = rate;
    await _saveThemeSettings();
  }

  Future<void> setTtsPitch(double pitch) async {
    ttsPitch.value = pitch;
    await _saveThemeSettings();
  }

  Future<void> setTtsVoice(String? name, String? locale) async {
    ttsVoiceName.value = name;
    ttsVoiceLocale.value = locale;
    await _saveThemeSettings();
  }

  Future<void> completeOnboarding() async {
    hasCompletedOnboarding.value = true;
    await _saveThemeSettings();
  }

  Future<void> resetOnboarding() async {
    hasCompletedOnboarding.value = false;
    await _saveThemeSettings();
  }

  Future<void> _saveThemeSettings() async {
    final modeStr = themeModeRx.value == ThemeMode.light
        ? 'light'
        : themeModeRx.value == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _themeService.writePreferences(
      ThemePreferencesModel(
        isDarkMode: isDarkMode.value,
        accentColorValue: accentColor.value.toARGB32(),
        themeMode: modeStr,
        cardStyle: cardStyle.value,
        deckStyle: deckStyle.value,
        defaultSourceLang: defaultSourceLang.value,
        isReminderEnabled: isReminderEnabled.value,
        reminderHour: reminderHour.value,
        reminderMinute: reminderMinute.value,
        ttsSpeechRate: ttsSpeechRate.value,
        ttsPitch: ttsPitch.value,
        ttsVoiceName: ttsVoiceName.value,
        ttsVoiceLocale: ttsVoiceLocale.value,
        hasCompletedOnboarding: hasCompletedOnboarding.value,
      ),
    );
  }
}
