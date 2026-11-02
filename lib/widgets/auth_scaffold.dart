import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'rig_art.dart';
import 'rig_surfaces.dart';

/// Shared layout for sign-in and registration: a branded header over the form.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: RigPalette.volt,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(Radii.xl),
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    right: -Space.lg,
                    bottom: -Space.xxl,
                    width: 148,
                    child: RigTowerArt(),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.xxl,
                        Space.lg,
                        Space.xxl,
                        Space.section,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showBack)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: IconButton(
                                tooltip: 'Back',
                                color: RigPalette.ink,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            ),
                          Row(
                            children: [
                              const RigMark(size: 36),
                              const SizedBox(width: Space.sm + 2),
                              Text(
                                'SmartRig',
                                style: context.text.titleMedium!.copyWith(
                                  color: RigPalette.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.section),
                          Padding(
                            padding: const EdgeInsets.only(right: 96),
                            child: Text(
                              title,
                              style: context.text.displayMedium!.copyWith(
                                color: RigPalette.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Padding(
                            padding: const EdgeInsets.only(right: 112),
                            child: Text(
                              subtitle,
                              style: context.text.bodyMedium!.copyWith(
                                color: RigPalette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: ContentWidth(
                maxWidth: 480,
                child: Padding(
                  padding: const EdgeInsets.all(Space.xxl),
                  child: form,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Please enter your email';
  if (!value.contains('@')) return 'Please enter a valid email';
  return null;
}
