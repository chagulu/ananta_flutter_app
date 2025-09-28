import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

// Import shared api and the list page (no stubs!)
import 'package:ananta_app/screens/home_shell.dart' show api;
import 'package:ananta_app/screens/visitor_list.dart';

class ManualEntryPage extends StatefulWidget {
  const ManualEntryPage({super.key});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final _form = GlobalKey<FormState>();
  final _guestCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  bool _submitting = false;

  // Dropdown state
  String? _selectedFlat;
  String? _selectedBuilding;

  // Static options as requested
  static const List<String> kFlatOptions = <String>[
    'A1','A2','B1','B2','C1','C2','D1','D2','E1','E2',
  ];

  static const List<String> kBuildingOptions = <String>[
    'A1','A2','A3','A4','A5','A6','A7','A8',
  ];

  @override
  void dispose() {
    _guestCtrl.dispose();
    _mobileCtrl.dispose();
    _purposeCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "guestName": _guestCtrl.text.trim(),
      "mobile": _mobileCtrl.text.trim(),
      if (_selectedFlat != null && _selectedFlat!.isNotEmpty)
        "flatNumber": _selectedFlat,
      if (_selectedBuilding != null && _selectedBuilding!.isNotEmpty)
        "buildingNumber": _selectedBuilding,
      if (_purposeCtrl.text.trim().isNotEmpty)
        "visitPurpose": _purposeCtrl.text.trim(),
      if (_vehicleCtrl.text.trim().isNotEmpty)
        "vehicleDetails": _vehicleCtrl.text.trim(),
    };
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();

    try {
      final res = await api.post('/api/visitor/entry', data: _buildPayload());
      final data = res.data is Map ? res.data as Map : {};
      final ok = data['success'] == true;
      final msg = (data['message'] ?? 'Created').toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VisitorListPage()),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed').toString())
          : (e.message ?? 'Failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(
              children: [
                _textField(
                  'Guest name',
                  _guestCtrl,
                  Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Required';
                    if (s.length > 100) return 'Max 100 chars';
                    return null;
                  },
                ),
                _textField(
                  'Mobile (10 digits)',
                  _mobileCtrl,
                  Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Required';
                    if (!RegExp(r'^\d{10}$').hasMatch(s)) return 'Enter 10 digits';
                    return null;
                  },
                ),

                // Flat number dropdown
                _dropdownField<String>(
                  label: 'Flat number',
                  icon: Icons.home_outlined,
                  value: _selectedFlat,
                  items: kFlatOptions,
                  onChanged: (val) => setState(() => _selectedFlat = val),
                  validator: (val) {
                    // Make selection optional; set to Required if needed
                    return null;
                  },
                ),

                // Building number dropdown
                _dropdownField<String>(
                  label: 'Building number',
                  icon: Icons.domain_outlined,
                  value: _selectedBuilding,
                  items: kBuildingOptions,
                  onChanged: (val) => setState(() => _selectedBuilding = val),
                  validator: (val) {
                    // Make selection optional; set to Required if needed
                    return null;
                  },
                ),

                _textField(
                  'Visit purpose',
                  _purposeCtrl,
                  Icons.event_note_outlined,
                  textInputAction: TextInputAction.next,
                ),
                _textField(
                  'Vehicle details',
                  _vehicleCtrl,
                  Icons.directions_car_outlined,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: _submitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: scheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_submitting ? 'Submitting...' : 'Create entry'),
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController c,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.error, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ))
            .toList(),
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.error, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}
