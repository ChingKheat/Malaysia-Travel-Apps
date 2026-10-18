import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/api_keys.dart';
import '../core/app_colors.dart';
import '../core/app_decorations.dart';
import '../core/supabase_config.dart';
import '../services/google_places_service.dart';
import '../services/place_classifier.dart';

class AdminPlacesScreen extends StatefulWidget {
  const AdminPlacesScreen({super.key});

  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  static const List<String> availableStates = [
    'Penang',
    'Kuala Lumpur',
    'Melaka',
    'Selangor',
    'Johor',
    'Perak',
    'Pahang',
    'Sabah',
    'Sarawak',
    'Kedah',
    'Terengganu',
    'Kelantan',
    'Negeri Sembilan',
    'Perlis',
  ];

  String _selectedState = 'Penang';
  bool _isLoading = false;
  bool _isFetchingList = false;
  final List<String> _logs = [];

  List<Map<String, dynamic>> _currentPlaces = [];
  int _dbCount = 0;
  bool _rlsBlocked = false;
  bool _missingReviewColumn = false;
  double _syncProgress = 0.0;
  String _syncStatusText = '';
  String _syncSubStatusText = '';
  bool _showTerminalLogs = false;

  @override
  void initState() {
    super.initState();
    _loadStateData();
  }

  static double _calculatePopularityScore(Map<String, dynamic> item) {
    final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
    final count = (item['user_ratings_total'] as num?)?.toInt() ?? 0;
    if (count <= 0) return rating * 0.1;
    if (count < 10) return rating * 0.4;
    // Standard Bayesian/weighted popularity formula: rating * log10(reviewCount + 10)
    return rating * (math.log(count + 10) / math.ln10);
  }

  static String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
    });
  }

  Future<void> _loadStateData() async {
    setState(() {
      _isFetchingList = true;
      _rlsBlocked = false;
    });

    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await client
            .from('places')
            .select()
            .ilike('state', '%$_selectedState%')
            .order('rating', ascending: false)
            .limit(500);

        final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
        list.sort((a, b) => _calculatePopularityScore(b).compareTo(_calculatePopularityScore(a)));

        final hasColumnInDb = list.isEmpty || list.any((p) => p.containsKey('user_ratings_total'));

        setState(() {
          _currentPlaces = list;
          _dbCount = _currentPlaces.length;
          _missingReviewColumn = !hasColumnInDb;
        });
      } catch (e) {
        debugPrint('Error loading places: $e');
      }
    }

    setState(() {
      _isFetchingList = false;
    });
  }

  Future<void> _syncPlacesFromGoogle() async {
    if (!ApiKeys.hasGoogleMapsKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps API key is not configured.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _rlsBlocked = false;
      _logs.clear();
      _syncProgress = 0.05;
      _syncStatusText = 'Starting top-rated sync for $_selectedState...';
      _syncSubStatusText = 'Target: 100 places per category (300 places total)';
    });

    _addLog('🚀 Starting top-rated enrichment for $_selectedState (Target: 100 per category)...');

    final client = http.Client();
    final allPlaces = <String, Map<String, dynamic>>{};

    final categorySpecs = [
      {
        'category': 'Attraction',
        'icon': '🏛️',
        'queries': [
          'top rated famous tourist attractions, iconic landmarks and must visit places in $_selectedState, Malaysia',
          'famous historical heritage monuments, iconic temples and top cultural sights in $_selectedState, Malaysia',
          'top rated museums, art galleries, popular viewpoints and architecture in $_selectedState, Malaysia',
          'famous theme parks, family entertainment attractions and top sightseeing spots in $_selectedState, Malaysia',
          'popular shopping malls, craft centers and top attractions to visit in $_selectedState, Malaysia',
        ],
      },
      {
        'category': 'Restaurant',
        'icon': '🍜',
        'queries': [
          'top rated famous local street food, legendary hawker stalls and food courts in $_selectedState, Malaysia',
          'best Michelin guide and award winning restaurants, famous local dining in $_selectedState, Malaysia',
          'most popular traditional authentic Malaysian restaurants and top cafes in $_selectedState, Malaysia',
          'famous night markets, iconic breakfast spots and top local delicacies in $_selectedState, Malaysia',
          'top rated seafood restaurants, coffee shops and famous eateries in $_selectedState, Malaysia',
        ],
      },
      {
        'category': 'Nature & Culture',
        'icon': '🌿',
        'queries': [
          'top rated scenic national parks, forest reserves, botanical gardens and waterfalls in $_selectedState, Malaysia',
          'famous pristine beaches, islands, coastal viewpoints and scenic spots in $_selectedState, Malaysia',
          'popular hiking trails, scenic mountain peaks, famous caves and nature lookouts in $_selectedState, Malaysia',
          'iconic cultural heritage villages, handicraft centers and historic temples in $_selectedState, Malaysia',
          'famous eco parks, wildlife sanctuaries and scenic nature attractions in $_selectedState, Malaysia',
        ],
      },
    ];

    const targetPerCategory = 100;

    try {
      for (int cIdx = 0; cIdx < categorySpecs.length; cIdx++) {
        final spec = categorySpecs[cIdx];
        final catName = spec['category'] as String;
        final icon = spec['icon'] as String;
        final queriesList = (spec['queries'] as List<String>);

        _addLog('📂 [${cIdx + 1}/${categorySpecs.length}] Category: $icon $catName (Target: Top $targetPerCategory)...');
        setState(() {
          final baseProg = cIdx * 0.28;
          _syncProgress = (baseProg + 0.02).clamp(0.05, 0.85);
          _syncStatusText = 'Category ${cIdx + 1}/3: $icon $catName (Target: Top $targetPerCategory)';
          _syncSubStatusText = 'Gathered ${allPlaces.length} places so far';
        });

        final categoryPlaces = <String, Map<String, dynamic>>{};

        for (int qIdx = 0; qIdx < queriesList.length && categoryPlaces.length < targetPerCategory; qIdx++) {
          final queryText = queriesList[qIdx];
          String? pageToken;
          int pageNum = 1;

          while (categoryPlaces.length < targetPerCategory && pageNum <= 3) {
            _addLog('   ↳ Query ${qIdx + 1}, Page $pageNum: Searching top places from Google...');

            final bodyMap = <String, dynamic>{
              'textQuery': queryText,
              'languageCode': 'en',
              'pageSize': 20,
            };
            if (pageToken != null && pageToken.isNotEmpty) {
              bodyMap['pageToken'] = pageToken;
            }

            final response = await client.post(
              Uri.parse('https://places.googleapis.com/v1/places:searchText'),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': ApiKeys.googleMaps,
                'X-Goog-FieldMask':
                    'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.regularOpeningHours,places.primaryTypeDisplayName,places.editorialSummary,places.types,places.photos,nextPageToken',
              },
              body: jsonEncode(bodyMap),
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              final places = (data['places'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

              int newInPage = 0;
              for (final p in places) {
                final id = p['id']?.toString();
                if (id == null || id.isEmpty) continue;

                final name = (p['displayName'] as Map<String, dynamic>?)?['text'] ?? 'Point of Interest';
                final primaryType = (p['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text'] ?? catName;
                final loc = p['location'] as Map<String, dynamic>?;
                final lat = (loc?['latitude'] as num?)?.toDouble() ?? 3.140853;
                final lng = (loc?['longitude'] as num?)?.toDouble() ?? 101.693207;

                // Sanity check: place must be strictly within Malaysia
                if (lat < 1.0 || lat > 7.5 || lng < 99.0 || lng > 120.0) continue;
                // If Kuala Lumpur, verify place is within greater KL / Klang Valley bounds
                if (_selectedState.toLowerCase().contains('kuala lumpur')) {
                  if (lat < 2.8 || lat > 3.5 || lng < 101.4 || lng > 102.1) continue;
                }
                final rating = (p['rating'] as num?)?.toDouble();
                final reviewCount = (p['userRatingCount'] as num?)?.toInt() ?? 0;

                final photosRaw = (p['photos'] as List<dynamic>? ?? []);
                final photoUrls = photosRaw
                    .take(5)
                    .map((ph) {
                      final photoName = ph['name']?.toString() ?? '';
                      return photoName.isNotEmpty
                          ? GooglePlacesService.buildPhotoUrl(photoName)
                          : '';
                    })
                    .where((url) => url.isNotEmpty)
                    .toList();

                final isIndoor = PlaceClassifier.classify(
                  category: primaryType,
                  name: name,
                );

                final placeEntry = {
                  'place_id': id,
                  'name': name,
                  'state': _selectedState,
                  'category': primaryType,
                  'latitude': lat,
                  'longitude': lng,
                  'rating': rating,
                  'user_ratings_total': reviewCount,
                  'is_indoor': isIndoor,
                  'photo_url': photoUrls.isNotEmpty ? photoUrls.join('|') : null,
                  'operating_hours': p['regularOpeningHours'],
                };

                if (!categoryPlaces.containsKey(id)) {
                  newInPage++;
                  categoryPlaces[id] = placeEntry;
                }
              }

              _addLog('   ✓ Added $newInPage places (Total for $catName: ${categoryPlaces.length}/$targetPerCategory)');

              final currentTotal = allPlaces.length + categoryPlaces.length;
              final catProgress = (categoryPlaces.length / targetPerCategory).clamp(0.0, 1.0);
              final overall = 0.05 + (cIdx * 0.25) + (catProgress * 0.25);
              setState(() {
                _syncProgress = overall.clamp(0.05, 0.80);
                _syncStatusText = 'Step ${cIdx + 1}/3: $icon $catName (${categoryPlaces.length}/$targetPerCategory)';
                _syncSubStatusText = '$currentTotal places gathered with photos & reviews';
              });

              final nextToken = data['nextPageToken']?.toString();
              if (nextToken != null && nextToken.isNotEmpty && categoryPlaces.length < targetPerCategory) {
                pageToken = nextToken;
                pageNum++;
                await Future.delayed(const Duration(milliseconds: 500));
              } else {
                break;
              }
            } else {
              _addLog('   ✗ Google API returned ${response.statusCode}: ${response.body}');
              break;
            }
          }
        }

        // Sort category places by popularity score (rating + review count) descending
        final sortedCat = categoryPlaces.values.toList()
          ..sort((a, b) => _calculatePopularityScore(b).compareTo(_calculatePopularityScore(a)));
        for (final p in sortedCat) {
          allPlaces[p['place_id'] as String] = p;
        }

        _addLog('   🏁 $catName complete: Gathered ${categoryPlaces.length} top-rated places.');
        setState(() {
          final prog = 0.05 + ((cIdx + 1) * 0.25);
          _syncProgress = prog.clamp(0.05, 0.80);
          _syncStatusText = 'Finished $icon $catName (${categoryPlaces.length} places)';
          _syncSubStatusText = 'Total gathered so far: ${allPlaces.length} places';
        });
      }

      _addLog('📦 Total unique top places gathered across all categories: ${allPlaces.length}');

      if (allPlaces.isNotEmpty) {
        // Sort entire dataset by popularity score (rating + review count) descending
        final rows = allPlaces.values.toList()
          ..sort((a, b) => _calculatePopularityScore(b).compareTo(_calculatePopularityScore(a)));

        _addLog('💾 Saving ${rows.length} top-rated places with photos into Supabase in batches...');

        const chunkSize = 40;
        int savedCount = 0;
        bool hasError = false;

        for (int i = 0; i < rows.length; i += chunkSize) {
          final end = (i + chunkSize > rows.length) ? rows.length : i + chunkSize;
          final chunk = rows.sublist(i, end);
          final batchNum = (i ~/ chunkSize) + 1;
          final totalBatches = (rows.length / chunkSize).ceil();

          _addLog('   Batch [$batchNum/$totalBatches]: Uploading ${chunk.length} places...');
          final batchProgress = 0.80 + (0.15 * (batchNum / totalBatches));
          setState(() {
            _syncProgress = batchProgress.clamp(0.80, 0.95);
            _syncStatusText = 'Saving to database: Batch $batchNum/$totalBatches';
            _syncSubStatusText = '$savedCount / ${rows.length} places saved';
          });

          final supabaseRes = await client.post(
            Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/places'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(chunk),
          );

          if (supabaseRes.statusCode >= 200 && supabaseRes.statusCode < 300) {
            savedCount += chunk.length;
          } else {
            // Check if failure is due to missing user_ratings_total column
            if (supabaseRes.body.contains('user_ratings_total')) {
              setState(() {
                _missingReviewColumn = true;
              });
              _addLog('⚠️ Supabase is missing "user_ratings_total" column. Retrying batch without review count...');
              final fallbackChunk = chunk.map((c) {
                final copy = Map<String, dynamic>.from(c);
                copy.remove('user_ratings_total');
                return copy;
              }).toList();

              final retryRes = await client.post(
                Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/places'),
                headers: {
                  'Content-Type': 'application/json',
                  'apikey': SupabaseConfig.supabaseAnonKey,
                  'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
                  'Prefer': 'resolution=merge-duplicates',
                },
                body: jsonEncode(fallbackChunk),
              );

              if (retryRes.statusCode >= 200 && retryRes.statusCode < 300) {
                savedCount += chunk.length;
                continue;
              }
            }

            hasError = true;
            _addLog('❌ Supabase Error on Batch $batchNum (${supabaseRes.statusCode}): ${supabaseRes.body}');
            if (supabaseRes.body.contains('row-level security') || supabaseRes.statusCode == 401) {
              setState(() {
                _rlsBlocked = true;
              });
            }
            break;
          }
        }

        if (!hasError) {
          _addLog('🎉 SUCCESS! Saved all $savedCount top-rated places with photos into Supabase!');
          setState(() {
            _syncProgress = 0.96;
            _syncStatusText = 'Auto-syncing indoor & outdoor sub-tables...';
            _syncSubStatusText = 'Configuring rain & AC tags for $savedCount places';
          });
          _addLog('⚡ Auto-syncing indoor & outdoor classifications to sub-tables...');
          await _syncConfirmedSubTables(rows);
          GooglePlacesService.clearMemoryCache();
          await _loadStateData();
          setState(() {
            _syncProgress = 1.0;
            _syncStatusText = 'Sync Completed Successfully! 🎉';
            _syncSubStatusText = 'Saved all $savedCount places with photos, reviews & indoor tags';
          });
        }
      }
    } catch (e) {
      _addLog('⚠️ Exception: $e');
      setState(() {
        _syncStatusText = 'Sync stopped with error';
        _syncSubStatusText = e.toString();
      });
    } finally {
      client.close();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearStatePlaces() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear $_selectedState Places?'),
        content: Text('This will delete all cached places for $_selectedState from the Supabase database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _logs.clear();
      _syncProgress = 0.2;
      _syncStatusText = 'Clearing places for $_selectedState...';
      _syncSubStatusText = 'Deleting records from Supabase';
    });

    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('places').delete().ilike('state', '%$_selectedState%');
        GooglePlacesService.clearMemoryCache();
        _addLog('🗑️ Cleared places for $_selectedState in Supabase.');
        await _loadStateData();
        setState(() {
          _syncProgress = 1.0;
          _syncStatusText = 'Cleared $_selectedState Places 🗑️';
          _syncSubStatusText = 'All cached places for $_selectedState removed';
        });
      } catch (e) {
        _addLog('⚠️ Error deleting: $e');
        setState(() {
          _syncStatusText = 'Error deleting places';
          _syncSubStatusText = e.toString();
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _syncConfirmedSubTables(List<Map<String, dynamic>> places) async {
    final client = http.Client();
    try {
      final indoorRows = places
          .where((p) => p['is_indoor'] == true)
          .map((p) => {'place_id': p['place_id'], 'is_air_conditioned': true})
          .toList();

      final outdoorRows = places
          .where((p) => p['is_indoor'] == false)
          .map((p) => {'place_id': p['place_id'], 'is_rain_sensitive': true})
          .toList();

      if (indoorRows.isNotEmpty) {
        final res = await client.post(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/indoor_places'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode(indoorRows),
        );
        if (res.statusCode < 300) {
          _addLog('   🏠 Synced ${indoorRows.length} indoor places into indoor_places table.');
        } else {
          _addLog('   ⚠️ Note on indoor_places sync (${res.statusCode})');
        }
      }

      if (outdoorRows.isNotEmpty) {
        final res = await client.post(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/outdoor_places'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode(outdoorRows),
        );
        if (res.statusCode < 300) {
          _addLog('   ☀️ Synced ${outdoorRows.length} outdoor places into outdoor_places table.');
        } else {
          _addLog('   ⚠️ Note on outdoor_places sync (${res.statusCode})');
        }
      }
    } catch (e) {
      _addLog('   ⚠️ Sub-table sync note: $e');
    } finally {
      client.close();
    }
  }

  Future<void> _autoClassifyPlaces() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _syncProgress = 0.1;
      _syncStatusText = 'Starting auto-classification for $_selectedState...';
      _syncSubStatusText = 'Fetching places from database';
    });

    _addLog('⚡ Starting automatic classification for $_selectedState places...');

    final client = http.Client();
    try {
      final encodedState = Uri.encodeComponent(_selectedState);
      final getRes = await client.get(
        Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/places?state=ilike.*$encodedState*&select=place_id,name,category,is_indoor'),
        headers: {
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
      );

      if (getRes.statusCode != 200) {
        _addLog('❌ Failed to fetch places: ${getRes.statusCode}');
        setState(() {
          _syncStatusText = 'Failed to fetch places';
          _syncSubStatusText = 'HTTP ${getRes.statusCode}';
        });
        return;
      }

      final places = (jsonDecode(getRes.body) as List<dynamic>).cast<Map<String, dynamic>>();
      _addLog('📋 Loaded ${places.length} places for $_selectedState from database.');

      int indoorCount = 0;
      int outdoorCount = 0;
      int unassignedCount = 0;
      final updates = <Map<String, dynamic>>[];

      for (final p in places) {
        final id = p['place_id'] as String;
        final name = (p['name'] ?? '').toString();
        final category = (p['category'] ?? '').toString();

        final classified = PlaceClassifier.classify(category: category, name: name);

        if (classified == true) {
          indoorCount++;
        } else if (classified == false) {
          outdoorCount++;
        } else {
          unassignedCount++;
        }

        if (p['is_indoor'] != classified) {
          updates.add({
            'place_id': id,
            'is_indoor': classified,
          });
        }
      }

      _addLog('📊 Auto-classification breakdown:');
      _addLog('   🏠 Indoor: $indoorCount');
      _addLog('   ☀️ Outdoor: $outdoorCount');
      _addLog('   ❓ Needs Review (Null): $unassignedCount');

      setState(() {
        _syncProgress = 0.35;
        _syncStatusText = 'Analyzed ${places.length} places';
        _syncSubStatusText = '$indoorCount Indoor • $outdoorCount Outdoor • $unassignedCount Review';
      });

      if (updates.isEmpty) {
        _addLog('✨ All places are already up-to-date with classification rules!');
      } else {
        _addLog('💾 Updating ${updates.length} places in Supabase...');

        int updatedCount = 0;
        for (int uIdx = 0; uIdx < updates.length; uIdx++) {
          final u = updates[uIdx];
          final id = u['place_id'] as String;
          final patchRes = await client.patch(
            Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/places?place_id=eq.$id'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            },
            body: jsonEncode({'is_indoor': u['is_indoor']}),
          );
          if (patchRes.statusCode < 300) {
            updatedCount++;
          }

          if (uIdx % 10 == 0 || uIdx == updates.length - 1) {
            final prog = 0.35 + (0.50 * ((uIdx + 1) / updates.length));
            setState(() {
              _syncProgress = prog.clamp(0.35, 0.85);
              _syncStatusText = 'Updating places in database ($updatedCount/${updates.length})...';
              _syncSubStatusText = 'Saving indoor/outdoor tags';
            });
          }
        }
        _addLog('🎉 Successfully auto-classified $updatedCount places!');
      }

      // Re-sync sub-tables
      _addLog('🔄 Synchronizing indoor_places and outdoor_places sub-tables...');
      setState(() {
        _syncProgress = 0.90;
        _syncStatusText = 'Syncing indoor & outdoor sub-tables...';
        _syncSubStatusText = 'Updating indoor_places & outdoor_places tables';
      });

      final allClassified = places.map((p) {
        final classified = PlaceClassifier.classify(
          category: (p['category'] ?? '').toString(),
          name: (p['name'] ?? '').toString(),
        );
        return {
          'place_id': p['place_id'],
          'is_indoor': classified,
        };
      }).toList();

      await _syncConfirmedSubTables(allClassified);
      _addLog('✅ Auto-classification & sub-table sync complete!');

      GooglePlacesService.clearMemoryCache();
      await _loadStateData();

      setState(() {
        _syncProgress = 1.0;
        _syncStatusText = 'Auto-classification complete! ⚡';
        _syncSubStatusText = '${updates.length} places updated & sub-tables synchronized';
      });
    } catch (e) {
      _addLog('⚠️ Exception: $e');
      setState(() {
        _syncStatusText = 'Classification error';
        _syncSubStatusText = e.toString();
      });
    } finally {
      client.close();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlaceIndoorOutdoor(Map<String, dynamic> place) async {
    final currentVal = place['is_indoor'] as bool?;
    final bool? nextVal;
    if (currentVal == true) {
      nextVal = false;
    } else if (currentVal == false) {
      nextVal = null;
    } else {
      nextVal = true;
    }

    final id = place['place_id'] as String;
    final name = place['name'] ?? 'Place';

    setState(() {
      place['is_indoor'] = nextVal;
    });

    final client = http.Client();
    try {
      // 1. Update places table
      await client.patch(
        Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/places?place_id=eq.$id'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: jsonEncode({'is_indoor': nextVal}),
      );

      // 2. Update sub-tables
      if (nextVal == true) {
        await client.post(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/indoor_places'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode([{'place_id': id, 'is_air_conditioned': true}]),
        );
        await client.delete(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/outdoor_places?place_id=eq.$id'),
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
          },
        );
      } else if (nextVal == false) {
        await client.post(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/outdoor_places'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode([{'place_id': id, 'is_rain_sensitive': true}]),
        );
        await client.delete(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/indoor_places?place_id=eq.$id'),
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
          },
        );
      } else {
        await client.delete(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/indoor_places?place_id=eq.$id'),
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
          },
        );
        await client.delete(
          Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/outdoor_places?place_id=eq.$id'),
          headers: {
            'apikey': SupabaseConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
          },
        );
      }

      final label = nextVal == true ? '🏠 Indoor' : (nextVal == false ? '☀️ Outdoor' : '❓ Needs Review');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name set to $label'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling place: $e');
    } finally {
      client.close();
    }
  }

  Widget _buildIndoorOutdoorBadge(Map<String, dynamic> place) {
    final isIndoor = place['is_indoor'] as bool?;
    final Color bgColor;
    final Color textColor;
    final String label;

    if (isIndoor == true) {
      bgColor = const Color(0xFFE0F2FE);
      textColor = const Color(0xFF0284C7);
      label = '🏠 Indoor';
    } else if (isIndoor == false) {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      label = '☀️ Outdoor';
    } else {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFD97706);
      label = '❓ Review';
    }

    return InkWell(
      onTap: () => _togglePlaceIndoorOutdoor(place),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.touch_app, size: 9, color: textColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge({
    required String label,
    required String icon,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$icon $count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressBar() {
    if (_logs.isEmpty && !_isLoading) return const SizedBox.shrink();

    final isDone = !_isLoading && _syncProgress >= 1.0;
    final percent = (_syncProgress * 100).toInt().clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Percentage
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 24,
                            )
                          : _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF2563EB),
                                  ),
                                )
                              : const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 24,
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _syncStatusText.isNotEmpty
                                      ? _syncStatusText
                                      : (_isLoading ? 'Syncing places...' : 'Activity Status'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: isDone
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_syncSubStatusText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _syncSubStatusText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Animated Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    tween: Tween<double>(
                      begin: 0,
                      end: _syncProgress.clamp(0.0, 1.0),
                    ),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value > 0 ? value : (_isLoading ? null : 0.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Terminal Toggle Bar
          InkWell(
            onTap: () {
              setState(() {
                _showTerminalLogs = !_showTerminalLogs;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                  bottom: _showTerminalLogs
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
                borderRadius: _showTerminalLogs
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        _showTerminalLogs
                            ? 'Hide Raw Logs'
                            : 'View Raw Terminal Logs (${_logs.length} lines)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showTerminalLogs
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Terminal Body
          if (_showTerminalLogs)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _logs.map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: log.contains('🎉') || log.contains('✓') || log.contains('✅')
                                ? const Color(0xFF4ADE80)
                                : (log.contains('❌') || log.contains('✗')
                                    ? const Color(0xFFF87171)
                                    : Colors.white70),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Admin Database Hub',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Secret Data Seeder Portal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Bulk-fetch real tourist attractions, restaurants, and nature spots with Google photos directly into your Supabase database.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // State Selector Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '1. Select Destination State',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '13 States + KL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStates.map((st) {
                    final isSel = st == _selectedState;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text(st),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.ink,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && !_isLoading) {
                          setState(() {
                            _selectedState = st;
                          });
                          _loadStateData();
                        }
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storage, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Database Count for $_selectedState:',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _dbCount > 0 ? const Color(0xFFE8FDF2) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_dbCount places',
                        style: TextStyle(
                          color: _dbCount > 0 ? const Color(0xFF059669) : Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_currentPlaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCountBadge(
                        label: 'Indoor',
                        icon: '🏠',
                        count: _currentPlaces.where((p) => p['is_indoor'] == true).length,
                        color: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                      ),
                      const SizedBox(width: 8),
                      _buildCountBadge(
                        label: 'Outdoor',
                        icon: '☀️',
                        count: _currentPlaces.where((p) => p['is_indoor'] == false).length,
                        color: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFDCFCE7),
                      ),
                      const SizedBox(width: 8),
                      _buildCountBadge(
                        label: 'Review',
                        icon: '❓',
                        count: _currentPlaces.where((p) => p['is_indoor'] == null).length,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // RLS Alert Banner if blocked
          if (_rlsBlocked) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Supabase Row-Level Security (RLS) Locked',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To allow saving places, run this 1-line command in your Supabase SQL Editor:',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            'ALTER TABLE public.places DISABLE ROW LEVEL SECURITY;',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                              text: 'ALTER TABLE public.places DISABLE ROW LEVEL SECURITY;',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('SQL command copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Missing Review Count Column Alert Banner
          if (_missingReviewColumn) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_half, color: Color(0xFFB45309), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Missing Review Count Column in Supabase',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Places in $_selectedState are currently saved without review counts. To rank by Popularity Score and display reviews (e.g. 12.4k), run this in Supabase SQL Editor and tap Fetch & Sync again:',
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            'ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                              text: 'ALTER TABLE public.places ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER DEFAULT 0;',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('SQL command copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _loadStateData();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Checking database schema...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFB45309)),
                      label: const Text(
                        'Already Ran It? Tap to Refresh & Dismiss',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _syncPlacesFromGoogle,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_for_offline),
                  label: Text(_isLoading ? 'Syncing...' : 'Fetch & Sync $_selectedState (Top 100/cat)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _clearStatePlaces,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _isLoading ? null : _autoClassifyPlaces,
              icon: const Icon(Icons.bolt, color: Color(0xFF4F46E5), size: 18),
              label: const Text(
                '⚡ Auto-Classify Indoor & Outdoor (Schedule Ready)',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Activity & Progress Bar
          _buildSyncProgressBar(),

          // Synced Places List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Places in Database ($_selectedState)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadStateData,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isFetchingList)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_currentPlaces.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'No places stored for $_selectedState yet.',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Fetch & Sync" above to download 300+ top places (100 per category) from Google API.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._currentPlaces.map((p) {
              final rawPhoto = p['photo_url']?.toString();
              final primaryPhoto = rawPhoto != null && rawPhoto.isNotEmpty
                  ? (rawPhoto.contains('|') ? rawPhoto.split('|').first : rawPhoto)
                  : null;
              final photoCount = rawPhoto != null && rawPhoto.contains('|')
                  ? rawPhoto.split('|').length
                  : (rawPhoto != null && rawPhoto.isNotEmpty ? 1 : 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: primaryPhoto != null
                          ? Image.network(
                              primaryPhoto,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.place, color: AppColors.primary),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.place, color: AppColors.primary),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name']?.toString() ?? 'Place',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                p['category']?.toString() ?? 'Attraction',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                              _buildIndoorOutdoorBadge(p),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              p['rating']?.toString() ?? '4.5',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (p['user_ratings_total'] != null && (p['user_ratings_total'] as num) > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '(${_formatReviewCount((p['user_ratings_total'] as num).toInt())})',
                                style: const TextStyle(fontSize: 10, color: AppColors.muted),
                              ),
                            ],
                          ],
                        ),
                        if (photoCount > 0) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '📷 $photoCount',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
