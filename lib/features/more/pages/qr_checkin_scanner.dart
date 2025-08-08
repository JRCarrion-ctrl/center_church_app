import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class QRCheckinScannerPage extends StatefulWidget {
  const QRCheckinScannerPage({super.key});

  @override
  State<QRCheckinScannerPage> createState() => _QRCheckinScannerPageState();
}

class _QRCheckinScannerPageState extends State<QRCheckinScannerPage> {
  final supabase = Supabase.instance.client;
  final logger = Logger();
  final MobileScannerController _controller = MobileScannerController();

  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawValue) async {
    if (_processing) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final childId = await _verifyQrKey(rawValue);
      if (childId == null) {
        // key_315: "Invalid or expired QR code"
        setState(() {
          _error = "key_315".tr();
          _processing = false;
        });
        await _controller.start();
        return;
      }

      // Prevent duplicate check-ins (still checked-in with no checkout)
      final existing = await supabase
          .from('child_checkins')
          .select('id')
          .eq('child_id', childId);

      if (existing.isNotEmpty) {
        // key_317: "Child is already checked in"
        setState(() {
          _error = "key_317".tr();
          _processing = false;
        });
        await _controller.start();
        return;
      }

      await supabase.from('child_checkins').insert({
        'child_id': childId,
        // Store in UTC to be consistent app-wide
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      // Navigate then confirm (snackbar lives on destination Scaffold)
      context.go('/nursery');
      // key_313: existing success string (e.g., "Checked in successfully")
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_313".tr())),
      );
    } catch (e, stack) {
      logger.e('Check-in failed', error: e, stackTrace: stack);
      if (!mounted) return;

      // key_316: "Check-in failed."
      setState(() {
        _error = "key_316".tr();
      });
      await _controller.start();
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<String?> _verifyQrKey(String rawKey) async {
    final response = await supabase
        .from('child_profile_qr_keys')
        .select('child_id')
        .eq('qr_key', rawKey)
        .maybeSingle();

    if (response == null) return null;
    final childId = response['child_id'];
    return childId is String ? childId : childId?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // key_314: existing title, e.g., "Scan to Check In"
      appBar: AppBar(title: Text("key_314".tr())),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              if (_processing) return;

              // Prefer a QR code if multiple barcodes detected
              String? value;
              for (final b in capture.barcodes) {
                if (b.format == BarcodeFormat.qrCode) {
                  value = b.rawValue;
                  break;
                }
              }
              value ??= capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;

              if (value != null) {
                _handleScan(value);
              }
            },
          ),
          if (_processing)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
