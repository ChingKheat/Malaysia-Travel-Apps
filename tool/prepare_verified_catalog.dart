// Offline-only JSON validation and SQL preparation. Never connects to a server.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? option(String key) {
    final i = args.indexOf(key);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final input = option('--input');
  if (input == null) {
    stderr.writeln(
      'Usage: dart run tool/prepare_verified_catalog.dart --input reviewed.json [--output prepared.sql] [--batch-size 100] [--after stable-id]',
    );
    exitCode = 64;
    return;
  }
  final rows = jsonDecode(File(input).readAsStringSync()) as List;
  final seen = <String>{};
  final accepted = <Map<String, dynamic>>[];
  final errors = <String>[];
  String quote(Object? value) =>
      value == null ? 'NULL' : "'${value.toString().replaceAll("'", "''")}'";
  for (var i = 0; i < rows.length; i++) {
    try {
      final row = Map<String, dynamic>.from(rows[i] as Map);
      final id = row['place_id'] as String;
      final lat = row['latitude'] as num, lng = row['longitude'] as num;
      if (id.isEmpty ||
          id.startsWith('ChI') ||
          id.startsWith('google_') ||
          !seen.add(id)) {
        throw 'Invalid/duplicate stable ID';
      }
      for (final field in [
        'name',
        'state',
        'category',
        'catalog_license',
        'catalog_source_url',
      ]) {
        if (row[field] is! String || (row[field] as String).trim().isEmpty) {
          throw 'Missing $field';
        }
      }
      if (row['data_source'] != 'independent' || row['reviewed'] != true) {
        throw 'Independent source and explicit review required';
      }
      if (Uri.tryParse(row['catalog_source_url'])?.scheme != 'https') {
        throw 'HTTPS provenance required';
      }
      if (DateTime.tryParse(row['catalog_verified_at']?.toString() ?? '') ==
          null) {
        throw 'Verification timestamp required';
      }
      if (!lat.isFinite ||
          !lng.isFinite ||
          lat < 1 ||
          lat > 7.5 ||
          lng < 99 ||
          lng > 120) {
        throw 'Invalid Malaysia coordinates';
      }
      // Optional ratings/photos are deliberately excluded: they require their own
      // provenance and image rights review, not a guessed default or Google copy.
      accepted.add(row);
    } catch (e) {
      errors.add('row ${i + 1}: $e');
    }
  }
  accepted.sort(
    (a, b) => (a['place_id'] as String).compareTo(b['place_id'] as String),
  );
  final after = option('--after');
  final batch = accepted
      .where(
        (r) => after == null || (r['place_id'] as String).compareTo(after) > 0,
      )
      .take(
        (int.tryParse(option('--batch-size') ?? '100') ?? 100).clamp(1, 500),
      )
      .toList();
  final output = option('--output');
  if (output != null && errors.isEmpty) {
    final sql = StringBuffer('BEGIN;\n');
    for (final row in batch) {
      sql.writeln(
        'INSERT INTO public.places(place_id,name,state,category,latitude,longitude,data_source,catalog_status,catalog_source_url,catalog_license,catalog_verified_at) VALUES '
        '(${quote(row['place_id'])},${quote(row['name'])},${quote(row['state'])},${quote(row['category'])},${row['latitude']},${row['longitude']},\'independent\',\'published\',${quote(row['catalog_source_url'])},${quote(row['catalog_license'])},${quote(row['catalog_verified_at'])}) '
        'ON CONFLICT(place_id) DO UPDATE SET name=excluded.name,state=excluded.state,category=excluded.category,latitude=excluded.latitude,longitude=excluded.longitude,catalog_source_url=excluded.catalog_source_url,catalog_license=excluded.catalog_license,catalog_verified_at=excluded.catalog_verified_at,catalog_status=excluded.catalog_status WHERE places.data_source=\'independent\';',
      );
    }
    sql.writeln('COMMIT;');
    File(output).writeAsStringSync(sql.toString());
  }
  stdout.writeln(
    jsonEncode({
      'accepted': accepted.length,
      'rejected': errors.length,
      'batch': batch.length,
      'resume_after': batch.isEmpty ? after : batch.last['place_id'],
      'errors': errors,
      'prepared_sql': errors.isEmpty ? output : null,
      'remote_changes': 0,
    }),
  );
  if (errors.isNotEmpty) exitCode = 1;
}
