// File: lib/features/home/incident_report_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../app_state.dart';

class IncidentReportButton extends StatelessWidget {
  const IncidentReportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade800,
          side: BorderSide(color: Colors.red.shade200, width: 1.4),
          backgroundColor:
              Colors.red.shade50.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => _openSheet(context),
        icon: const Icon(Icons.shield_outlined, size: 24),
        label: const Text(
          'Report Security Incident',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _IncidentReportSheet(),
    );
  }

  static const String _insertMutation = r'''
    mutation InsertIncidentReport($location: String!, $description: String!, $user_id: String!) {
      insert_incident_reports_one(object: {
        location: $location,
        description: $description,
        user_id: $user_id
      }) { id created_at }
    }
  ''';
}

class _IncidentReportSheet extends StatefulWidget {
  const _IncidentReportSheet();

  @override
  State<_IncidentReportSheet> createState() =>
      _IncidentReportSheetState();
}

class _IncidentReportSheetState
    extends State<_IncidentReportSheet> {
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Icon(
                Icons.report_problem_rounded,
                color: Colors.red.shade800,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Security Incident',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Provide details to alert the security team immediately.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),

          const SizedBox(height: 24),

          // Location Field
          TextField(
            controller: _locationController,
            enabled: !_isSubmitting,
            decoration: _inputDecoration(
              label: 'Specific Location',
              hint: 'Parking Lot, Main Lobby...',
              icon: Icons.location_on_outlined,
            ),
          ),

          const SizedBox(height: 16),

          // Description Field
          TextField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Incident Description',
              hint: 'What is happening?',
            ),
          ),

          const SizedBox(height: 32),

          // Submit Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Colors.red.shade300,
              padding:
                  const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _isSubmitting
                ? null
                : () => _submit(appState, userId),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isSubmitting
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      key: ValueKey('text'),
                      'Send Urgent Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor:
          Colors.grey.shade100.withValues(alpha: 0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _submit(
      AppState appState, String? userId) async {
    if (_locationController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() => _isSubmitting = true);

    try {
      final result = await appState.client.mutate(
        MutationOptions(
          document:
              gql(IncidentReportButton._insertMutation),
          variables: {
            'location':
                _locationController.text.trim(),
            'description':
                _descriptionController.text.trim(),
            'user_id': userId,
          },
        ),
      );

      if (result.hasException) {
        throw result.exception!;
      }

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Report sent to Security Team'),
            backgroundColor:
                Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Error sending report'),
            backgroundColor:
                Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
