import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/dashboard_providers.dart';

void showAddPropertySheet(BuildContext context) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddPropertySheet(),
  );
}

class _AddPropertySheet extends ConsumerStatefulWidget {
  const _AddPropertySheet();

  @override
  ConsumerState<_AddPropertySheet> createState() => _AddPropertySheetState();
}

class _AddPropertySheetState extends ConsumerState<_AddPropertySheet> {
  final _formKey = GlobalKey<FormState>();
  final _line1Ctrl    = TextEditingController();
  final _line2Ctrl    = TextEditingController();
  final _townCtrl     = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  String _propertyType = 'house';
  int _bedrooms = 2;
  bool _saving = false;
  bool _declared = false;
  String? _error;

  static const _types = ['flat', 'house', 'bungalow', 'maisonette', 'hmo', 'studio'];
  static const _typeLabels = {
    'flat': 'Flat',
    'house': 'House',
    'bungalow': 'Bungalow',
    'maisonette': 'Maisonette',
    'hmo': 'HMO',
    'studio': 'Studio',
  };

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _townCtrl.dispose();
    _postcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_declared) return;
    setState(() { _saving = true; _error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final postcode = _postcodeCtrl.text.trim().toUpperCase();
      final line1 = _line1Ctrl.text.trim();

      // Insert property
      final result = await supabase.from('properties').insert({
        'landlord_id':   user.id,
        'address_line_1': line1,
        if (_line2Ctrl.text.trim().isNotEmpty) 'address_line_2': _line2Ctrl.text.trim(),
        if (_townCtrl.text.trim().isNotEmpty)  'town': _townCtrl.text.trim(),
        'postcode':      postcode,
        'property_type': _propertyType,
        'num_bedrooms':  _bedrooms,
      }).select('id').single();

      final propertyId = result['id'] as String;

      // Auto-fetch EPC in background (don't block on it)
      ref.read(lookupEpcProvider.notifier).lookup(
        postcode: postcode,
        address: line1,
        propertyId: propertyId,
      );

      ref.invalidate(landlordPropertiesProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_home_rounded,
                      color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Add Property',
                      style: TextStyle(
                        color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: p.card, shape: BoxShape.circle,
                      border: Border.all(color: p.border)),
                    child: Icon(Icons.close_rounded, size: 16, color: p.sub),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // Address line 1
              _label('Address line 1 *', p),
              const SizedBox(height: 6),
              _FormField(
                ctrl: _line1Ctrl,
                hint: 'e.g. 12 Example Street',
                p: p,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Address line 2
              _label('Address line 2', p),
              const SizedBox(height: 6),
              _FormField(ctrl: _line2Ctrl, hint: 'Flat, floor, etc. (optional)', p: p),
              const SizedBox(height: 14),

              // Town + postcode
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Town / City', p),
                  const SizedBox(height: 6),
                  _FormField(ctrl: _townCtrl, hint: 'London', p: p),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Postcode *', p),
                  const SizedBox(height: 6),
                  _FormField(
                    ctrl: _postcodeCtrl,
                    hint: 'SW1A 1AA',
                    p: p,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ])),
              ]),
              const SizedBox(height: 20),

              // Property type
              _label('Property type', p),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _types.map((t) => GestureDetector(
                  onTap: () => setState(() => _propertyType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _propertyType == t
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                          : p.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _propertyType == t
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                            : p.border,
                        width: _propertyType == t ? 1.5 : 1,
                      ),
                    ),
                    child: Text(_typeLabels[t] ?? t,
                        style: TextStyle(
                          color: _propertyType == t
                              ? const Color(0xFF3B82F6)
                              : p.sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Bedrooms
              _label('Bedrooms', p),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() { if (_bedrooms > 1) _bedrooms--; }),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: p.bg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border)),
                    child: Icon(Icons.remove_rounded, size: 16, color: p.sub),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_bedrooms',
                      style: TextStyle(
                        color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: () => setState(() { if (_bedrooms < 20) _bedrooms++; }),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: p.bg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border)),
                    child: Icon(Icons.add_rounded, size: 16, color: p.sub),
                  ),
                ),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ),
              ],

              const SizedBox(height: 24),

              // Self-declaration
              GestureDetector(
                onTap: () => setState(() => _declared = !_declared),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _declared
                            ? const Color(0xFF3B82F6)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _declared
                              ? const Color(0xFF3B82F6)
                              : p.border,
                          width: 1.5,
                        ),
                      ),
                      child: _declared
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I confirm I have the legal right to let this property (as owner, leaseholder with subletting rights, or authorised agent)',
                        style: TextStyle(
                          color: p.sub, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_saving ? 'Adding…' : 'Add Property'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _saving || !_declared ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, AbodePalette p) => Text(text,
      style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600));
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final AbodePalette p;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _FormField({
    required this.ctrl,
    required this.hint,
    required this.p,
    this.textCapitalization = TextCapitalization.words,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(color: p.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.muted, fontSize: 13),
        filled: true,
        fillColor: p.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}
