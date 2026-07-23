/// Utility helper to translate raw technical errors (PostgrestException, SocketException)
/// into user-friendly Indonesian messages for end users.
String formatUserFriendlyError(Object? error, {String defaultMessage = 'Terjadi kendala saat memuat data. Silakan coba lagi.'}) {
  if (error == null) return defaultMessage;
  final msg = error.toString();

  if (msg.contains('column') && msg.contains('does not exist')) {
    return 'Gagal memuat profil: Terjadi ketidaksesuaian struktur data. Silakan hubungi admin.';
  }

  if (msg.contains('infinite recursion') || msg.contains('42P17')) {
    return 'Gagal memuat profil toko: Silakan dorong pembaruan migrasi database (supabase db push).';
  }

  if (msg.contains('PostgrestException') || msg.contains('SocketException') || msg.contains('TimeoutException')) {
    return 'Gagal terhubung ke server. Silakan periksa koneksi internet Anda dan coba lagi.';
  }

  if (msg.contains('Authentication required') || msg.contains('JWT expired')) {
    return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
  }

  return defaultMessage;
}
