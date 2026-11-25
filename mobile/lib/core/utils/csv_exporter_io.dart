import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> exportCsvPlatform({
  required String filename,
  required String csvContent,
}) async {
  final contentWithBom = '\uFEFF$csvContent';

  if (Platform.isAndroid || Platform.isIOS) {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(contentWithBom, encoding: utf8, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: filename,
      ),
    );

    return 'Laporan siap disimpan atau dibagikan: $filename';
  }

  Directory? targetDir;
  try {
    targetDir = await getDownloadsDirectory();
  } catch (_) {
    targetDir = null;
  }
  targetDir ??= await getApplicationDocumentsDirectory();

  await targetDir.create(recursive: true);
  final file = File('${targetDir.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(contentWithBom, encoding: utf8, flush: true);

  return 'Laporan disimpan di: ${file.path}';
}
