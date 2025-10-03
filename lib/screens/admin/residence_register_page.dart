// File: lib/screens/admin/residence_register_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Reuse shared Dio from HomeShell
import 'package:ananta_app/screens/home_shell.dart' show api;

class ResidenceRegisterPage extends StatefulWidget {
  const ResidenceRegisterPage({super.key});

  @override
  State<ResidenceRegisterPage> createState() => _ResidenceRegisterPageState();
}

class _ResidenceRegisterPageState extends State<ResidenceRegisterPage> {
  final _form = GlobalKey<FormState>();

  // Controllers
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _resNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Dropdown selections
  String? _selectedBuilding;
  String? _selectedFlat;

  // Static dropdown options (swap to API-driven if needed)
  static const List<String> kBuildingOptions = <String>[
    'A1','A2','A3','A4','A5','A6','A7','A8',
  ];
  static const List<String> kFlatOptions = <String>[
    '101','102','103','201','202','203','301','302','303',
  ];

  bool _submitting = false;
  bool _showPassword = false;
  String? _banner;
  bool _isError = false;

  final _secure = const FlutterSecureStorage();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _mobileCtrl.dispose();
    _resNameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "username": _usernameCtrl.text.trim(),
      "password": _passwordCtrl.text,
      "mobileNo": _mobileCtrl.text.trim(),
      "residenceName": _resNameCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
      "city": _cityCtrl.text.trim(),
      "state": _stateCtrl.text.trim(),
      "pincode": _pincodeCtrl.text.trim(),
      if (_selectedBuilding != null && _selectedBuilding!.isNotEmpty)
        "buildingNumber": _selectedBuilding,
      if (_selectedFlat != null && _selectedFlat!.isNotEmpty)
        "flatNumber": _selectedFlat,
    };
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _banner = null;
      _isError = false;
    });
    FocusScope.of(context).unfocus();

    try {
      final adminToken = await _secure.read(key: 'admin_token');

      final res = await api.post(
        '/api/admin/residences/register-resident',
        data: _buildPayload(),
        options: Options(
          headers: {
            if (adminToken != null && adminToken.isNotEmpty)
              'Authorization': 'Bearer $adminToken',
          },
          contentType: Headers.jsonContentType,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );

      final data = res.data is Map ? res.data as Map : {};
      final statusOk = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
      final hasSuccessFlag = data['success'] == true;
      final hasId = data['id'] != null || data['residentId'] != null || (data['data'] is Map && data['data']['id'] != null);
      final ok = statusOk || hasSuccessFlag || hasId;

      final msg = (data['message'] ??
                  data['msg'] ??
                  (ok ? 'Resident registered successfully' : 'Registration failed'))
              .toString();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      setState(() {
        _banner = msg;
        _isError = !ok;
      });

      if (ok) {
        _form.currentState?.reset();
        _passwordCtrl.clear();
        _selectedBuilding = null;
        _selectedFlat = null;
        setState(() {});
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? e.response?.data['error'] ?? 'Registration failed').toString())
          : (e.message ?? 'Registration failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } catch (_) {
      if (!mounted) return;
      const msg = 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(msg)));
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Resident'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branding row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.primary.withOpacity(0.12),
                            child: Icon(Icons.apartment, color: cs.primary),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Resident profile details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_banner != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _isError ? cs.errorContainer : cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isError ? cs.error : cs.primary,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isError ? Icons.error_outline : Icons.check_circle_outline,
                                color: _isError ? cs.onErrorContainer : cs.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _banner!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: _isError ? cs.onErrorContainer : cs.onPrimaryContainer,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Grid-like layout for larger screens
                      LayoutBuilder(
                        builder: (context, box) {
                          final isWide = box.maxWidth >= 560;
                          return Wrap(
                            runSpacing: 12,
                            spacing: 12,
                            children: [
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _textField(
                                  label: 'Username',
                                  controller: _usernameCtrl,
                                  icon: Icons.person_outline,
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Required';
                                    if (s.length < 3) return 'Min 3 chars';
                                    if (s.length > 50) return 'Max 50 chars';
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _passwordField(cs),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _textField(
                                  label: 'Mobile (10 digits)',
                                  controller: _mobileCtrl,
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Required';
                                    if (!RegExp(r'^\d{10}$').hasMatch(s)) return 'Enter 10 digits';
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _textField(
                                  label: 'Residence name',
                                  controller: _resNameCtrl,
                                  icon: Icons.badge_outlined,
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Required';
                                    if (s.length > 100) return 'Max 100 chars';
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                width: box.maxWidth,
                                child: _textField(
                                  label: 'Address',
                                  controller: _addressCtrl,
                                  icon: Icons.location_on_outlined,
                                  maxLines: 2,
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Required';
                                    if (s.length > 200) return 'Max 200 chars';
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 24) / 3 : box.maxWidth,
                                child: _textField(
                                  label: 'City',
                                  controller: _cityCtrl,
                                  icon: Icons.location_city_outlined,
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 24) / 3 : box.maxWidth,
                                child: _textField(
                                  label: 'State',
                                  controller: _stateCtrl,
                                  icon: Icons.map_outlined,
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 24) / 3 : box.maxWidth,
                                child: _textField(
                                  label: 'Pincode',
                                  controller: _pincodeCtrl,
                                  icon: Icons.markunread_mailbox_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Required';
                                    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter 6 digits';
                                    return null;
                                  },
                                ),
                              ),

                              // Building dropdown
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _dropdownField<String>(
                                  label: 'Building number',
                                  icon: Icons.domain_outlined,
                                  value: _selectedBuilding,
                                  items: kBuildingOptions,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBuilding = val;
                                      _selectedFlat = null; // reset dependent field
                                    });
                                  },
                                  validator: (val) {
                                    if ((val ?? '').toString().isEmpty) return 'Required';
                                    return null;
                                  },
                                ),
                              ),

                              // Flat dropdown
                              _fieldBox(
                                width: isWide ? (box.maxWidth - 12) / 2 : box.maxWidth,
                                child: _dropdownField<String>(
                                  label: 'Flat number',
                                  icon: Icons.home_outlined,
                                  value: _selectedFlat,
                                  items: kFlatOptions,
                                  onChanged: (val) => setState(() => _selectedFlat = val),
                                  validator: (val) {
                                    if ((val ?? '').toString().isEmpty) return 'Required';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: _submitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: cs.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(_submitting ? 'Registering...' : 'Register resident'),
                          onPressed: _submitting ? null : _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ADDED: helper to size fields uniformly in the Wrap grid
  Widget _fieldBox({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  Widget _passwordField(ColorScheme cs) {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: !_showPassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
        suffixIcon: IconButton(
          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.error, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (v) {
        final s = (v ?? '');
        if (s.isEmpty) return 'Required';
        if (s.length < 6) return 'Min 6 chars';
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.error, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: validator,
      textInputAction: TextInputAction.next,
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
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
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
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.error, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down),
    );
  }
}
