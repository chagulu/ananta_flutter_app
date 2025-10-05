// File: lib/screens/admin/event_list_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ananta_app/screens/home_shell.dart' show api;
import 'admin/event_form_page.dart';
import '../screens/event_view_page.dart';

class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final _secure = const FlutterSecureStorage();
  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
    });
    try {
      // Admin listing (authorized)
      final token = await _secure.read(key: 'access_token');
      final res = await api.get(
        '/api/admin/events',
        options: Options(headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        }),
      );
      if (res.statusCode == 200) {
        final data = res.data;
        final list = (data is Map && data['data'] is List)
            ? (data['data'] as List)
            : (data is List ? data : const []);
        setState(() {
          _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        throw Exception('Failed (${res.statusCode})');
      }
    } on DioException catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.response?.data?.toString() ?? e.message ?? 'Unknown error';
      });
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EventFormPage()),
    ).then((_) => _fetch());
  }

  void _openEdit(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventFormPage(eventId: id)),
    ).then((_) => _fetch());
  }

  void _openView(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventViewPage(id: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error
            ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
            : _items.isEmpty
                ? const Center(child: Text('No events'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      final id = it['id'] ?? it['eventId'];
                      return ListTile(
                        leading: const Icon(Icons.event),
                        title: Text((it['title'] ?? '').toString()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (it['description'] != null) Text(it['description'].toString()),
                            if (it['eventDate'] != null) Text(it['eventDate'].toString()),
                            if (it['buildingNumber'] != null) Text('Building: ${it['buildingNumber']}'),
                          ],
                        ),
                        onTap: id == null ? null : () => _openView(int.tryParse(id.toString()) ?? 0),
                        trailing: id == null
                            ? null
                            : IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openEdit(int.tryParse(id.toString()) ?? 0),
                              ),
                      );
                    },
                  );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Add event',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _fetch, child: body is ScrollView ? body : ListView(children: [body])),
    );
  }
}
