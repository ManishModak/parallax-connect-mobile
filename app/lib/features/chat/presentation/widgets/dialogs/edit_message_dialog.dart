import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../models/chat_message.dart';
import '../../view_models/chat_controller.dart';

class EditMessageDialog extends StatefulWidget {
  final ChatMessage message;
  final ChatController controller;

  const EditMessageDialog({
    super.key,
    required this.message,
    required this.controller,
  });

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Edit Message',
        style: GoogleFonts.inter(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _textController,
        autofocus: true,
        maxLines: 5,
        minLines: 1,
        style: GoogleFonts.inter(color: AppColors.primary),
        decoration: InputDecoration(
          hintText: 'Edit your message...',
          hintStyle: GoogleFonts.inter(color: AppColors.secondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.surfaceLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.surfaceLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: AppColors.secondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final newText = _textController.text.trim();
            if (newText.isNotEmpty && newText != widget.message.text) {
              widget.controller.editMessage(widget.message, newText);
            }
            Navigator.pop(context);
          },
          child: Text(
            'Save & Send',
            style: GoogleFonts.inter(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
