import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/training_models.dart';

/// Picks one file for a training upload; null when cancelled. The bytes are
/// read into memory (web sends the browser's File the same way) — nothing is
/// copied to app or public storage by us. A provider so tests need no
/// platform dialog.
typedef TrainingFilePicker = Future<TrainingUploadFile?> Function(List<String> extensions);

final trainingFilePickerProvider = Provider<TrainingFilePicker>((ref) => (extensions) async {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );
      final f = r?.files.single;
      if (f == null || f.bytes == null) return null;
      return TrainingUploadFile(name: f.name, bytes: f.bytes!);
    });

/// Saves bytes where the user chooses (Android's system "Save to" screen —
/// web's browser download). Returns true when saved, false when cancelled.
typedef TrainingFileSaver = Future<bool> Function(String fileName, Uint8List bytes);

final trainingFileSaverProvider = Provider<TrainingFileSaver>((ref) => (fileName, bytes) async {
      final path = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      return path != null;
    });
