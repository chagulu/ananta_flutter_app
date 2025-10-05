// File: lib/screens/event_view_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class EventViewPage extends StatefulWidget {
  final int id;
  const EventViewPage({super.key, required this.id});

  @override
  State<EventViewPage> createState() => _EventViewPageState();
}

class _EventViewPageState extends State<EventViewPage> {
  late final Dio _dio;
  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  Map<String, dynamic>? _event;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(
      baseUrl: "http://10.0.2.2:8080",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
    });
    try {
      final res = await _dio.get('/api/admin/events/${widget.id}');
      if (res.statusCode == 200) {
        final data = res.data;
        final raw = (data is Map && data['data'] is Map)
            ? data['data'] as Map
            : (data is Map ? data as Map : <String, dynamic>{});
        final ev = Map<String, dynamic>.from(raw);
        setState(() => _event = ev);
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

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error
            ? Center(
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _event == null
                ? const Center(child: Text('No data'))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.event),
                        title: Text((_event!['title'] ?? '').toString()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_event!['description'] != null)
                              Text(_event!['description'].toString()),
                            if (_event!['eventDate'] != null)
                              Text(_event!['eventDate'].toString()),
                            if (_event!['buildingNumber'] != null)
                              Text('Building: ${_event!['buildingNumber']}'),
                          ],
                        ),
                      ),
                    ),
                  );

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5), const Center(child: CircularProgressIndicator())])
            : (_error || _event == null)
                ? ListView(children: [SizedBox(height: 24), body])
                : ListView(children: [body]),
      ),
    );
  }
}
