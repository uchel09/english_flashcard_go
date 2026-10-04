import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../../controllers/theme_controller.dart';

enum CardSide { front, back }

class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  final AudioPlayer _audioPlayer;
  final FlutterTts _flutterTts;

  final RxBool isPlaying = false.obs;
  final RxnInt activeCardId = RxnInt();
  final Rx<CardSide?> activeSide = Rx<CardSide?>(null);

  StreamSubscription<PlayerState>? _playerSubscription;

  AudioService({AudioPlayer? audioPlayer, FlutterTts? flutterTts})
      : _audioPlayer = audioPlayer ?? AudioPlayer(),
        _flutterTts = flutterTts ?? FlutterTts() {
    _initTts();
    _initAudioPlayer();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      _resetPlayingState();
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      debugPrint('FlutterTTS error: $msg');
      _resetPlayingState();
    });
  }

  void _initAudioPlayer() {
    _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _resetPlayingState();
      }
    });
  }

  void _resetPlayingState() {
    isPlaying.value = false;
    activeCardId.value = null;
    activeSide.value = null;
  }

  String _mapLanguageToLocale(String lang) {
    switch (lang.toLowerCase()) {
      case 'id':
        return 'id-ID';
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'ja':
        return 'ja-JP';
      case 'de':
        return 'de-DE';
      case 'ar':
        return 'ar-SA';
      case 'zh':
        return 'zh-CN';
      default:
        return lang.contains('-') ? lang : 'id-ID';
    }
  }

  Future<void> stop() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    } finally {
      _resetPlayingState();
    }
  }

  Future<void> playAudioPath(String path) async {
    await stop();
    isPlaying.value = true;
    try {
      String resolved = path;
      if (!p.isAbsolute(resolved)) {
        final dir = await getApplicationDocumentsDirectory();
        resolved = p.join(dir.path, resolved);
      }
      if (File(resolved).existsSync()) {
        await _audioPlayer.setFilePath(resolved);
        await _audioPlayer.play();
      } else {
        _resetPlayingState();
      }
    } catch (e) {
      debugPrint('Error playing audio preview: $e');
      _resetPlayingState();
    }
  }

  Future<void> playCardSide({
    required Card card,
    required CardSide side,
    String sourceLang = 'id',
  }) async {
    // 1. Always stop any currently playing audio first
    await stop();

    isPlaying.value = true;
    activeCardId.value = card.id;
    activeSide.value = side;

    final String? recordingPath =
        side == CardSide.front ? card.frontAudioPath : card.backAudioPath;

    String? resolvedPath = recordingPath;
    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      if (!p.isAbsolute(resolvedPath)) {
        final dir = await getApplicationDocumentsDirectory();
        resolvedPath = p.join(dir.path, resolvedPath);
      }
    }

    // 2. Rule: If recording exists on disk, play via just_audio
    if (resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync()) {
      try {
        await _audioPlayer.setFilePath(resolvedPath);
        await _audioPlayer.play();
        return;
      } catch (e) {
        debugPrint('Error playing recorded audio with just_audio: $e');
        _resetPlayingState();
        return;
      }
    }

    // 3. Rule: Otherwise, use flutter_tts
    try {
      final themeCtrl =
          Get.isRegistered<ThemeController>() ? ThemeController.to : null;
      final rate = themeCtrl?.ttsSpeechRate.value ?? 0.5;
      final pitch = themeCtrl?.ttsPitch.value ?? 1.0;
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);

      if (side == CardSide.front) {
        final locale = _mapLanguageToLocale(sourceLang);
        await _flutterTts.setLanguage(locale);
        await _flutterTts.speak(card.frontText);
      } else {
        await _flutterTts.setLanguage('en-US');
        final voiceName = themeCtrl?.ttsVoiceName.value;
        final voiceLocale = themeCtrl?.ttsVoiceLocale.value;
        if (voiceName != null && voiceName.isNotEmpty) {
          try {
            await _flutterTts.setVoice(
              {'name': voiceName, 'locale': voiceLocale ?? 'en-US'},
            );
          } catch (_) {}
        }
        await _flutterTts.speak(card.backText);
      }
    } catch (e) {
      debugPrint('Error speaking TTS: $e');
      _resetPlayingState();
    }
  }

  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List) {
        final result = <Map<String, String>>[];
        for (final v in rawVoices) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty) {
              result.add({'name': name, 'locale': locale});
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('Error getting TTS voices: $e');
    }
    return [];
  }

  Future<void> speakSample({
    String text = 'Hello, this is a voice sample for your flashcards.',
    String lang = 'en-US',
  }) async {
    await stop();
    isPlaying.value = true;
    try {
      final themeCtrl =
          Get.isRegistered<ThemeController>() ? ThemeController.to : null;
      final rate = themeCtrl?.ttsSpeechRate.value ?? 0.5;
      final pitch = themeCtrl?.ttsPitch.value ?? 1.0;
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);

      final voiceName = themeCtrl?.ttsVoiceName.value;
      final voiceLocale = themeCtrl?.ttsVoiceLocale.value;
      if (voiceName != null && voiceName.isNotEmpty) {
        try {
          await _flutterTts.setVoice(
            {'name': voiceName, 'locale': voiceLocale ?? lang},
          );
        } catch (_) {}
      }

      await _flutterTts.setLanguage(lang);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking sample TTS: $e');
      _resetPlayingState();
    }
  }

  bool isCardSidePlaying(int cardId, CardSide side) {
    return isPlaying.value &&
        activeCardId.value == cardId &&
        activeSide.value == side;
  }

  @override
  void onClose() {
    _playerSubscription?.cancel();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.onClose();
  }
}
