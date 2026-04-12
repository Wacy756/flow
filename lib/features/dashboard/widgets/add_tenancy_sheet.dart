import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

void showAddTenancySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddTenancySheet(),
  );
}

// ---------------------------------------------------------------------------

class _AddTenancySheet extends ConsumerStatefulWidget {
  const _AddTenancySheet();

  @override
  ConsumerState<_AddTenancySheet> createState() => _AddTenancySheetState();
}

class _AddTenancySheetState extends ConsumerState<_AddTenancySheet> {
  final _formKey = GlobalKey<FormState>();

  // Address fields
  final _postcodeCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _addr3Ctrl = TextEditingController();
  final _townCtrl = TextEditingController();
  double? _latitude;
  double? _longitude;

  // Property
  String? _propertyType;
  String _numBeds = '';
  String _numBaths = '';
  String _maxTenants = '';
  String? _furnishing;

  // Financials
  String _monthlyRent = '';
  String _weeklyRent = '';
  String? _depositType;
  String _depositAmount = '';
  String _minLength = '';
  DateTime _moveInDate = DateTime.now();

  // Invite
  final List<String> _emails = [];
  final _emailCtrl = TextEditingController();

  // Address lookup state
  List<Map<String, dynamic>> _suggestions = [];
  bool _lookingUp = false;
  bool _showSuggestions = false;
  String? _lookupError;

  bool _submitting = false;
  String? _submitError;
  String? _submitSuccess;

  static const _propertyTypes = [
    'Flat', 'House', 'Studio', 'Bungalow', 'Cottage', 'Other'
  ];
  static const _furnishingTypes = [
    'Furnished', 'Unfurnished', 'Part Furnished'
  ];
  static const _depositTypes = [
    'Tenancy Deposit', 'Zero Deposit', 'Other'
  ];

  @override
  void dispose() {
    _postcodeCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _addr3Ctrl.dispose();
    _townCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Address lookup — calls GetAddress.io directly
  // ---------------------------------------------------------------------------

  Future<void> _findAddress() async {
    final postcode = _postcodeCtrl.text.trim().toUpperCase();
    if (postcode.isEmpty) return;

    setState(() {
      _lookingUp = true;
      _lookupError = null;
      _showSuggestions = false;
      _suggestions = [];
    });

    try {
      final key = dotenv.env['GETADDRESS_API_KEY'] ?? '';
      final uri = Uri.parse(
          'https://api.getAddress.io/autocomplete/$postcode?api-key=$key&all=true');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('Address lookup failed');

      final body = json.decode(res.body) as Map<String, dynamic>;
      final suggestions =
          (body['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      setState(() {
        _suggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
        if (suggestions.isEmpty) _lookupError = 'No addresses found.';
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _lookingUp = false);
    }
  }

  Future<void> _selectAddress(Map<String, dynamic> suggestion) async {
    setState(() {
      _lookingUp = true;
      _showSuggestions = false;
    });

    try {
      final key = dotenv.env['GETADDRESS_API_KEY'] ?? '';
      final id = suggestion['id'] as String;
      final uri =
          Uri.parse('https://api.getAddress.io/get/$id?api-key=$key');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('Failed to fetch address');

      final addr = json.decode(res.body) as Map<String, dynamic>;

      // getAddress.io returns formatted_address as a list
      final formatted =
          (addr['formatted_address'] as List?)?.cast<String>() ?? [];

      setState(() {
        _addr1Ctrl.text = (addr['line_1'] as String?) ??
            (formatted.isNotEmpty ? formatted[0] : '');
        _addr2Ctrl.text = (addr['line_2'] as String?) ??
            (formatted.length > 1 ? formatted[1] : '');
        _addr3Ctrl.text = addr['line_3'] as String? ??
            (formatted.length > 2 ? formatted[2] : '');
        _townCtrl.text = addr['town_or_city'] as String? ??
            addr['town'] as String? ?? '';
        _postcodeCtrl.text =
            addr['postcode'] as String? ?? _postcodeCtrl.text;
        _latitude = (addr['latitude'] as num?)?.toDouble();
        _longitude = (addr['longitude'] as num?)?.toDouble();
      });
    } catch (e) {
      setState(() => _lookupError = e.toString());
    } finally {
      setState(() => _lookingUp = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Email invite helpers
  // ---------------------------------------------------------------------------

  void _addEmail() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _submitError = 'Please enter a valid email.');
      return;
    }
    if (_emails.contains(email)) {
      setState(() => _submitError = 'This email has already been added.');
      return;
    }
    setState(() {
      _emails.add(email);
      _emailCtrl.clear();
      _submitError = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emails.isEmpty && _emailCtrl.text.trim().isEmpty) {
      setState(() => _submitError = 'Add at least one tenant email.');
      return;
    }

    // Auto-add the typed email if not yet added
    final allEmails = [..._emails];
    final typed = _emailCtrl.text.trim().toLowerCase();
    if (typed.isNotEmpty && !allEmails.contains(typed)) {
      allEmails.add(typed);
    }

    setState(() {
      _submitting = true;
      _submitError = null;
      _submitSuccess = null;
    });

    final formData = <String, dynamic>{
      'postcode': _postcodeCtrl.text.trim().toUpperCase(),
      'address_line_1': _addr1Ctrl.text.trim(),
      'address_line_2': _addr2Ctrl.text.trim(),
      'address_line_3': _addr3Ctrl.text.trim(),
      'town': _townCtrl.text.trim(),
      'property_type': _propertyType,
      'num_bedrooms': _numBeds.isEmpty ? null : int.tryParse(_numBeds),
      'num_bathrooms': _numBaths.isEmpty ? null : int.tryParse(_numBaths),
      'max_tenants': _maxTenants.isEmpty ? null : int.tryParse(_maxTenants),
      'furnishing': _furnishing,
      'monthly_rent': _monthlyRent.isEmpty ? null : double.tryParse(_monthlyRent),
      'weekly_rent': _weeklyRent.isEmpty ? null : double.tryParse(_weeklyRent),
      'deposit_amount':
          _depositAmount.isEmpty ? null : _depositAmount.trim(),
      'min_tenancy_length':
          _minLength.isEmpty ? null : int.tryParse(_minLength),
      'move_in_date': DateFormat('yyyy-MM-dd').format(_moveInDate),
      'latitude': _latitude,
      'longitude': _longitude,
    };

    final ok = await ref
        .read(addTenancyProvider.notifier)
        .submit(formData: formData, tenantEmails: allEmails);

    final addState = ref.read(addTenancyProvider);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _submitSuccess =
            'Invitation${allEmails.length > 1 ? 's' : ''} sent!';
        _submitting = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() {
        _submitError = addState.error?.toString() ?? 'An error occurred.';
        _submitting = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Tenancy',
                      style: Theme.of(context).textTheme.displaySmall),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _Section('Property Address'),
                    _postcodeRow(),
                    if (_showSuggestions) _suggestionList(),
                    if (_lookupError != null)
                      _errorText(_lookupError!),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _addr1Ctrl,
                      label: 'Address Line 1',
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    _textField(
                        controller: _addr2Ctrl, label: 'Address Line 2'),
                    const SizedBox(height: 10),
                    _textField(
                        controller: _addr3Ctrl, label: 'Address Line 3'),
                    const SizedBox(height: 10),
                    _textField(
                        controller: _townCtrl, label: 'Town / City'),
                    const SizedBox(height: 20),

                    _Section('Property Details'),
                    _dropdown(
                      label: 'Property Type',
                      value: _propertyType,
                      items: _propertyTypes,
                      onChanged: (v) =>
                          setState(() => _propertyType = v),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _numberField(
                              label: 'Bedrooms',
                              value: _numBeds,
                              onChanged: (v) =>
                                  setState(() => _numBeds = v))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(
                              label: 'Bathrooms',
                              value: _numBaths,
                              onChanged: (v) =>
                                  setState(() => _numBaths = v))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(
                              label: 'Max Tenants',
                              value: _maxTenants,
                              onChanged: (v) =>
                                  setState(() => _maxTenants = v))),
                    ]),
                    const SizedBox(height: 10),
                    _dropdown(
                      label: 'Furnishing',
                      value: _furnishing,
                      items: _furnishingTypes,
                      onChanged: (v) =>
                          setState(() => _furnishing = v),
                    ),
                    const SizedBox(height: 20),

                    _Section('Financials'),
                    Row(children: [
                      Expanded(
                          child: _numberField(
                              label: 'Monthly Rent (£)',
                              value: _monthlyRent,
                              decimal: true,
                              onChanged: (v) =>
                                  setState(() => _monthlyRent = v))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _numberField(
                              label: 'Weekly Rent (£)',
                              value: _weeklyRent,
                              decimal: true,
                              onChanged: (v) =>
                                  setState(() => _weeklyRent = v))),
                    ]),
                    const SizedBox(height: 10),
                    _dropdown(
                      label: 'Deposit Type',
                      value: _depositType,
                      items: _depositTypes,
                      onChanged: (v) =>
                          setState(() => _depositType = v),
                    ),
                    const SizedBox(height: 10),
                    _numberField(
                        label: 'Deposit Amount (£)',
                        value: _depositAmount,
                        decimal: true,
                        onChanged: (v) =>
                            setState(() => _depositAmount = v)),
                    const SizedBox(height: 20),

                    _Section('Tenancy Terms'),
                    _numberField(
                        label: 'Min Tenancy Length (months)',
                        value: _minLength,
                        onChanged: (v) =>
                            setState(() => _minLength = v)),
                    const SizedBox(height: 10),
                    _dateField(),
                    const SizedBox(height: 20),

                    _Section('Invite Tenants'),
                    _emailInviteRow(),
                    const SizedBox(height: 10),
                    if (_emails.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _emails
                            .map((e) => _EmailChip(
                                  email: e,
                                  onRemove: () =>
                                      setState(() => _emails.remove(e)),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 20),

                    // Error / success
                    if (_submitError != null)
                      _errorText(_submitError!),
                    if (_submitSuccess != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_submitSuccess!,
                            style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 12),

                    // Submit
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            )
                          : const Text('Send Invitations'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper builders
  // ---------------------------------------------------------------------------

  Widget _postcodeRow() => Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _postcodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Postcode *',
                hintText: 'e.g. SW1A 1AA',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _lookingUp ? null : _findAddress,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: _lookingUp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white)))
                : const Text('Find',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      );

  Widget _suggestionList() => Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1),
          itemBuilder: (_, i) => ListTile(
            title: Text(
              _suggestions[i]['address'] as String? ?? '',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => _selectAddress(_suggestions[i]),
            dense: true,
          ),
        ),
      );

  Widget _emailInviteRow() => Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Tenant Email', hintText: 'tenant@example.com'),
              onFieldSubmitted: (_) => _addEmail(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _addEmail,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    bool required = false,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      );

  Widget _numberField({
    required String label,
    required String value,
    required void Function(String) onChanged,
    bool decimal = false,
  }) =>
      TextFormField(
        initialValue: value,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) =>
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      );

  Widget _dateField() => InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _moveInDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) setState(() => _moveInDate = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Move-in Date',
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            DateFormat('d MMMM yyyy').format(_moveInDate),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );

  Widget _errorText(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(msg,
            style:
                TextStyle(color: Colors.red.shade700, fontSize: 13)),
      );
}

// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class _EmailChip extends StatelessWidget {
  final String email;
  final VoidCallback onRemove;

  const _EmailChip({required this.email, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(email,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close,
                  size: 14, color: AppTheme.primaryDark),
            ),
          ],
        ),
      );
}
