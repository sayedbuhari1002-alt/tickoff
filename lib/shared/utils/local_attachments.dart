import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Local-only media helpers. Attachments are copied into app documents so they
/// survive cache cleanup and remain available offline.
class LocalAttachments {
  LocalAttachments._();
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickPhoto({bool camera = false}) async {
    final XFile? file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (file == null) return null;
    return _copyIntoApp(file.path, 'photos', p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path));
  }

  static Future<String> newAudioPath() async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory folder = Directory(p.join(root.path, 'audio_notes'));
    await folder.create(recursive: true);
    return p.join(folder.path, 'audio_${DateTime.now().microsecondsSinceEpoch}.m4a');
  }

  static Future<String> _copyIntoApp(String source, String subfolder, String extension) async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory folder = Directory(p.join(root.path, subfolder));
    await folder.create(recursive: true);
    final String target = p.join(folder.path, '${DateTime.now().microsecondsSinceEpoch}$extension');
    return (await File(source).copy(target)).path;
  }

  static Future<String?> duplicateFile(String path) async {
    final File source = File(path);
    if (!await source.exists()) return null;
    final String ext = p.extension(path).isEmpty ? '.bin' : p.extension(path);
    return _copyIntoApp(path, ext == '.m4a' ? 'audio_notes' : 'photos', ext);
  }

  static Future<void> deleteFile(String path) async {
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }
}

/// A small recorder wrapper so screens do not each create independent recorders.
class LocalAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _activePath;

  bool get isRecording => _activePath != null;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _activePath = await LocalAttachments.newAudioPath();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _activePath!);
    return true;
  }

  Future<String?> stop() async {
    if (_activePath == null) return null;
    final String? result = await _recorder.stop();
    final String path = _activePath!;
    _activePath = null;
    return result ?? path;
  }

  Future<void> dispose() => _recorder.dispose();
}

class LocalAudioPlayback {
  final AudioPlayer _player = AudioPlayer();
  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  Future<void> stop() => _player.stop();
  Future<void> dispose() => _player.dispose();
}
