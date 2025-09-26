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
  final _flatCtrl = TextEditingController();
  final _bldgCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _guestCtrl.dispose();
    _mobileCtrl.dispose();
    _flatCtrl.dispose();
    _bldgCtrl.dispose();
    _purposeCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    final flat = _flatCtrl.text.trim();
    final bldg = _bldgCtrl.text.trim();
    final purpose = _purposeCtrl.text.trim();
    final vehicle = _vehicleCtrl.text.trim();
    return {
      "guestName": _guestCtrl.text.trim(),
      "mobile": _mobileCtrl.text.trim(),
      if (flat.isNotEmpty) "flatNumber": flat,
      if (bldg.isNotEmpty) "buildingNumber": bldg,
      if (purpose.isNotEmpty) "visitPurpose": purpose,
      if (vehicle.isNotEmpty) "vehicleDetails": vehicle,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed')));
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
                _field(
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
                _field(
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
                _field('Flat number', _flatCtrl, Icons.home_outlined, textInputAction: TextInputAction.next),
                _field('Building number', _bldgCtrl, Icons.domain_outlined, textInputAction: TextInputAction.next),
                _field('Visit purpose', _purposeCtrl, Icons.event_note_outlined, textInputAction: TextInputAction.next),
                _field('Vehicle details', _vehicleCtrl, Icons.directions_car_outlined, textInputAction: TextInputAction.done),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: _submitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: scheme.onPrimary, strokeWidth: 2),
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

  Widget _field(
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
}
