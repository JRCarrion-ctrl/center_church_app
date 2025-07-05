import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/widgets/primary_button.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('donations')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      _history.clear();
      for (var d in response) {
        _history.add(DonationRecord(
          amount: (d['amount'] as num).toDouble(),
          fund: d['fund'] as String,
          date: DateTime.parse(d['created_at']),
        ));
      }
    });
  }

  Future<void> _saveDonationToSupabase(DonationRecord record) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('donations').insert({
      'user_id': user.id,
      'amount': record.amount,
      'fund': record.fund,
      'is_recurring': _isRecurring,
    });
  }

  void _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thank you!'),
        content: const Text('Your donation has been received.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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

    await _saveDonationToSupabase(newRecord);

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
        title: const Text('Give'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Give'),
            Tab(text: 'History'),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedFund,
                decoration: const InputDecoration(labelText: 'Fund'),
                items: mockFunds
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedFund = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (USD)'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Make this a recurring gift'),
                value: _isRecurring,
                onChanged: (val) => setState(() => _isRecurring = val),
              ),
              const Divider(),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Card Number'),
                validator: (value) =>
                    (value == null || value.length < 12) ? 'Invalid' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(labelText: 'MM/YY'),
                      validator: (value) =>
                          (value == null || value.length < 4) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvcController,
                      decoration: const InputDecoration(labelText: 'CVC'),
                      validator: (value) =>
                          (value == null || value.length < 3) ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                title: _isSubmitting ? 'Submitting...' : 'Give Now',
                onTap: _isSubmitting ? () {} : _submitDonation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationHistory() {
    if (_history.isEmpty) {
      return const Center(child: Text('No donations yet.'));
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
