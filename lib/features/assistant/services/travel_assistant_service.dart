import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_travel_planner/core/config/api_keys.dart';
import 'package:smart_travel_planner/core/config/supabase_config.dart';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';
import 'package:smart_travel_planner/features/assistant/services/assistant_system_instruction.dart';
import 'package:smart_travel_planner/features/assistant/services/assistant_tool_handler.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';

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
  http.Client _client = http.Client();
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

  AssistantMessage getInitialGreeting() => AssistantMessage(
    id: 'msg_welcome',
    text: switch (currentLanguage) {
      AssistantLanguage.malay =>
        'Selamat Datang! 👋 Saya pembantu perjalanan pintar anda untuk Malaysia. Tanya saya tentang cadangan tempat menarik, cuaca, makanan halal atau pengangkutan.',
      AssistantLanguage.chinese => '欢迎来到马来西亚！👋 我是您的旅行助手，可以协助景点、天气、清真美食与交通规划。',
      AssistantLanguage.english =>
        'Selamat Datang! 👋 I am your AI Travel Assistant for Malaysia. Ask me about attractions, weather, halal food, transport, or your itinerary.',
    },
    isUser: false,
    timestamp: DateTime.now(),
    followUpChips: const [
      'Check weather forecast',
      'Show indoor attractions',
      'Find halal food',
      'Add a place to my itinerary',
    ],
  );

  Future<AssistantMessage> askAssistant(String prompt) async {
    final text = prompt.trim();
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
    final fallback = await _offlineResponse(text);
    final diagnostic = _userFacingIssue(lastGeminiIssue);
    final response = diagnostic == null
        ? fallback
        : fallback.copyWith(text: '$diagnostic\n\n${fallback.text}');
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
    Map<String, dynamic>? finalData;
    final results = <Map<String, dynamic>>[];
    final executedData = <Map<String, dynamic>>[];
    for (var turn = 0; turn < 5; turn++) {
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$activeModel:generateContent',
      );
      final requestBody = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': assistantSystemInstruction(currentLanguage)},
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
        await Future<void>.delayed(
          Duration(milliseconds: 700 * (attempt + 1)),
        );
      }
      if (switchedAfterTimeout) continue;
      if (response.statusCode == 503 &&
          turn == 0 &&
          activeModel != 'gemini-3.5-flash-lite') {
        activeModel = 'gemini-3.5-flash-lite';
        continue;
      }
      if (response.statusCode != 200) {
        throw StateError('Gemini service returned HTTP ${response.statusCode}.');
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
      if (content == null)
        throw const FormatException('Gemini response contained no content');
      final calls = parts
          .where((p) => p['functionCall'] is Map)
          .map((p) => Map<String, dynamic>.from(p['functionCall'] as Map))
          .toList();
      if (calls.isNotEmpty) {
        _history.add({'role': 'model', 'parts': parts});
        for (final call in calls) {
          final name = call['name']?.toString() ?? '';
          final args = call['args'] is Map
              ? Map<String, dynamic>.from(call['args'] as Map)
              : <String, dynamic>{};
          final result = await toolHandler.execute(name, args);
          results.add({'name': name, 'result': result});
          executedData.add(result);
          if (name == 'search_malaysia_places' && result['places'] is List) {
            for (final raw in result['places'] as List) {
              if (raw is Map)
                finalData ??= _placeData(Map<String, dynamic>.from(raw));
            }
          }
          if (name == 'get_weather_forecast' && result['success'] == true)
            finalData ??= _weatherData(Map<String, dynamic>.from(result));
          if (name == 'add_to_itinerary' && result['success'] == true)
            finalData ??= {
              'text': null,
              'places': <AssistantPlaceSuggestion>[],
            };
        }
        _history.add({
          'role': 'user',
          'parts': [
            for (final item in results)
              {
                'functionResponse': {
                  'name': item['name'],
                  'response': item['result'],
                },
              },
          ],
        });
        continue;
      }
      final text = parts
          .map((p) => p['text']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join('\n')
          .trim();
      if (text.isEmpty)
        throw const FormatException('Gemini response text missing');
      _history.add({
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      });
      final combined = <String, dynamic>{...?finalData};
      for (final result in executedData) {
        if (result['places'] is List) combined['places'] = result['places'];
        if (result['success'] == true && result.containsKey('temperature_c')) {
          combined['weather_alert'] = {
            'city': result['city'],
            'temperature': '${result['temperature_c']}°C',
            'condition': result['condition'],
            'rain_probability': result['rain_probability_percent'],
            'advisory': result['advisory'],
          };
        }
      }
      return _decodeStructured(text, combined);
    }
    throw StateError('Gemini tool loop limit reached');
  }

  AssistantMessage _decodeStructured(
    String raw,
    Map<String, dynamic>? toolData,
  ) {
    var text = raw;
    List<AssistantPlaceSuggestion> places = const [];
    AssistantWeatherAlert? weather;
    List<String> chips = const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        text = map['text']?.toString() ?? raw;
        final placeList = map['places'];
        if (placeList is List)
          places = placeList
              .whereType<Map>()
              .map((p) => _place(Map<String, dynamic>.from(p)))
              .toList();
        final w = map['weather_alert'];
        if (w is Map) weather = _weather(Map<String, dynamic>.from(w));
        if (map['follow_up_chips'] is List)
          chips = (map['follow_up_chips'] as List)
              .whereType<String>()
              .take(4)
              .toList();
      }
    } catch (_) {
      text = raw;
    }
    if (places.isEmpty && toolData?['places'] is List)
      places = (toolData!['places'] as List)
          .whereType<Map>()
          .map((p) => _place(Map<String, dynamic>.from(p)))
          .toList();
    if (weather == null && toolData?['weather_alert'] is Map)
      weather = _weather(
        Map<String, dynamic>.from(toolData!['weather_alert'] as Map),
      );
    if (chips.isEmpty)
      chips = const [
        'Show more indoor attractions',
        'Find halal food nearby',
        'Plan public transport',
      ];
    return AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      places: places,
      weatherAlert: weather,
      followUpChips: chips,
    );
  }

  String _safeGeminiIssue(Object error) {
    if (error is StateError) return error.message;
    if (error is FormatException) return 'Gemini returned an unreadable response.';
    if (error is TimeoutException) return 'Gemini request timed out.';
    return 'Gemini could not be reached. Check the API key and network connection.';
  }

  String? _userFacingIssue(String? issue) {
    if (issue == null) return null;
    if (issue.contains('not configured')) {
      return 'Gemini is not configured for this app build. The assistant is using offline guidance.';
    }
    if (issue.startsWith('Gemini service returned HTTP 401') ||
        issue.startsWith('Gemini service returned HTTP 403')) {
      return 'Gemini rejected the configured API key. Check the key and its API access; the assistant is using offline guidance.';
    }
    if (issue.startsWith('Gemini service returned HTTP 404')) {
      return 'The configured Gemini model is unavailable. Remove any GEMINI_MODEL override or set it to gemini-3.8-flash; the assistant is using offline guidance.';
    }
    if (issue.startsWith('Gemini service returned HTTP 503')) {
      return 'Gemini is temporarily busy after a few retries. Please try again shortly; the assistant is using offline guidance for now.';
    }
    if (issue.contains('timed out')) {
      return 'Gemini did not respond in time, including the backup model. Please try again shortly; the assistant is using offline guidance for now.';
    }
    return 'Gemini could not be reached ($issue). The assistant is using offline guidance.';
  }

  Map<String, dynamic> _placeData(Map<String, dynamic> place) => {
    'places': [place],
  };
  Map<String, dynamic> _weatherData(Map<String, dynamic> data) => {
    'weather_alert': {
      'city': data['city'],
      'temperature': '${data['temperature_c']}°C',
      'condition': data['condition'],
      'rain_probability': data['rain_probability_percent'],
      'advisory': data['advisory'],
    },
  };
  AssistantPlaceSuggestion _place(Map<String, dynamic> p) =>
      AssistantPlaceSuggestion(
        name: p['name']?.toString() ?? 'Place',
        category: p['category']?.toString() ?? 'Attraction',
        rating: (p['rating'] as num?)?.toDouble(),
        location: p['state']?.toString() ?? '',
        description: p['description']?.toString() ?? '',
        photoUrl: p['photo_url']?.toString(),
        isIndoor: p['is_indoor'] == true,
        placeId: p['place_id']?.toString(),
      );
  AssistantWeatherAlert _weather(Map<String, dynamic> w) =>
      AssistantWeatherAlert(
        city: w['city']?.toString() ?? '',
        temperature: w['temperature']?.toString() ?? '',
        condition: w['condition']?.toString() ?? '',
        rainProbability: (w['rain_probability'] as num?)?.round(),
        advisory: w['advisory']?.toString() ?? '',
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

  Future<AssistantMessage> _offlineResponse(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final p = prompt.toLowerCase();
    if (p.contains('weather') ||
        p.contains('rain') ||
        p.contains('cuaca') ||
        p.contains('hujan') ||
        p.contains('天气') ||
        p.contains('雨'))
      return AssistantMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: switch (currentLanguage) {
          AssistantLanguage.malay =>
            'Saya tidak dapat mengesahkan ramalan langsung sekarang. Cuaca Malaysia lazimnya panas dan lembap dengan hujan tropika. Semak ramalan sebelum keluar. Saya juga boleh cadangkan muzium atau tarikan berbumbung.',
          AssistantLanguage.chinese =>
            '目前无法确认实时天气。马来西亚通常炎热潮湿并有热带阵雨，出行前请查看当地预报。我也可以推荐博物馆或室内景点。',
          AssistantLanguage.english =>
            'I can’t verify a live forecast right now. Malaysia is generally hot and humid, with tropical showers common. Check a current forecast before heading out. I can still suggest museums and covered attractions.',
        },
        isUser: false,
        timestamp: DateTime.now(),
        followUpChips: _offlineChips(),
      );
    if (p.contains('batu cave') ||
        p.contains('etiquette') ||
        p.contains('dress') ||
        p.contains('黑风洞'))
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
    return AssistantMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: _offlineGeneralText(),
      isUser: false,
      timestamp: DateTime.now(),
      followUpChips: _offlineChips(),
    );
  }

  List<String> _offlineChips() => switch (currentLanguage) {
    AssistantLanguage.malay => const ['Cadangkan tarikan berbumbung di KL', 'Cari makanan halal', 'Cara guna MRT dan LRT di KL?'],
    AssistantLanguage.chinese => const ['推荐吉隆坡室内景点', '寻找清真美食', '吉隆坡如何乘坐 MRT 和 LRT？'],
    AssistantLanguage.english => const ['Suggest indoor attractions in KL', 'Find halal food in KL', 'How do MRT and LRT work in KL?'],
  };

  String _offlineGeneralText() => switch (currentLanguage) {
    AssistantLanguage.malay => 'Saya boleh membantu merancang perjalanan di Malaysia. Di Kuala Lumpur, MRT/LRT menghubungkan banyak kawasan utama; Touch ’n Go biasa digunakan untuk transit, manakala Grab berguna untuk perjalanan terus. Untuk makanan halal, cari pensijilan halal atau tanya premis. Anda mahu cadangan tarikan berbumbung, makanan halal, atau pengangkutan awam?',
    AssistantLanguage.chinese => '我可以协助规划马来西亚行程。在吉隆坡，MRT/LRT 可到达许多主要区域；Touch ’n Go 常用于公共交通，Grab 适合点对点出行。选择清真餐饮时，请查看清真认证或向店家确认。您想了解室内景点、清真美食，还是公共交通？',
    AssistantLanguage.english => 'I can help plan travel around Malaysia. In Kuala Lumpur, the MRT and LRT connect many major areas; Touch ’n Go is commonly used for transit, while Grab is useful for direct trips. For halal food, look for displayed halal certification or confirm with the venue. Would you like indoor attractions, halal food ideas, or public transport guidance?',
  };
}
