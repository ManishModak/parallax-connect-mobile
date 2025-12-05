import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/services/system/connectivity_service.dart';
import '../../../../core/services/ai/model_selection_service.dart';
import '../../../../core/services/storage/config_storage.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../helpers/qr_scanner_handler.dart';
import '../widgets/connection/connection_form.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLocal = false;
  bool _isConnecting = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final storage = ref.read(configStorageProvider);
    if (storage.hasConfig()) {
      setState(() {
        _urlController.text = storage.getBaseUrl() ?? '';
        _isLocal = storage.getIsLocal();
        _passwordController.text = storage.getPassword() ?? '';
      });
    }
  }

  Future<void> _scanQrCode() async {
    try {
      final trimmed = await QrScannerHandler.scanUrl(context);
      if (!mounted || trimmed == null) return;

      setState(() {
        _urlController.text = trimmed;
      });
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: trimmed.length),
      );

      // Auto-connect in background after successful scan
      await _autoConnectFromQr(trimmed);
    } on PlatformException {
      if (!mounted) return;
      _showErrorSnackBar(
        'Unable to scan QR code. Paste URL manually.',
        LucideIcons.alertTriangle,
      );
    }
  }

  Future<void> _autoConnectFromQr(String scannedUrl) async {
    setState(() => _isConnecting = true);
    _showConnectingSnackBar('Connecting to server...');

    // Check connectivity for cloud mode
    if (!_isLocal) {
      final connectivityService = ref.read(connectivityServiceProvider);
      final hasInternet = await connectivityService.hasInternetConnection;

      if (!hasInternet) {
        setState(() => _isConnecting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackBar(
          'No internet connection. Cloud mode requires an active internet connection.',
          LucideIcons.wifiOff,
        );
        return;
      }
    }

    // Save config temporarily for testing
    final storage = ref.read(configStorageProvider);
    await storage.saveConfig(
      baseUrl: scannedUrl,
      isLocal: _isLocal,
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
    );

    // Test connection
    final chatRepository = ref.read(chatRepositoryProvider);
    final isConnected = await chatRepository.testConnection();

    setState(() => _isConnecting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (isConnected) {
      _showSuccessSnackBar('Connected! Navigating to chat...');
      // Fetch available models after successful connection
      ref.read(modelSelectionProvider.notifier).fetchModels();

      // Fetch server capabilities and auto-enable attachments if supported
      final featureFlags = ref.read(featureFlagsProvider.notifier);
      await featureFlags.refreshCapabilities();
      final autoEnabled = await featureFlags.autoEnableIfServerSupports();
      if (autoEnabled) {
        developer.log(
          'Auto-enabled attachments (server has vision/doc support)',
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      context.go(AppRoutes.chat);
    } else {
      // Provide mode-specific troubleshooting hints
      final errorMessage = _isLocal
          ? 'Connection failed. Check: Same WiFi, server running, firewall.'
          : 'Connection failed. Check: Internet, server running, URL correct.';

      _showErrorSnackBar(errorMessage, LucideIcons.serverOff);
    }
  }

  void _showConnectingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.surfaceLight,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _handlePasteFromClipboard(HapticsHelper hapticsHelper) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      _showErrorSnackBar('Clipboard is empty.', LucideIcons.clipboardX);
      return;
    }
    setState(() {
      _urlController.text = text;
    });
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: _urlController.text.length),
    );
    if (!mounted) return;
    _showSuccessSnackBar('URL pasted from clipboard.');
  }

  Future<void> _saveAndConnect() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isConnecting = true);

      // Check connectivity for cloud mode
      if (!_isLocal) {
        final connectivityService = ref.read(connectivityServiceProvider);
        final hasInternet = await connectivityService.hasInternetConnection;

        if (!hasInternet) {
          setState(() => _isConnecting = false);
          if (!mounted) return;
          _showErrorSnackBar(
            'No internet connection. Cloud mode requires an active internet connection.',
            LucideIcons.wifiOff,
          );
          return;
        }
      }

      // Save config temporarily for testing
      final storage = ref.read(configStorageProvider);
      await storage.saveConfig(
        baseUrl: _urlController.text.trim(),
        isLocal: _isLocal,
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
      );

      // Test connection
      final chatRepository = ref.read(chatRepositoryProvider);
      final isConnected = await chatRepository.testConnection();

      setState(() => _isConnecting = false);

      if (!mounted) return;

      if (isConnected) {
        _showSuccessSnackBar('Successfully connected to server!');
        // Fetch available models after successful connection
        ref.read(modelSelectionProvider.notifier).fetchModels();

        // Fetch server capabilities and auto-enable attachments if supported
        final featureFlags = ref.read(featureFlagsProvider.notifier);
        await featureFlags.refreshCapabilities();
        final autoEnabled = await featureFlags.autoEnableIfServerSupports();
        if (autoEnabled) {
          developer.log(
            'Auto-enabled attachments (server has vision/doc support)',
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go(AppRoutes.chat);
      } else {
        // Provide mode-specific troubleshooting hints
        final errorMessage = _isLocal
            ? 'Failed to connect. Check: 1) Same WiFi network 2) Server is running 3) Firewall allows connection. If it worked before, try disabling WiFi MAC randomization in phone settings.'
            : 'Failed to connect. Check: 1) Internet connection 2) Server is running 3) URL is correct.';

        _showErrorSnackBar(errorMessage, LucideIcons.serverOff);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.successDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openSetupGuide(HapticsHelper hapticsHelper) async {
    hapticsHelper.triggerHaptics();
    final url = Uri.parse(
      'https://github.com/ManishModak/parallax-connect/blob/main/SERVER_SETUP.md',
    );
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showErrorSnackBar(
          'Unable to open the setup guide. Copy the URL manually.',
          LucideIcons.alertTriangle,
        );
      }
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Failed to launch setup guide',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showErrorSnackBar(
        'Unable to open the setup guide. Copy the URL manually.',
        LucideIcons.alertTriangle,
      );
    }
  }

  Future<void> _copySetupLink(HapticsHelper hapticsHelper) async {
    hapticsHelper.triggerHaptics();
    await Clipboard.setData(
      const ClipboardData(
        text:
            'https://github.com/ManishModak/parallax-connect/blob/main/SERVER_SETUP.md',
      ),
    );
    if (!mounted) return;
    _showSuccessSnackBar('Server setup link copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final hapticsHelper = ref.read(hapticsHelperProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Connection Setup',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: ConnectionForm(
          formKey: _formKey,
          urlController: _urlController,
          passwordController: _passwordController,
          isLocal: _isLocal,
          isConnecting: _isConnecting,
          isPasswordVisible: _isPasswordVisible,
          hapticsHelper: hapticsHelper,
          onScanQr: _scanQrCode,
          onPasteFromClipboard: () async =>
              _handlePasteFromClipboard(hapticsHelper),
          onTogglePasswordVisibility: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
          onConnect: _saveAndConnect,
          onOpenGuide: () => _openSetupGuide(hapticsHelper),
          onCopyLink: () => _copySetupLink(hapticsHelper),
          onModeChanged: (value) => setState(() => _isLocal = value),
        ),
      ),
    );
  }
}
