import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:mobile/features/auth/providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends ConsumerState<RegisterPage> {

  final formKey =
      GlobalKey<FormState>();

  final fullNameController =
      TextEditingController();

  final usernameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {

    fullNameController.dispose();

    usernameController.dispose();

    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  Future<void> handleRegister() async {

    if (
      !formKey.currentState!.validate()
    ) {
      return;
    }

    try {

      setState(() {
        isLoading = true;
      });

      final authService =
          ref.read(
            authServiceProvider,
          );

      await authService.signUp(
        email:
            emailController.text.trim(),

        password:
            passwordController.text,

        fullName:
            fullNameController.text.trim(),

        username:
            usernameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Register success',
          ),
        ),
      );

      context.go('/home');

    } catch (error) {

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),

            child: Form(
              key: formKey,

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,

                children: [

                  const Text(
                    'Create Account',

                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  TextFormField(
                    controller:
                        fullNameController,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Full Name',
                    ),

                    validator: (value) {

                      if (
                        value == null ||
                        value.isEmpty
                      ) {
                        return
                            'Full name required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextFormField(
                    controller:
                        usernameController,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Username',
                    ),

                    validator: (value) {

                      if (
                        value == null ||
                        value.isEmpty
                      ) {
                        return
                            'Username required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextFormField(
                    controller:
                        emailController,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Email',
                    ),

                    validator: (value) {

                      if (
                        value == null ||
                        value.isEmpty
                      ) {
                        return
                            'Email required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextFormField(
                    controller:
                        passwordController,

                    obscureText: true,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Password',
                    ),

                    validator: (value) {

                      if (
                        value == null ||
                        value.length < 6
                      ) {
                        return
                            'Minimum 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : handleRegister,

                    child:
                        isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,

                                child:
                                    CircularProgressIndicator(),
                              )
                            : const Text(
                                'Register',
                              ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextButton(
                    onPressed: () {
                      context.go('/login');
                    },

                    child: const Text(
                      'Already have account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}