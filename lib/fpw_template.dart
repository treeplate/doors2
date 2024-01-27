bool get filePickerSupported => false;

abstract class PickedFile {
  List<String> readFileLines();
  void writeFile(String data);
  void appendToFile(String data);

  String get path;
  bool get exists;
}

Future<PickedFile?> pickFile() async {
  assert(!filePickerSupported,
      'Override [pickFile] when you override [filePickerSupported]');
  throw UnsupportedError(
      "Check [filePickerSupported] before calling pickFile()");
}

PickedFile getFile(String path) {
  assert(!filePickerSupported,
      'Override [getFile] when you override [filePickerSupported]');
  throw UnsupportedError(
      "Check [filePickerSupported] before calling getFile()");
}
