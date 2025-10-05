// File: lib/screens/admin/event_form_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/home_shell.dart' show api;

class EventFormPage extends StatefulWidget {
  final int? eventId; // null => create, non-null => edit
  const EventFormPage({super.key, this.eventId});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // ISO string
  final _buildingCtrl = TextEditingController(); // optional

  bool _loading = false;
  String? _banner;
  bool _isError = false;

  final _secure = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _loadEvent(widget.eventId!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _buildingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvent(int id) async {
    setState(() {
      _loading = true;
      _banner = null;
      _isError = false;
    });
    try {
      final res = await api.get('/api/admin/events/$id');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final ev = (data['data'] is Map) ? data['data'] as Map : data;
        _titleCtrl.text = (ev['title'] ?? '').toString();
        _descCtrl.text = (ev['description'] ?? '').toString();
        _dateCtrl.text = (ev['eventDate'] ?? '').toString();
        _buildingCtrl.text = (ev['buildingNumber'] ?? '').toString();
      } else {
        throw Exception('Failed to load event');
      }
    } on DioException catch (e) {
      setState(() {
        _banner = e.response?.data?.toString() ?? e.message ?? 'Failed to load';
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _banner = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _payload() {
    final p = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'eventDate': _dateCtrl.text.trim(), // e.g., 2025-10-10T18:30:00
    };
    final b = _buildingCtrl.text.trim();
    if (b.isNotEmpty) p['buildingNumber'] = b;
    return p;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _banner = null;
      _isError = false;
    });

    try {
      final token = await _secure.read(key: 'access_token');
      if (token == null || token.isEmpty) throw Exception('Not authenticated');

      final isEdit = widget.eventId != null;
      final path = isEdit
          ? '/api/admin/events${widget.eventId != null ? '/${widget.eventId}' : ''}'
          : '/api/admin/events';

      final Options opts = Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      Response res;
      if (isEdit) {
        res = await api.put(path, data: _payload(), options: opts);
      } else {
        res = await api.post(path, data: _payload(), options: opts);
      }

      final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
      final msg = res.data is Map
          ? ((res.data['message'] ?? (isEdit ? 'Event updated' : 'Event created')).toString())
          : (isEdit ? 'Event updated' : 'Event created');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      setState(() {
        _banner = msg;
        _isError = !ok;
      });

      if (ok && !isEdit) {
        _form.currentState?.reset();
        _buildingCtrl.clear();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response?.data['message'] ?? 'Failed').toString())
          : (e.message ?? 'Failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      const msg = 'Failed';
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(msg)));
      setState(() {
        _banner = msg;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Helper to pick date and time, then write ISO string to _dateCtrl
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _parseExistingDate() ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) return;

    final initialTime = TimeOfDay.fromDateTime(initialDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Format to ISO: YYYY-MM-DDTHH:mm:ss
    final iso = _toIsoStringSeconds(combined);
    setState(() {
      _dateCtrl.text = iso;
    });
  }

  DateTime? _parseExistingDate() {
    final s = _dateCtrl.text.trim();
    // Try parsing if already in ISO, else null
    try {
      if (s.isEmpty) return null;
      // Accept with or without seconds; normalize if needed
      final normalized = s.contains('T') && s.length == 19
          ? s
          : s.contains('T') && s.length >= 16
              ? '${s.padRight(19, '0')}'
              : s;
      return DateTime.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _toIsoStringSeconds(DateTime dt) {
    // Without timezone suffix
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${_two(dt.month)}-'
        '${_two(dt.day)}T'
        '${_two(dt.hour)}:'
        '${_two(dt.minute)}:'
        '${_two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.eventId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Event' : 'Add Event'),
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
                      if (_banner != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _isError ? cs.errorContainer : cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isError ? cs.error : cs.primary),
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
                      Text(
                        'Event details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),

                      _textField(
                        context,
                        label: 'Title',
                        controller: _titleCtrl,
                        icon: Icons.title_outlined,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (s.length > 150) return 'Max 150 chars';
                          return null;
                        },
                      ),
                      _textField(
                        context,
                        label: 'Description',
                        controller: _descCtrl,
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (s.length > 500) return 'Max 500 chars';
                          return null;
                        },
                      ),

                      // Date-time with picker button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _dateCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Event date (ISO)',
                            hintText: 'YYYY-MM-DDTHH:mm:ss',
                            prefixIcon: Icon(Icons.event, color: cs.onSurfaceVariant),
                            suffixIcon: IconButton(
                              tooltip: 'Pick date & time',
                              icon: const Icon(Icons.calendar_month),
                              onPressed: _loading ? null : _pickDateTime,
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Required';
                            final ok = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$').hasMatch(s);
                            if (!ok) return 'Use ISO format e.g. 2025-10-10T18:30:00';
                            return null;
                          },
                          onTap: _loading ? null : _pickDateTime,
                        ),
                      ),

                      _textField(
                        context,
                        label: 'Building number (optional)',
                        controller: _buildingCtrl,
                        icon: Icons.domain_outlined,
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: _loading
                              ? SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2),
                                )
                              : Icon(isEdit ? Icons.save : Icons.add),
                          label: Text(_loading ? (isEdit ? 'Saving...' : 'Creating...') : (isEdit ? 'Save changes' : 'Create event')),
                          onPressed: _loading ? null : _submit,
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

  Widget _textField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
      ),
    );
  }
}
