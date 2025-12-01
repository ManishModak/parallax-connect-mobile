import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';
import '../../helpers/connection_validator.dart';
import '../connection_mode_toggle.dart';
import '../setup_instructions_card.dart';

class ConnectionForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController urlController;
  final TextEditingController passwordController;
  final bool isLocal;
  final bool isConnecting;
  final bool isPasswordVisible;
  final HapticsHelper hapticsHelper;
  final VoidCallback onScanQr;
  final Future<void> Function() onPasteFromClipboard;
  final VoidCallback onTogglePasswordVisibility;
  final Future<void> Function() onConnect;
  final Future<void> Function() onOpenGuide;
  final Future<void> Function() onCopyLink;
  final ValueChanged<bool> onModeChanged;

  const ConnectionForm({
    super.key,
    required this.formKey,
    required this.urlController,
    required this.passwordController,
    required this.isLocal,
    required this.isConnecting,
    required this.isPasswordVisible,
    required this.hapticsHelper,
    required this.onScanQr,
    required this.onPasteFromClipboard,
    required this.onTogglePasswordVisibility,
    required this.onConnect,
    required this.onOpenGuide,
    required this.onCopyLink,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Connection Mode',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ConnectionModeToggle(
            isLocal: isLocal,
            onModeChanged: onModeChanged,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 12),
          _buildUrlHeader(),
          const SizedBox(height: 8),
          _buildUrlField(),
          const SizedBox(height: 24),
          _buildPasswordLabel(),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 24),
          SetupInstructionsCard(
            isLocal: isLocal,
            onOpenGuide: onOpenGuide,
            onCopyLink: onCopyLink,
          ),
          const SizedBox(height: 24),
          _buildConnectButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUrlHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Server URL or Address',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Tooltip(
          message: 'Scan QR host URL',
          child: IconButton(
            icon: const Icon(LucideIcons.scanLine),
            color: AppColors.secondary,
            onPressed: () {
              hapticsHelper.triggerHaptics();
              onScanQr();
            },
          ),
        ),
        Tooltip(
          message: 'Paste from clipboard',
          child: IconButton(
            icon: const Icon(LucideIcons.clipboardPaste),
            color: AppColors.secondary,
            onPressed: () async {
              hapticsHelper.triggerHaptics();
              await onPasteFromClipboard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: urlController,
      style: GoogleFonts.sourceCodePro(color: AppColors.primary),
      decoration: ConnectionValidator.buildUrlDecoration(isLocal: isLocal)
          .copyWith(
        prefixIcon: Icon(
          isLocal ? LucideIcons.wifi : LucideIcons.globe,
          color: AppColors.secondary,
        ),
      ),
      validator: ConnectionValidator.validateUrl,
    );
  }

  Widget _buildPasswordLabel() {
    return Text(
      'Password (optional)',
      style: GoogleFonts.inter(
        color: AppColors.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      style: GoogleFonts.inter(color: AppColors.primary),
      obscureText: !isPasswordVisible,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'Leave empty if not set',
        hintStyle: GoogleFonts.inter(color: AppColors.accent),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary),
        ),
        prefixIcon: const Icon(
          LucideIcons.lock,
          color: AppColors.secondary,
        ),
        suffixIcon: IconButton(
          tooltip: isPasswordVisible ? 'Hide password' : 'Show password',
          icon: Icon(
            isPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
          ),
          color: AppColors.secondary,
          onPressed: () {
            hapticsHelper.triggerHaptics();
            onTogglePasswordVisibility();
          },
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isConnecting
            ? null
            : () async {
                hapticsHelper.triggerHaptics();
                await onConnect();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.accent,
        ),
        child: isConnecting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Connecting...',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Text(
                'Connect',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}


