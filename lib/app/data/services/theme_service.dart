import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ThemePreferencesModel {
  final bool isDarkMode;
  final int accentColorValue;
  final String themeMode; // 'light', 'dark', 'system'
  final String cardStyle; // 'elevated', 'outlined', 'flat'
  final String deckStyle; // 'standard', 'compact', 'outlined'
  final String defaultSourceLang; // default 'id'
  final bool isReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final double ttsSpeechRate;
  final double ttsPitch;
  final String? ttsVoiceName;
  final String? ttsVoiceLocale;
  final bool hasCompletedOnboarding;

  const ThemePreferencesModel({
    required this.isDarkMode,
    required this.accentColorValue,
    this.themeMode = 'system',
    this.cardStyle = 'elevated',
    this.deckStyle = 'standard',
    this.defaultSourceLang = 'id',
    this.isReminderEnabled = false,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.ttsSpeechRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsVoiceName,
    this.ttsVoiceLocale,
    this.hasCompletedOnboarding = false,
  });

  ThemePreferencesModel copyWith({
    bool? isDarkMode,
    int? accentColorValue,
    String? themeMode,
    String? cardStyle,
    String? deckStyle,
    String? defaultSourceLang,
    bool? isReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    double? ttsSpeechRate,
    double? ttsPitch,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    bool? hasCompletedOnboarding,
  }) {
    return ThemePreferencesModel(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      themeMode: themeMode ?? this.themeMode,
      cardStyle: cardStyle ?? this.cardStyle,
      deckStyle: deckStyle ?? this.deckStyle,
      defaultSourceLang: defaultSourceLang ?? this.defaultSourceLang,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVoiceName: ttsVoiceName ?? this.ttsVoiceName,
      ttsVoiceLocale: ttsVoiceLocale ?? this.ttsVoiceLocale,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toJson() => {
        'isDarkMode': isDarkMode,
        'accentColorValue': accentColorValue,
        'themeMode': themeMode,
        'cardStyle': cardStyle,
        'deckStyle': deckStyle,
        'defaultSourceLang': defaultSourceLang,
        'isReminderEnabled': isReminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'ttsSpeechRate': ttsSpeechRate,
        'ttsPitch': ttsPitch,
        'ttsVoiceName': ttsVoiceName,
        'ttsVoiceLocale': ttsVoiceLocale,
        'hasCompletedOnboarding': hasCompletedOnboarding,
      };

  factory ThemePreferencesModel.fromJson(Map<String, dynamic> json) {
    final mode = json['themeMode'] as String? ??
        ((json['isDarkMode'] as bool? ?? false) ? 'dark' : 'system');
    return ThemePreferencesModel(
      isDarkMode: json['isDarkMode'] as bool? ?? (mode == 'dark'),
      accentColorValue:
          json['accentColorValue'] as int? ?? 0xFF3F51B5, // Default Indigo
      themeMode: mode,
      cardStyle: json['cardStyle'] as String? ?? 'elevated',
      deckStyle: json['deckStyle'] as String? ?? 'standard',
      defaultSourceLang: json['defaultSourceLang'] as String? ?? 'id',
      isReminderEnabled: json['isReminderEnabled'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 19,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      ttsSpeechRate: (json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.5,
      ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
      ttsVoiceName: json['ttsVoiceName'] as String?,
      ttsVoiceLocale: json['ttsVoiceLocale'] as String?,
      hasCompletedOnboarding:
          json['hasCompletedOnboarding'] as bool? ?? false,
    );
  }
}

class ThemeService {
  Future<File> _getStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/theme_preferences.json');
  }

  Future<ThemePreferencesModel?> readPreferences() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return ThemePreferencesModel.fromJson(json);
      }
    } catch (e) {
      debugPrint('ThemeService: Failed to read preferences: $e');
    }
    return null;
  }

  Future<void> writePreferences(ThemePreferencesModel model) async {
    try {
      final file = await _getStorageFile();
      final content = jsonEncode(model.toJson());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('ThemeService: Failed to write preferences: $e');
    }
  }
}
