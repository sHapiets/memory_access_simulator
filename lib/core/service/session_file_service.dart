import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:memory_access_simulator/core/controller/runtime.dart';

class SessionFileService {
  SessionFileService._();

  static void downloadSession(Runtime runtime) {
    final jsonString = runtime.exportSessionJson();
    final bytes = utf8.encode(jsonString);

    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..download = 'memory_access_session.masim'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // Let the browser begin the download before releasing the object URL.
    Timer(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  static Future<bool> loadSession(Runtime runtime) async {
    final input = html.FileUploadInputElement()
      ..accept = '.masim,application/json';

    input.click();

    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return false;

    final reader = html.FileReader();
    reader.readAsText(files.first);

    await reader.onLoad.first;

    final result = reader.result;
    if (result is! String) {
      throw const FormatException('Unable to read the selected session file.');
    }

    runtime.importSessionJson(result);
    return true;
  }
}
