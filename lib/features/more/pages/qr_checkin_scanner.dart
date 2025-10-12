// File: lib/features/nursery/pages/qr_checkin_scanner_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/app_state.dart';

class QRCheckinScannerPage extends StatefulWidget {
  const QRCheckinScannerPage({super.key});

  @override
  State<QRCheckinScannerPage> createState() => _QRCheckinScannerPageState();
}

class _QRCheckinScannerPageState extends State<QRCheckinScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _processing = false;
  String? _error;
  Timer? _errorClearTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errorClearTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  void _showError(String message) {
    _errorClearTimer?.cancel();
    setState(() => _error = message);
    _errorClearTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _error = null);
    });
  }

  Future<void> _handleScan(String rawValue) async {
    if (_processing) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      await HapticFeedback.mediumImpact();

      final childId = await _verifyQrKey(rawValue);
      if (childId == null) {
        if (!mounted) return;
        _showError(tr('key_012')); // "Error"
        await Future.delayed(const Duration(milliseconds: 600));
        await _controller.start();
        return;
      }

      final checkin = await _checkInChild(childId);
      if (checkin == null) {
        if (!mounted) return;
        _showError(tr('key_012'));
        await Future.delayed(const Duration(milliseconds: 600));
        await _controller.start();
        return;
      }

      if (!mounted) return;
      // Return the childId to the caller (keeps your existing contract)
      context.pop(childId);
    } catch (_) {
      if (!mounted) return;
      _showError(tr('key_012'));
      await Future.delayed(const Duration(milliseconds: 600));
      await _controller.start();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Verify the scanned QR key against Hasura.
  Future<String?> _verifyQrKey(String rawKey) async {
    if (rawKey.isEmpty) return null;

    const q = r'''
      query VerifyQr($k: String!) {
        child_profile_qr_keys(where: { qr_key: { _eq: $k } }, limit: 1) {
          child_id
        }
      }
    ''';

    try {
      final client = GraphProvider.of(context);
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'k': rawKey},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res.hasException) return null;

      final list = (res.data?['child_profile_qr_keys'] as List<dynamic>? ?? []);
      if (list.isEmpty) return null;
      final childId = list.first['child_id'];
      return childId is String ? childId : childId?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Create (or reuse) a check-in for the child (idempotent).
  Future<Map<String, dynamic>?> _checkInChild(String childId) async {
    final staffId = context.read<AppState>().profile?.id;
    if (staffId == null) return null;

    // 1) Find existing open check-in
    const qExisting = r'''
      query ExistingCheckin($cid: uuid!) {
        child_checkins(
          where: { child_id: { _eq: $cid }, check_out_time: { _is_null: true } }
          limit: 1
        ) {
          id
          check_in_time
        }
      }
    ''';

    final client = GraphProvider.of(context);

    try {
      final existingRes = await client.query(
        QueryOptions(
          document: gql(qExisting),
          variables: {'cid': childId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (existingRes.hasException) return null;

      final existing = (existingRes.data?['child_checkins'] as List<dynamic>? ?? []);
      if (existing.isNotEmpty) {
        final row = existing.first as Map<String, dynamic>;
        return {'id': row['id'], 'check_in_time': row['check_in_time']};
      }

      // 2) Insert a fresh check-in
      const mInsert = r'''
        mutation InsertCheckin($cid: uuid!, $uid: String!) {
          insert_child_checkins_one(object: {
            child_id: $cid,
            checked_in_by: $uid
          }) {
            id
            check_in_time
          }
        }
      ''';

      final insRes = await client.mutate(
        MutationOptions(
          document: gql(mInsert),
          variables: {'cid': childId, 'uid': staffId},
        ),
      );
      if (insRes.hasException) return null;

      final row = insRes.data?['insert_child_checkins_one']
          as Map<String, dynamic>?;
      if (row == null) return null;

      return {'id': row['id'], 'check_in_time': row['check_in_time']};
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr('key_314'))), // "Scan QR Code"
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_processing) return;
              final first = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
              final raw = first?.rawValue ?? '';
              if (raw.isEmpty) return;
              _handleScan(raw);
            },
          ),

          // Hint
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(217),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    tr('key_314_hint'), // "Center the QR code within the frame"
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // Error
          if (_error != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          if (_processing) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
