import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String> exportCsvPlatform({
  required String filename,
  required String csvContent,
}) async {
  final contentWithBom = '\uFEFF$csvContent';
  final blobParts = <JSAny>[contentWithBom.toJS].toJS;
  final blob = web.Blob(
    blobParts,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final objectUrl = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = filename
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(objectUrl);

  return 'Laporan berhasil diunduh: $filename';
}
