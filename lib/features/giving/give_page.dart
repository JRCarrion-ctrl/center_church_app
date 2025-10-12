// File: lib/features/give/give_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
// If you don't already import intl elsewhere, uncomment the next line.
// import 'package:intl/intl.dart';

import '../../shared/widgets/primary_button.dart';
import '../../../app_state.dart';

class GivePage extends StatefulWidget {
  const GivePage({super.key});

  @override
  State<GivePage> createState() => _GivePageState();
}

class DonationRecord {
  final DateTime date;
  final double amount;
  final String fund;

  DonationRecord({required this.date, required this.amount, required this.fund});
}

class _GivePageState extends State<GivePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final currencyFormatter = NumberFormat.simpleCurrency(locale: 'en_US');

  String _selectedFund = mockFunds.first;
  bool _isRecurring = false;
  bool _isSubmitting = false;

  static const List<String> mockFunds = [
    'Tithes & Offerings',
    'Missions',
    'Building Fund',
    'Youth Ministry',
  ];

  final List<DonationRecord> _history = [];

  late TabController _tabController;

  // GraphQL wiring
  GraphQLClient? _gql;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gql ??= GraphQLProvider.of(context).value;
    _userId ??= context.read<AppState>().profile?.id;

    // Load history once we have user info
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    if (_gql == null || _userId == null) return;

    const q = r'''
      query DonationHistory($uid: String!) {
        donations(
          where: { user_id: { _eq: $uid } }
          order_by: { created_at: desc }
        ) {
          amount
          fund
          created_at
        }
      }
    ''';

    final res = await _gql!.query(
      QueryOptions(
        document: gql(q),
        variables: {'uid': _userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (res.hasException) {
      // You could log res.exception here
      return;
    }

    final rows = (res.data?['donations'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    setState(() {
      _history
        ..clear()
        ..addAll(rows.map((d) => DonationRecord(
              amount: (d['amount'] as num).toDouble(),
              fund: d['fund'] as String,
              date: DateTime.parse(d['created_at'] as String),
            )));
    });
  }

  Future<void> _saveDonation(DonationRecord record) async {
    if (_gql == null || _userId == null) return;

    const m = r'''
      mutation InsertDonation($user_id: uuid!, $amount: numeric!, $fund: String!, $is_recurring: Boolean!) {
        insert_donations_one(object: {
          user_id: $user_id,
          amount: $amount,
          fund: $fund,
          is_recurring: $is_recurring
        }) { id }
      }
    ''';

    final res = await _gql!.mutate(
      MutationOptions(
        document: gql(m),
        variables: {
          'user_id': _userId,
          'amount': record.amount,
          'fund': record.fund,
          'is_recurring': _isRecurring,
        },
      ),
    );

    if (res.hasException) {
      // surface a friendly error, but don't crash the flow
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_043".tr())), // reuse generic error
        );
      }
    }
  }

  void _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Simulate payment processing (replace with your real gateway)
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_044".tr()),
        content: Text("key_045".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("key_046".tr()),
          ),
        ],
      ),
    );

    final newRecord = DonationRecord(
      date: DateTime.now(),
      amount: double.tryParse(_amountController.text) ?? 0.0,
      fund: _selectedFund,
    );

    setState(() {
      _history.insert(0, newRecord);
    });

    await _saveDonation(newRecord);

    _formKey.currentState!.reset();
    _amountController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _cvcController.clear();
    setState(() {
      _selectedFund = mockFunds.first;
      _isRecurring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_047".tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "key_047".tr()),
            Tab(text: "key_047a".tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGiveForm(),
          _buildDonationHistory(),
        ],
      ),
    );
  }

  Widget _buildGiveForm() {
    final loggedIn = _userId != null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AbsorbPointer(
        absorbing: !loggedIn,
        child: Opacity(
          opacity: loggedIn ? 1 : 0.6,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFund,
                    decoration: InputDecoration(labelText: "key_047b".tr()),
                    items: mockFunds
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedFund = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "key_047c".tr()),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? "key_047d".tr() : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text("key_048".tr()),
                    value: _isRecurring,
                    onChanged: (val) => setState(() => _isRecurring = val),
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "key_048a".tr()),
                    validator: (value) =>
                        (value == null || value.length < 12) ? "key_048b".tr() : null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(labelText: 'MM/YY'),
                          validator: (value) =>
                              (value == null || value.length < 4) ? "key_048b".tr() : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _cvcController,
                          decoration: const InputDecoration(labelText: 'CVC'),
                          validator: (value) =>
                              (value == null || value.length < 3) ? "key_048b".tr() : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    title: _isSubmitting ? "key_048c".tr() : "key_048d".tr(),
                    onTap: _isSubmitting
                        ? () {}
                        : (loggedIn ? _submitDonation : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("key_037".tr())), // "Please log in" (same key used elsewhere)
                            );
                          }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationHistory() {
    if (_history.isEmpty) {
      return Center(child: Text("key_049".tr()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final donation = _history[index];
        return Card(
          child: ListTile(
            title: Text('${currencyFormatter.format(donation.amount)} to ${donation.fund}'),
            subtitle: Text(DateFormat.yMMMMd().format(donation.date)),
          ),
        );
      },
    );
  }
}
