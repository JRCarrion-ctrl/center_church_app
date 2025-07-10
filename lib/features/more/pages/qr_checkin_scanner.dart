// File: lib/features/nursery/pages/qr_checkin_scanner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _handleScan(String rawValue) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final childId = await _verifyQrKey(rawValue);
      if (childId == null) {
        setState(() => _error = 'Invalid or expired QR code');
        return;
      }

      await supabase.from('child_checkins').insert({
        'child_id': childId,
        'check_in_time': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        context.go('/nursery');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Child checked in successfully')),
        );
      }
    } catch (e, stack) {
      logger.e('Check-in failed', error: e, stackTrace: stack);
      if (mounted) setState(() => _error = 'Check-in failed.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<String?> _verifyQrKey(String rawKey) async {
    final response = await supabase
        .from('child_profile_qr_keys')
        .select('child_id')
        .eq('qr_key', rawKey)
        .maybeSingle();

    return response?['child_id'] as String?;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              final barcode = capture.barcodes.firstOrNull;
              final value = barcode?.rawValue;
              if (value != null) _handleScan(value);
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
                color: Colors.red.shade200,
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
