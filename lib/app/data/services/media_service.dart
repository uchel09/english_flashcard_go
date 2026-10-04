import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class MediaService extends GetxService {
  static MediaService get to => Get.find<MediaService>();

  final AudioRecorder _recorder;
  final ImagePicker _imagePicker;

  final RxBool isRecording = false.obs;
  final RxString activeRecordingSide = ''.obs; // 'front' or 'back'

  MediaService({AudioRecorder? recorder, ImagePicker? imagePicker})
      : _recorder = recorder ?? AudioRecorder(),
        _imagePicker = imagePicker ?? ImagePicker();

  Future<String> get _appDirectoryPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> resolveAbsolutePath(String relativePath) async {
    if (p.isAbsolute(relativePath)) {
      return relativePath;
    }
    final basePath = await _appDirectoryPath;
    return p.join(basePath, relativePath);
  }

  String _generateFileName(String prefix, String ext) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${prefix}_${timestamp}_$random.$ext';
  }

  /// Copies a file to app media directory and returns its relative path
  Future<String> copyFileToAppStorage(File sourceFile, String subfolder, String prefix) async {
    final basePath = await _appDirectoryPath;
    final targetDir = Directory(p.join(basePath, 'media', subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final ext = p.extension(sourceFile.path).replaceAll('.', '');
    final cleanExt = ext.isEmpty ? 'bin' : ext;
    final filename = _generateFileName(prefix, cleanExt);
    final targetPath = p.join(targetDir.path, filename);

    await sourceFile.copy(targetPath);
    // Return relative path: media/subfolder/filename
    return p.join('media', subfolder, filename).replaceAll(r'\', '/');
  }

  // --- Audio Recording ---

  Future<bool> hasMicrophonePermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  Future<void> startRecording(String side) async {
    final hasPerm = await hasMicrophonePermission();
    if (!hasPerm) {
      throw Exception('Izin mikrofon ditolak. Mohon aktifkan izin mikrofon di pengaturan perangkat.');
    }

    final basePath = await _appDirectoryPath;
    final targetDir = Directory(p.join(basePath, 'media', 'audios'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final filename = _generateFileName('rec_$side', 'm4a');
    final targetPath = p.join(targetDir.path, filename);

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: targetPath,
    );

    isRecording.value = true;
    activeRecordingSide.value = side;
  }

  Future<String?> stopRecording() async {
    if (!isRecording.value) return null;

    try {
      final absolutePath = await _recorder.stop();
      isRecording.value = false;
      activeRecordingSide.value = '';

      if (absolutePath != null && File(absolutePath).existsSync()) {
        final basePath = await _appDirectoryPath;
        // Make relative to basePath
        final relative = p.relative(absolutePath, from: basePath).replaceAll(r'\', '/');
        return relative;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      isRecording.value = false;
      activeRecordingSide.value = '';
    }
    return null;
  }

  // --- Pick Audio File ---

  Future<String?> pickAudioFile(String side) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        return await copyFileToAppStorage(file, 'audios', 'pick_$side');
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
      throw Exception('Gagal memilih file audio: $e');
    }
    return null;
  }

  // --- Pick Image (Gallery / Camera) ---

  Future<String?> pickImage(ImageSource source, String side) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        final file = File(picked.path);
        final prefix = source == ImageSource.camera ? 'cam_$side' : 'gal_$side';
        return await copyFileToAppStorage(file, 'images', prefix);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      throw Exception('Izin akses galeri/kamera ditolak atau terjadi kesalahan.');
    }
    return null;
  }

  // --- Delete File ---

  Future<void> deleteMediaFile(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final absPath = await resolveAbsolutePath(relativePath);
      final file = File(absPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting media file: $e');
    }
  }

  @override
  void onClose() {
    _recorder.dispose();
    super.onClose();
  }
}
