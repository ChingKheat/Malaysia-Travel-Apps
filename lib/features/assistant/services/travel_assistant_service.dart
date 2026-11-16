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
    followUpChips: switch (currentLanguage) {
      AssistantLanguage.malay => const [
        '🌧️ Is it going to rain today in KL?',
        '🍜 Best Halal food around Bukit Bintang',
        '🏛️ Tarikan kebudayaan popular',
        '🚆 Cara ke KL Sentral dari KLIA',
      ],
      AssistantLanguage.chinese => const [
        '🌧️ Is it going to rain today in KL?',
        '🍜 Best Halal food around Bukit Bintang',
        '🏛️ 值得一游的吉隆坡文化景点',
        '🚆 如何从 KLIA 坐车到 KL Sentral',
      ],
      AssistantLanguage.english => const [
        '🌧️ Is it going to rain today in KL?',
        '🍜 Best Halal food around Bukit Bintang',
        '🏛️ Top cultural places to visit',
        '🚆 How to travel from KLIA to KL Sentral',
      ],
    },
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
      if (content == null) {
        throw const FormatException('Gemini response contained no content');
      }
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
              if (raw is Map) {
                finalData ??= _placeData(Map<String, dynamic>.from(raw));
              }
            }
          }
          if (name == 'get_weather_forecast' && result['success'] == true) {
            finalData ??= _weatherData(Map<String, dynamic>.from(result));
          }
          if (name == 'add_to_itinerary' && result['success'] == true) {
            finalData ??= {
              'text': null,
              'places': <AssistantPlaceSuggestion>[],
            };
          }
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
      if (text.isEmpty) {
        throw const FormatException('Gemini response text missing');
      }
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
        if (placeList is List) {
          places = placeList
              .whereType<Map>()
              .map((p) => _place(Map<String, dynamic>.from(p)))
              .toList();
        }
        final w = map['weather_alert'];
        if (w is Map) weather = _weather(Map<String, dynamic>.from(w));
        if (map['follow_up_chips'] is List) {
          chips = (map['follow_up_chips'] as List)
              .whereType<String>()
              .take(4)
              .toList();
        }
      }
    } catch (_) {
      text = raw;
    }
    if (places.isEmpty && toolData?['places'] is List) {
      places = (toolData!['places'] as List)
          .whereType<Map>()
          .map((p) => _place(Map<String, dynamic>.from(p)))
          .toList();
    }
    if (weather == null && toolData?['weather_alert'] is Map) {
      weather = _weather(
        Map<String, dynamic>.from(toolData!['weather_alert'] as Map),
      );
    }
    if (chips.isEmpty) {
      chips = const [
        'Show more indoor attractions',
        'Find halal food nearby',
        'Plan public transport',
      ];
    }
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
        p.contains('雨')) {
      return AssistantMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: switch (currentLanguage) {
          AssistantLanguage.malay =>
            'Ramalan cuaca di Lembah Klang menunjukkan kebarangkalian hujan renyai sekitar petang. Untuk keselesaan anda, kami cadangkan persinggahan dalam bangunan seperti Aquaria KLCC atau Muzium Kesenian Islam.',
          AssistantLanguage.chinese =>
            '根据气象数据，吉隆坡午后有概率出现热带雷阵雨。建议您将行程调换为有顶棚走廊连接的室内景点，例如吉隆坡城中城水族馆（Aquaria KLCC）。',
          AssistantLanguage.english =>
            'Scattered tropical thunderstorms are expected around 3:30 PM across central Kuala Lumpur (75% probability). We suggest keeping indoor backups ready such as Aquaria KLCC.',
        },
        isUser: false,
        timestamp: DateTime.now(),
        weatherAlert: AssistantWeatherAlert(
          city: 'Kuala Lumpur',
          temperature: '29°C',
          condition: switch (currentLanguage) {
            AssistantLanguage.malay => 'Hujan Petang',
            AssistantLanguage.chinese => '午后阵雨',
            AssistantLanguage.english => 'Thunderstorms in PM',
          },
          rainProbability: 75,
          advisory: switch (currentLanguage) {
            AssistantLanguage.malay =>
              'Hujan lebat diramalkan petang ini. Laluan pejalan kaki berbumbung disyorkan.',
            AssistantLanguage.chinese => '预计午后有雷阵雨。推荐使用空调全覆盖人行天桥。',
            AssistantLanguage.english =>
              'Heavy shower predicted between 3:30 PM and 5:00 PM. Covered pedestrian walkways recommended.',
          },
          suggestedIndoorPlace: 'Aquaria KLCC',
        ),
        places: [
          AssistantPlaceSuggestion(
            name: switch (currentLanguage) {
              AssistantLanguage.chinese => 'Aquaria KLCC (吉隆坡水族馆)',
              _ => 'Aquaria KLCC',
            },
            category: switch (currentLanguage) {
              AssistantLanguage.malay => 'Akuarium & Alam Hidupan',
              AssistantLanguage.chinese => '室内景点 & 亲子海洋馆',
              AssistantLanguage.english => 'Oceanarium & Family',
            },
            rating: 4.6,
            location: switch (currentLanguage) {
              AssistantLanguage.malay => 'Pusat Konvensyen Kuala Lumpur (KLCC)',
              AssistantLanguage.chinese => '吉隆坡会展中心地下层 (KLCC)',
              AssistantLanguage.english =>
                'Kuala Lumpur Convention Centre (Concourse Level)',
            },
            description: switch (currentLanguage) {
              AssistantLanguage.malay =>
                'Akuarium bertaraf dunia dengan terowong bawah air sepanjang 90 meter.',
              AssistantLanguage.chinese => '拥有 90 米海底隧道和逾 5,000 种动植物，全程空调舒适防雨。',
              AssistantLanguage.english =>
                'World-class aquarium with a 90-metre transparent underwater walkway tunnel.',
            },
            photoUrl:
                'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400&q=80',
            isIndoor: true,
          ),
        ],
        followUpChips: _offlineChips(),
      );
    }
    if (p.contains('food') ||
        p.contains('halal') ||
        p.contains('makan') ||
        p.contains('alor') ||
        p.contains('bukit bintang') ||
        p.contains('美食') ||
        p.contains('清真')) {
      return AssistantMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: switch (currentLanguage) {
          AssistantLanguage.malay =>
            'Untuk pilihan makanan halal dan rasa tempatan terbaik di Kuala Lumpur, pastikan anda mencuba pelbagai hidangan jalanan di Jalan Alor dan Kampung Baru.',
          AssistantLanguage.chinese =>
            '吉隆坡堪称美食天堂！若您想品尝地道风味，阿罗街（Jalan Alor）是体验夜市排档的不二之选。',
          AssistantLanguage.english =>
            'Malaysia is a global food paradise! For an electrifying hawker evening, visit Jalan Alor in Bukit Bintang.',
        },
        isUser: false,
        timestamp: DateTime.now(),
        places: [
          AssistantPlaceSuggestion(
            name: switch (currentLanguage) {
              AssistantLanguage.chinese => '阿罗街美食夜市 (Jalan Alor)',
              _ => 'Jalan Alor Food Street',
            },
            category: switch (currentLanguage) {
              AssistantLanguage.malay => 'Makanan Jalanan & Malam',
              AssistantLanguage.chinese => '街头美食 & 夜市大排档',
              AssistantLanguage.english => 'Street Food & Night Market',
            },
            rating: 4.5,
            location: switch (currentLanguage) {
              AssistantLanguage.chinese => '吉隆坡武吉免登 (Bukit Bintang)',
              _ => 'Bukit Bintang, Kuala Lumpur',
            },
            description: switch (currentLanguage) {
              AssistantLanguage.malay =>
                'Pusat hidangan malam yang meriah dengan pelbagai gerai makanan halal dan jalanan.',
              AssistantLanguage.chinese => '集聚炒粿条、烤鸡翅、沙爹肉串与热带水果的著名美食街。',
              AssistantLanguage.english =>
                'Famous street food haven with extensive local halal and street delicacies.',
            },
            photoUrl:
                'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
            isIndoor: false,
          ),
        ],
        followUpChips: _offlineChips(),
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
