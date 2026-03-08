// lib/widgets/primary_button.dart
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final double fontSize;
  final double padding;

  const PrimaryButton({
    super.key,
    required this.title,
    required this.onTap,
    this.fontSize = 16.0,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0, // Elevation is handled by the BoxShadow above
          padding: EdgeInsets.symmetric(vertical: padding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Matching pill shape
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700, // Thicker weight for the call to action
            letterSpacing: 1.1,
          ),
        ),
        onPressed: onTap,
        child: Text(title.toUpperCase()), // Uppercase adds a modern touch
      ),
    );
  }
}