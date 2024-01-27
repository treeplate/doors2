import 'dart:io';

import 'package:file_picker/file_picker.dart';

bool get filePickerSupported => true;

class PickedFile {
  final File proxy;
  String get path => proxy.path;
  bool get exists => proxy.existsSync();

  PickedFile(this.proxy);
  List<String> readFileLines() {
    return proxy.readAsLinesSync();
  }

  void writeFile(String data) {
    proxy.writeAsStringSync(data);
  }

  void appendToFile(String data) {
    proxy.writeAsStringSync(data, mode: FileMode.append);
  }
}

Future<PickedFile?> pickFile() async {
  FilePickerResult? filePickerResult = (await FilePicker.platform.pickFiles(
    allowedExtensions: ['tas'],
  ));
  if (filePickerResult == null) return null;
  return PickedFile(
    File(
      filePickerResult.paths.single!,
    ),
  );
}

PickedFile getFile(String path) {
  return PickedFile(
    File(path),
  );
}
