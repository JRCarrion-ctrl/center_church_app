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
        color: Colors.white, // Solid white background
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Material widget needed so the InkWell ripple effect works properly
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            // Matching the 0.8 multiplier from SecondaryButton
            padding: EdgeInsets.symmetric(vertical: padding * 0.8),
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: fontSize,
                fontWeight: FontWeight.w700, 
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}