import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/models/app_user_model.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  bool initialized = false;
  bool isSaving = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void initialize(AppUserModel user) {
    if (initialized) return;

    initialized = true;
    fullNameController.text = user.fullName;
    emailController.text = user.email.isNotEmpty
        ? user.email
        : (supabase.auth.currentUser?.email ?? '');
    phoneController.text = user.phone ?? '';
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final authService = ref.read(authServiceProvider);

      await authService.updateProfile(
        fullName: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
      );

      ref.invalidate(appUserProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil Saya')),
      body: appUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Pengguna tidak ditemukan'));
          }

          initialize(user);
          return buildForm(user);
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildForm(AppUserModel user) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: fullNameController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama lengkap wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Email Field (Read-only)
              TextFormField(
                controller: emailController,
                enabled: false,
                style: TextStyle(color: Colors.grey.shade700),
                decoration: InputDecoration(
                  labelText: 'Email Akun',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  helperText: 'Email terdaftar pada sistem (hanya baca)',
                  fillColor: Colors.grey.shade100,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon / WhatsApp',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Tipe Akun: ${user.role == 'seller' ? 'Penjual UMK 🏬' : 'Pembeli 🛒'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryHover,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: isSaving ? null : saveProfile,
                icon: isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_rounded),
                label: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
