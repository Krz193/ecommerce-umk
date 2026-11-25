Future<String> exportCsvPlatform({
  required String filename,
  required String csvContent,
}) async {
  throw UnsupportedError('CSV export tidak didukung pada platform ini.');
}
