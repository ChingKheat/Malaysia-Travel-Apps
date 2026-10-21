import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_travel_planner/features/places/services/place_catalog_service.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';

class ApiRetrievalScreen extends StatefulWidget {
  const ApiRetrievalScreen({super.key});

  @override
  State<ApiRetrievalScreen> createState() => _ApiRetrievalScreenState();
}

class _ApiRetrievalScreenState extends State<ApiRetrievalScreen> {
  final TextEditingController _cityController = TextEditingController(
    text: 'Kuala Lumpur',
  );
  bool _isLoading = false;
  int? _statusCode;
  int _responseTimeMs = 0;
  String _rawJsonOutput = '';
  List<Map<String, dynamic>> _retrievedPlaces = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPlacesFromApi();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlacesFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _statusCode = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final rows = await PlaceCatalogService().load();
      final city = _cityController.text.trim().toLowerCase();
      final matches = rows
          .where(
            (r) => '${r['state']} ${r['name']}'.toLowerCase().contains(city),
          )
          .take(50)
          .toList();
      if (!mounted) return;
      setState(() {
        _statusCode = 200;
        _rawJsonOutput = const JsonEncoder.withIndent('  ').convert(matches);
        _retrievedPlaces = matches
            .map(
              (r) => <String, dynamic>{
                'name': r['name'],
                'full_address': r['state'],
                'type': r['category'],
                'lat': '${r['latitude']}',
                'lon': '${r['longitude']}',
              },
            )
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = 'Saved places are unavailable. Try again later.',
        );
      }
    } finally {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _responseTimeMs = stopwatch.elapsedMilliseconds;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Places Inspector'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.teal,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.place), text: 'Retrieved Places'),
              Tab(icon: Icon(Icons.code), text: 'Raw JSON Output'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Top Controls Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: 'Search City / Destination',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _fetchPlacesFromApi(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchPlacesFromApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_download),
                        label: Text(_isLoading ? 'Fetching...' : 'Retrieve'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // HTTP Response Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _statusCode == 200
                          ? Colors.green.shade50
                          : (_statusCode != null
                                ? Colors.red.shade50
                                : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _statusCode == 200
                            ? Colors.green.shade300
                            : (_statusCode != null
                                  ? Colors.red.shade300
                                  : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _statusCode == 200
                                  ? Icons.check_circle
                                  : Icons.info,
                              color: _statusCode == 200
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusCode != null
                                  ? 'HTTP Status: $_statusCode OK'
                                  : (_isLoading
                                        ? 'Reading saved database...'
                                        : 'Ready'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _statusCode == 200
                                    ? Colors.green.shade900
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_responseTimeMs}ms',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_retrievedPlaces.length} Items',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Rendered Cards
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _retrievedPlaces.isEmpty
                      ? const Center(child: Text('No places retrieved yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _retrievedPlaces.length,
                          itemBuilder: (context, index) {
                            final place = _retrievedPlaces[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  place['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Category: ${place['type']}\nLocation: (${place['lat']}, ${place['lon']})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 2: Raw JSON Output
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          width: double.infinity,
                          color: const Color(0xFF1E1E1E),
                          padding: const EdgeInsets.all(14),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _rawJsonOutput.isEmpty
                                  ? '// Read stored place data; no Google search requests'
                                  : _rawJsonOutput,
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                color: Color(0xFF4EC9B0),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
