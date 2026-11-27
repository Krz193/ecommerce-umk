import 'package:mobile/core/utils/csv_exporter_stub.dart'
    if (dart.library.js_interop) 'package:mobile/core/utils/csv_exporter_web.dart'
    if (dart.library.io) 'package:mobile/core/utils/csv_exporter_io.dart';

/// Neutralizes spreadsheet formula injection prefixes (`=`, `+`, `-`, `@`,
/// `\t`, `\r`, including leading-whitespace variants) and applies RFC 4180
/// CSV quoting.
String escapeCsvCell(String value) {
  var sanitized = value;
  final trimmedLeft = sanitized.trimLeft();

  if (trimmedLeft.isNotEmpty &&
      (trimmedLeft.startsWith('=') ||
          trimmedLeft.startsWith('+') ||
          trimmedLeft.startsWith('-') ||
          trimmedLeft.startsWith('@') ||
          sanitized.startsWith('\t') ||
          sanitized.startsWith('\r'))) {
    sanitized = "'$sanitized";
  }

  final escaped = sanitized.replaceAll('"', '""');

  if (escaped.contains(',') ||
      escaped.contains('\n') ||
      escaped.contains('\r') ||
      escaped.contains('"')) {
    return '"$escaped"';
  }

  return escaped;
}

String buildCsvContent(List<List<String>> rows) {
  return rows.map((row) => row.map(escapeCsvCell).join(',')).join('\n');
}

Future<String> saveOrShareCsvReport({
  required String filename,
  required String csvContent,
}) {
  return exportCsvPlatform(filename: filename, csvContent: csvContent);
}
