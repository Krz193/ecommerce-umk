/// Thrown when a requested entity does not exist or is no longer accessible.
class ResourceNotFoundException implements Exception {
  final String message;

  const ResourceNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Returns true when [error] represents a missing or inaccessible record.
bool isNotFoundError(Object? error) {
  if (error == null) return false;
  if (error is ResourceNotFoundException) return true;
  final msg = error.toString();
  return msg.contains('PGRST116') || msg.contains('0 rows');
}

/// Utility helper to translate raw technical errors (PostgrestException, SocketException)
/// into user-friendly Indonesian messages for end users.
String formatUserFriendlyError(
  Object? error, {
  String defaultMessage =
      'Terjadi kendala saat memuat data. Silakan coba lagi.',
}) {
  if (error == null) return defaultMessage;
  if (error is ResourceNotFoundException) return error.message;

  final msg = error.toString();

  if (msg.contains('PGRST116') || msg.contains('0 rows')) {
    return 'Data tidak ditemukan atau Anda tidak lagi memiliki akses.';
  }

  if (msg.contains('column') && msg.contains('does not exist')) {
    return 'Gagal memuat profil: Terjadi ketidaksesuaian struktur data. Silakan hubungi admin.';
  }

  if (msg.contains('infinite recursion') || msg.contains('42P17')) {
    return 'Gagal memuat profil toko: Silakan dorong pembaruan migrasi database (supabase db push).';
  }

  if (msg.contains('Authentication required') ||
      msg.contains('JWT expired') ||
      msg.contains('User not logged in')) {
    return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
  }

  if (msg.contains('PostgrestException') ||
      msg.contains('SocketException') ||
      msg.contains('TimeoutException')) {
    return 'Gagal terhubung ke server. Silakan periksa koneksi internet Anda dan coba lagi.';
  }

  return defaultMessage;
}
