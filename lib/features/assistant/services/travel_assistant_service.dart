import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:smart_travel_planner/l10n/app_localizations.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:http/http.dart' as http;
import 'package:smart_travel_planner/core/config/api_keys.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/features/assistant/services/assistant_system_instruction.dart';
import 'package:smart_travel_planner/features/assistant/services/assistant_tool_handler.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/shared/services/weather_service.dart';

enum AssistantLanguage {
  english('English', 'en'),
  malay('Bahasa Melayu', 'ms'),
  chinese('中文', 'zh');

  const AssistantLanguage(this.label, this.code);
  final String label;
  final String code;
}

/// UC900 assistant. Gemini failures always return the existing offline reply.
class TravelAssistantService {
  factory TravelAssistantService() => _instance;
  TravelAssistantService._internal();
  static final TravelAssistantService _instance =
      TravelAssistantService._internal();
  AssistantLanguage currentLanguage = AssistantLanguage.english;
  bool isGeminiAvailable = false;
  AssistantToolHandler toolHandler = AssistantToolHandler();
  final http.Client _client = http.Client();
  String? lastGeminiIssue;
  String model = const String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );
  final List<Map<String, dynamic>> _history = [];

  String? validatePrompt(String? prompt) =>
      prompt == null || prompt.trim().isEmpty
      ? 'Please enter a travel question or tap a suggestion.'
      : (prompt.trim().length < 2
            ? 'Prompt is too short. Please be more specific.'
            : null);

  AppLocalizations get _strings =>
      lookupAppLocalizations(Locale(currentLanguage.code));

  AssistantMessage getInitialGreeting() => _reply(_strings.assistantGreeting);

  String? _pendingFoodQuestion;

  void clearConversation() {
    _pendingFoodQuestion = null;
    _history.clear();
  }

  Future<AssistantMessage> askAssistant(String prompt) async {
    final text = prompt.trim();
    final foodQuestion = _pendingFoodQuestion;
    _pendingFoodQuestion = null;
    final lower = text.toLowerCase();
    if (_countrywideFoodRequest.hasMatch(lower)) {
      _pendingFoodQuestion = text;
      final response = _reply(
        _localized(
          'Try nasi lemak, char kway teow, or roti canai. Which city are you visiting? I can suggest places to eat there.',
          'Cuba nasi lemak, char kway teow atau roti canai. Bandar mana yang anda akan lawati? Saya boleh cadangkan tempat makan di sana.',
          '可以试试椰浆饭（nasi lemak）、炒粿条或印度煎饼。您打算去哪个城市？我可以推荐当地的餐饮场所。',
        ),
      );
      unawaited(_persist(text, response.text));
      return response;
    }
    if (foodQuestion != null &&
        !_weatherRequest.hasMatch(lower) &&
        !_foodRequest.hasMatch(lower) &&
        !_addRequest.hasMatch(lower)) {
      final result = await toolHandler.execute('search_malaysia_places', {
        'category': 'food',
        'keyword': '',
        'reference_location': text,
      });
      if (result['reference_location'] != null) {
        final response = _foodReply(result, foodQuestion);
        unawaited(_persist(text, response.text));
        return response;
      }
    }
    if (_history.length > 20) _history.removeRange(0, _history.length - 20);
    if (ApiKeys.hasGeminiKey) {
      try {
        final message = await _askGemini(text);
        lastGeminiIssue = null;
        isGeminiAvailable = true;
        unawaited(_persist(text, message.text));
        return message;
      } catch (error) {
        lastGeminiIssue = _safeGeminiIssue(error);
        isGeminiAvailable = false;
      }
    } else {
      lastGeminiIssue = 'Gemini API key is not configured.';
      isGeminiAvailable = false;
    }
    final response = await _offlineResponse(text);
    unawaited(_persist(text, response.text));
    return response;
  }

  Future<AssistantMessage> _askGemini(String prompt) async {
    var activeModel = model;
    _history.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });
    List<Map> catalogMatches = [];
    for (var turn = 0; turn < 5; turn++) {
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$activeModel:generateContent',
      );
      final requestBody = jsonEncode({
        'systemInstruction': {
          'parts': [
            {
              'text': assistantSystemInstruction(
                currentLanguage,
                _malaysiaToday,
              ),
            },
          ],
        },
        'tools': [
          {'functionDeclarations': AssistantToolHandler.declarations},
        ],
        'contents': _history,
      });
      late http.Response response;
      var switchedAfterTimeout = false;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          response = await _client
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': ApiKeys.gemini,
                },
                body: requestBody,
              )
              .timeout(const Duration(seconds: 20));
        } on TimeoutException {
          if (turn == 0 && activeModel != 'gemini-3.5-flash-lite') {
            activeModel = 'gemini-3.5-flash-lite';
            switchedAfterTimeout = true;
            break;
          }
          rethrow;
        }
        if (response.statusCode != 503 || attempt == 2) break;
        await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
      if (switchedAfterTimeout) continue;
      if (response.statusCode == 503 &&
          turn == 0 &&
          activeModel != 'gemini-3.5-flash-lite') {
        activeModel = 'gemini-3.5-flash-lite';
        continue;
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Gemini service returned HTTP ${response.statusCode}.',
        );
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final candidateList = root['candidates'] as List? ?? const [];
      final candidate = candidateList.isNotEmpty && candidateList.first is Map
          ? Map<String, dynamic>.from(candidateList.first as Map)
          : null;
      final content = (candidate?['content'] as Map?)?.cast<String, dynamic>();
      final parts =
          (content?['parts'] as List?)
              ?.whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList() ??
          const [];
      if (content == null) {
        throw const FormatException('Gemini response contained no content');
      }
      final calls = parts
          .where((p) => p['functionCall'] is Map)
          .map((p) => Map<String, dynamic>.from(p['functionCall'] as Map))
          .toList();
      if (calls.isNotEmpty) {
        _history.add({'role': 'model', 'parts': parts});
        final functionResponses = <Map<String, dynamic>>[];
        final proposals = <Map<String, dynamic>>[];
        Map<String, dynamic>? weather;
        Map<String, dynamic>? food;
        for (final call in calls) {
          final name = call['name']?.toString() ?? '';
          final args = call['args'] is Map
              ? Map<String, dynamic>.from(call['args'] as Map)
              : <String, dynamic>{};
          final result = await toolHandler.execute(name, args);
          if (name == 'get_weather_forecast') weather = result;
          if (name == 'search_malaysia_places') {
            if (args['category'] == 'food') food = result;
            catalogMatches =
                (result['places'] as List?)?.whereType<Map>().toList() ?? [];
          }
          final proposal = result['proposal'];
          if (name == 'add_to_itinerary' && proposal is Map<String, dynamic>) {
            proposals.add(proposal);
          }
          functionResponses.add({
            'functionResponse': {'name': name, 'response': result},
          });
        }
        _history.add({'role': 'user', 'parts': functionResponses});
        final reply = switch ((proposals.isNotEmpty, weather, food)) {
          (true, _, _) => _reply(
            _strings.assistantReviewStop,
            proposals: proposals,
          ),
          (_, final forecast?, _) => _forecastReply(forecast),
          (_, _, final choices?) => _foodReply(choices, prompt),
          _ => null,
        };
        if (reply != null) {
          _history.add({
            'role': 'model',
            'parts': [
              {'text': reply.text},
            ],
          });
          return reply;
        }
        continue;
      }
      final text = parts
          .map((p) => p['text']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join('\n')
          .trim();
      if (text.isEmpty) {
        throw const FormatException('Gemini response text missing');
      }
      _history.add({
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      });
      final lower = prompt.toLowerCase();
      if (_addRequest.hasMatch(lower) ||
          _weatherRequest.hasMatch(lower) ||
          _foodRequest.hasMatch(lower)) {
        return _offlineResponse(prompt);
      }
      return _decodeStructured(text, catalogMatches);
    }
    throw StateError('Gemini tool loop limit reached');
  }

  AssistantMessage _decodeStructured(String raw, List<Map> catalogMatches) {
    var text = raw;
    List<String> chips = const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        text = decoded['text']?.toString() ?? raw;
        if (decoded['follow_up_chips'] is List) {
          chips = (decoded['follow_up_chips'] as List)
              .whereType<String>()
              .take(4)
              .toList();
        }
      }
    } on FormatException {
      // Plain text responses remain valid.
    }
    return AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      places: catalogMatches
          .map((row) => _place(Map<String, dynamic>.from(row)))
          .toList(),
      followUpChips: chips,
    );
  }

  String _safeGeminiIssue(Object error) {
    if (error is StateError) return error.message;
    if (error is FormatException) {
      return 'Gemini returned an unreadable response.';
    }
    if (error is TimeoutException) return 'Gemini request timed out.';
    return 'Gemini could not be reached. Check the API key and network connection.';
  }

  AssistantPlaceSuggestion _place(Map<String, dynamic> p) =>
      AssistantPlaceSuggestion(
        name: p['name']?.toString() ?? 'Place',
        category: p['category']?.toString() ?? 'Attraction',
        rating: (p['rating'] as num?)?.toDouble(),
        location: p['state']?.toString() ?? '',
        description: p['description']?.toString() ?? '',
        catalogDetails: p['catalog_details']?.toString(),
        photoUrl: p['photo_url']?.toString(),
        isIndoor: p['is_indoor'] == true,
        placeId: p['place_id']?.toString(),
      );
  Future<void> _persist(String prompt, String answer) async {
    try {
      final user = AuthService().currentUser;
      final db = SupabaseConfig.client;
      if (user == null || db == null || AuthService().isGuest) return;
      await db.from('assistant_messages').insert({
        'user_id': user.uid,
        'user_prompt': prompt,
        'ai_response': answer,
      });
    } catch (_) {}
  }

  static final _addRequest = RegExp(r'\b(add|tambah|masukkan)\b|添加|加入');
  static final _weatherRequest = RegExp(r'weather|\brain\b|cuaca|hujan|天气|下雨');
  static final _foodRequest = RegExp(r'food|halal|makan|美食|餐饮|清真');
  static final _countrywideFoodRequest = RegExp(
    r'^(?:(?:suggest )?food(?: options)? in malaysia|malaysian food|'
    r'(?:cadangkan )?(?:pilihan )?makanan di malaysia|'
    r'(?:请)?推荐马来西亚的(?:餐饮选项|美食))[.!?。！？]?$',
  );
  static final _clockPattern = RegExp(
    r'\b([01]?[0-9]|2[0-3]):([0-5][0-9])\s*(am|pm)?',
    caseSensitive: false,
  );

  String _clockFromMatch(RegExpMatch match) {
    var hour = int.parse(match[1]!);
    final period = match[3]?.toLowerCase();
    if (period != null) hour = hour % 12 + (period == 'pm' ? 12 : 0);
    return '${hour.toString().padLeft(2, '0')}:${match[2]}';
  }

  String? _labeledTime(String prompt, List<RegExpMatch> times, RegExp label) {
    final matches = times.where(
      (time) => label.hasMatch(prompt.substring(0, time.start)),
    );
    if (matches.length != 1) return null;
    final match = matches.first;
    if (RegExp(
      r'^\s*(?:or|atau|或)\s*\d',
    ).hasMatch(prompt.substring(match.end))) {
      return null;
    }
    return _clockFromMatch(match);
  }

  String? _requestedDate(String prompt) {
    final today = _malaysiaToday;
    final dates = {
      for (final match in RegExp(r'\b\d{4}-\d{2}-\d{2}\b').allMatches(prompt))
        match[0]!,
      if (RegExp(r'\btoday\b|hari ini|今天').hasMatch(prompt)) _dateString(today),
      if (RegExp(r'\btomorrow\b|\besok\b|明天').hasMatch(prompt))
        _dateString(today.add(const Duration(days: 1))),
    };
    return dates.length == 1 ? dates.single : null;
  }

  int? _requestedDay(String prompt) {
    final matches = RegExp(
      r'(?:(?:day|hari)\s+(\d+)|第\s*(\d+)\s*天)',
    ).allMatches(prompt).toList();
    if (matches.length != 1) return null;
    final match = matches.single;
    if (RegExp(
      r'^\s*(?:or|atau|或)\s*\d',
    ).hasMatch(prompt.substring(match.end))) {
      return null;
    }
    return int.tryParse((match[1] ?? match[2])!);
  }

  Future<AssistantMessage> _offlineResponse(String prompt) async {
    final p = prompt.toLowerCase();
    if (RegExp(r'^(how (can|do) i|bagaimanakah cara|如何)').hasMatch(p) &&
        RegExp(r'add|menambah|添加').hasMatch(p)) {
      return _reply(_strings.assistantItineraryInstructions);
    }
    if (_addRequest.hasMatch(p)) {
      final rows = await toolHandler.catalog();
      final matches = rows.where((row) {
        final name = row['name']?.toString().toLowerCase() ?? '';
        return name.isNotEmpty && p.contains(name);
      }).toList();
      if (matches.length == 1) {
        final trips = await SupabaseItineraryService().getSavedItineraries(
          refresh: false,
        );
        final titles = trips.where((trip) {
          final title = trip.title.trim().toLowerCase();
          return title.isNotEmpty &&
              RegExp(
                '(?:^|[^a-z0-9])${RegExp.escape(title)}(?:[^a-z0-9]|'
                r'$)',
              ).hasMatch(p);
        }).toList();
        final times = _clockPattern.allMatches(p).toList();
        final range =
            times.length == 2 &&
            ((times.first[3] == null) == (times.last[3] == null)) &&
            RegExp(
              r'^(?:-|–|to|hingga|sampai|至|到)$',
            ).hasMatch(p.substring(times.first.end, times.last.start).trim());
        final explicitArrival = _labeledTime(
          p,
          times,
          RegExp(
            r'(?:arrive(?: at)?|arrival(?: at)?|from|tiba(?: pada)?|dari|到达|从)\s*$',
          ),
        );
        final explicitDeparture = _labeledTime(
          p,
          times,
          RegExp(
            r'(?:depart(?: at)?|departure(?: at)?|leave(?: at)?|until|bertolak(?: pada)?|hingga|离开|直到)\s*$',
          ),
        );
        final result = await toolHandler.execute('add_to_itinerary', {
          'place_id': matches.single['place_id'],
          'trip_title': titles.length == 1 ? titles.single.title : null,
          'arrival_time': range
              ? _clockFromMatch(times.first)
              : explicitArrival,
          'departure_time': range
              ? _clockFromMatch(times.last)
              : explicitDeparture,
          'date': _requestedDate(p),
          'day_number': _requestedDay(p),
        });
        final proposal = result['proposal'];
        if (proposal is Map<String, dynamic>) {
          return _reply(_strings.assistantReviewStop, proposals: [proposal]);
        }
      }
      return _reply(
        _localized(
          'Which catalog place would you like to add?',
          'Tempat manakah dalam katalog yang ingin anda tambah?',
          '您想添加目录中的哪个地点？',
        ),
      );
    }
    if (_weatherRequest.hasMatch(p)) {
      final locations = [
        for (final city in WeatherService.stateCoordinates.keys)
          if (RegExp('\\b${RegExp.escape(city)}\\b').hasMatch(p)) city,
        if (RegExp(r'\bkl\b|吉隆坡').hasMatch(p) && !p.contains('kuala lumpur'))
          'Kuala Lumpur',
      ];
      if (locations.length != 1) {
        return _reply(
          _localized(
            'Which location and date would you like a forecast for?',
            'Untuk lokasi dan tarikh manakah anda mahu ramalan cuaca?',
            '您想查询哪个地点和日期的天气？',
          ),
        );
      }
      final day = _requestedDate(p);
      if (day == null) {
        return _reply(
          _localized(
            'What date should I check for ${locations.single}?',
            'Tarikh manakah yang perlu saya semak untuk ${locations.single}?',
            '您想查询 ${locations.single} 哪一天的天气？',
          ),
        );
      }
      final times = _clockPattern.allMatches(p).toList();
      final period = RegExp(
        r'morning|afternoon|evening|night|pagi|petang|malam|早上|上午|下午|晚上',
      ).firstMatch(p)?.group(0);
      if (times.length > 1 || (times.isEmpty && period != null)) {
        return _forecastReply({
          'city': locations.single,
          'forecast_date': day,
          'forecast_time': period,
        });
      }
      return _forecastReply(
        await toolHandler.execute('get_weather_forecast', {
          'city': locations.single,
          'date': day,
          'time': times.isEmpty ? null : _clockFromMatch(times.single),
        }),
      );
    }
    if (_foodRequest.hasMatch(p)) {
      final rows = await toolHandler.catalog();
      final names =
          {
              ...WeatherService.stateCoordinates.keys,
              for (final row in rows)
                if (row['name'] case final String name)
                  if (name.length > 2) name.toLowerCase(),
            }.where((name) => p.contains(name)).toList()
            ..sort((a, b) => b.length.compareTo(a.length));
      return _foodReply(
        await toolHandler.execute('search_malaysia_places', {
          'keyword': '',
          'category': 'food',
          'reference_location':
              names.firstOrNull ??
              (RegExp(r'\bkl\b|吉隆坡').hasMatch(p) ? 'Kuala Lumpur' : null),
        }),
        prompt,
      );
    }
    if (p.contains('batu cave') ||
        p.contains('etiquette') ||
        p.contains('dress') ||
        p.contains('黑风洞')) {
      return AssistantMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text:
            'Batu Caves is an active Hindu religious site. Dress modestly, respect worshippers, keep belongings secure around monkeys, and check current access guidance before travelling.',
        isUser: false,
        timestamp: DateTime.now(),
        followUpChips: const [
          'How do I get there by KTM?',
          'Find nearby indoor places',
        ],
      );
    }
    if (RegExp(
          r'^directions from |^arah perjalanan dari |^查询路线，起点和终点：',
        ).hasMatch(p) &&
        !(p.contains('klia') && p.contains('kl sentral'))) {
      return _reply(
        _localized(
          'I can’t check directions for this route right now. Enter your starting point and destination in your maps app for directions.',
          'Saya tidak dapat menyemak arah untuk laluan ini sekarang. Masukkan tempat bertolak dan destinasi dalam aplikasi peta anda.',
          '目前无法查询这条路线。请在地图应用中输入起点和终点以获取路线。',
        ),
      );
    }
    if (RegExp(
      r'transport|transit|mrt|lrt|klia|pengangkutan|交通|机场',
    ).hasMatch(p)) {
      return _reply(
        _localized(
          'In Kuala Lumpur, MRT and LRT trains serve many major areas. KLIA Ekspres connects the airport to KL Sentral.',
          'Di Kuala Lumpur, MRT dan LRT menghubungkan banyak kawasan utama. KLIA Ekspres menghubungkan lapangan terbang dengan KL Sentral.',
          '在吉隆坡，MRT 和 LRT 连接多个主要地区。KLIA Ekspres 连接机场和吉隆坡中央车站。',
        ),
      );
    }
    return _reply(
      _localized(
        'What would you like help with: food, weather, transport, or your itinerary?',
        'Anda perlukan bantuan tentang makanan, cuaca, pengangkutan atau itinerari?',
        '您想了解餐饮、天气、交通，还是需要行程帮助？',
      ),
    );
  }

  DateTime get _malaysiaToday =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  String _dateString(DateTime date) => date.toIso8601String().split('T').first;

  String _localized(String en, String ms, String zh) =>
      switch (currentLanguage) {
        AssistantLanguage.english => en,
        AssistantLanguage.malay => ms,
        AssistantLanguage.chinese => zh,
      };

  AssistantMessage _reply(
    String text, {
    List<AssistantPlaceSuggestion> places = const [],
    List<Map<String, dynamic>> proposals = const [],
  }) => AssistantMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    text: text,
    isUser: false,
    timestamp: DateTime.now(),
    places: places,
    stopProposals: proposals,
  );

  AssistantMessage _forecastReply(Map<String, dynamic> result) {
    final city = result['city']?.toString() ?? '';
    final date = result['forecast_date']?.toString() ?? '';
    final time = result['forecast_time'];
    final details = [
      if (city.isNotEmpty) city,
      if (date.isNotEmpty) date,
      if (time != null)
        time is String && time.contains(':') ? '$time MYT' : '$time',
    ].join(' · ');
    if (result['success'] != true) {
      final unavailable = _localized(
        'Forecast unavailable for the requested location and time.',
        'Ramalan tidak tersedia untuk lokasi dan masa yang diminta.',
        '没有该地点和时间的天气预报。',
      );
      return _reply([if (details.isNotEmpty) details, unavailable].join('\n'));
    }
    final status = result['cached'] == true
        ? ' · ${_localized('Cached forecast', 'Ramalan daripada cache', '缓存预报')}'
        : '';
    final rain = result['rain_probability_percent'];
    final rainLabel = _localized(
      'Chance of rain',
      'Kebarangkalian hujan',
      '降雨概率',
    );
    return _reply(
      '$details$status\n${result['condition']} · ${result['temperature_c']} °C'
      '${rain == null ? '' : ' · $rainLabel $rain%'}',
    );
  }

  AssistantMessage _foodReply(Map<String, dynamic> result, String prompt) {
    final reference = result['reference_location'];
    if (reference == null &&
        RegExp(
          r'near|closest|around me|berdekatan|terdekat|sekitar|附近|最近',
          caseSensitive: false,
        ).hasMatch(prompt)) {
      _pendingFoodQuestion = prompt;
      return _reply(
        _localized(
          'Which city or landmark should I search near?',
          'Bandar atau mercu tanda manakah yang patut saya gunakan untuk carian berdekatan?',
          '您想查找哪个城市或地标附近的餐饮？',
        ),
      );
    }
    final candidates =
        (result['places'] as List?)?.whereType<Map>() ?? const <Map>[];
    final requiresHalal =
        RegExp(r'\bhalal\b|清真', caseSensitive: false).hasMatch(prompt) &&
        !RegExp(
          r'non[- ]halal|tidak halal|非清真',
          caseSensitive: false,
        ).hasMatch(prompt);
    final rows = requiresHalal
        ? candidates.where((row) => row['is_halal'] == true)
        : candidates;
    if (requiresHalal && rows.isEmpty) {
      return _reply(
        _localized(
          'I couldn’t confirm halal status for any matching food venues.',
          'Saya tidak dapat mengesahkan status halal bagi tempat makan yang sepadan.',
          '我无法确认符合条件的餐饮场所的清真状态。',
        ),
      );
    }
    final text = reference != null
        ? _localized(
            'Food options by distance from $reference, where coordinates are available.',
            'Pilihan makanan mengikut jarak dari $reference, jika koordinat tersedia.',
            '有坐标的餐饮选项按距离 $reference 的远近排列。',
          )
        : _localized(
            'Here are food options from the catalog.',
            'Berikut ialah pilihan makanan daripada katalog.',
            '以下是目录中的餐饮选项。',
          );
    if (rows.isEmpty) {
      _pendingFoodQuestion = prompt;
      return _reply(
        _localized(
          'No food options are available in the catalog. Which city or landmark should I check?',
          'Tiada pilihan makanan dalam katalog. Bandar atau mercu tanda manakah yang patut saya semak?',
          '目录中没有可用的餐饮选项。您想查询哪个城市或地标？',
        ),
      );
    }
    return _reply(
      text,
      places: [
        for (final row in rows)
          _place({
            ...row,
            'catalog_details': [
              if (row['distance_km'] case final double distance)
                '${distance.toStringAsFixed(1)} km',
              switch (row['is_halal']) {
                true => _localized(
                  'Halal · Catalog',
                  'Halal · Katalog',
                  '清真 · 目录',
                ),
                false => _localized(
                  'Non-halal · Catalog',
                  'Tidak halal · Katalog',
                  '非清真 · 目录',
                ),
                _ => _localized(
                  'Halal status unknown',
                  'Status halal tidak diketahui',
                  '清真状态未知',
                ),
              },
            ].join(' · '),
          }),
      ],
    );
  }
}
