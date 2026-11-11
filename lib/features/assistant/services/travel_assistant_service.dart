import 'dart:async';
import 'package:smart_travel_planner/features/assistant/models/assistant_message.dart';

enum AssistantLanguage {
  english('English', 'en'),
  malay('Bahasa Melayu', 'ms'),
  chinese('中文', 'zh');

  const AssistantLanguage(this.label, this.code);
  final String label;
  final String code;
}

/// Service providing context-aware Malaysian travel intelligence (UC900).
/// Resilient against network drops and offline environments.
class TravelAssistantService {
  factory TravelAssistantService() => _instance;
  TravelAssistantService._internal();
  static final TravelAssistantService _instance = TravelAssistantService._internal();

  AssistantLanguage currentLanguage = AssistantLanguage.english;

  /// Validates user prompt before processing (FR900_2).
  String? validatePrompt(String? prompt) {
    if (prompt == null || prompt.trim().isEmpty) {
      return 'Please enter a travel question or tap a suggestion.';
    }
    if (prompt.trim().length < 2) {
      return 'Prompt is too short. Please be more specific.';
    }
    return null;
  }

  /// Initial greeting message tailored to current language.
  AssistantMessage getInitialGreeting() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: 'msg_welcome',
          text:
              'Selamat Datang! 👋 Saya pembantu perjalanan pintar anda untuk Malaysia. '
              'Tanya saya tentang cadangan tempat menarik, waktu cuaca hujan, makanan halal tempatan, atau semakan jadual.',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '🌧️ Cuaca & hujan di KL hari ini?',
            '🍜 Makanan halal popular di Bukit Bintang',
            '🏛️ Etika melawat Batu Caves',
            '🚇 Cara naik pengangkutan awam ke KLCC',
          ],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: 'msg_welcome',
          text:
              '欢迎来到马来西亚！👋 我是您的 AI 智能旅行助手。'
              '您可以随时向我询问景点推荐、雨天室内备选行程、地道清真美食或行程时间规划。',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '🌧️ 今天吉隆坡会下雨吗？',
            '🍜 武吉免登有哪些必吃清真美食？',
            '🏛️ 黑风洞参观着装与文化礼仪',
            '🚇 如何从中央车站乘坐公共交通到 KLCC？',
          ],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: 'msg_welcome',
          text:
              'Selamat Datang! 👋 I am your AI Travel Assistant for Malaysia. '
              'Ask me for attraction ideas, rainy day indoor backups, authentic local food spots, or help optimizing your schedule.',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '🌧️ Is it going to rain in KL today?',
            '🍜 Best Halal food near Bukit Bintang',
            '🏛️ Cultural etiquette for Batu Caves',
            '🚇 How to get from KL Sentral to KLCC',
          ],
        );
    }
  }

  /// Processes the user prompt with context-aware responses (FR900_4, FR900_5).
  Future<AssistantMessage> askAssistant(String prompt) async {
    // Simulate slight natural latency for typing indicator (FR900_3)
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final normalized = prompt.toLowerCase();

    // 1. Weather & Rain inquiries
    if (normalized.contains('rain') ||
        normalized.contains('weather') ||
        normalized.contains('hujan') ||
        normalized.contains('cuaca') ||
        normalized.contains('雨') ||
        normalized.contains('天气')) {
      return _generateWeatherResponse();
    }

    // 2. Food & Dining inquiries
    if (normalized.contains('food') ||
        normalized.contains('eat') ||
        normalized.contains('makan') ||
        normalized.contains('halal') ||
        normalized.contains('restoran') ||
        normalized.contains('美食') ||
        normalized.contains('吃') ||
        normalized.contains('餐厅')) {
      return _generateFoodResponse();
    }

    // 3. Batu Caves & Cultural Etiquette
    if (normalized.contains('batu cave') ||
        normalized.contains('gua batu') ||
        normalized.contains('etiquette') ||
        normalized.contains('dress') ||
        normalized.contains('pakaian') ||
        normalized.contains('黑风洞') ||
        normalized.contains('礼仪')) {
      return _generateBatuCavesResponse();
    }

    // 4. Transportation & Getting around
    if (normalized.contains('transport') ||
        normalized.contains('mrt') ||
        normalized.contains('lrt') ||
        normalized.contains('grab') ||
        normalized.contains('kl sentral') ||
        normalized.contains('pengangkutan') ||
        normalized.contains('交通') ||
        normalized.contains('地铁')) {
      return _generateTransportResponse();
    }

    // 5. Indoor / Rain-safe Attractions
    if (normalized.contains('indoor') ||
        normalized.contains('museum') ||
        normalized.contains('aquaria') ||
        normalized.contains('muzium') ||
        normalized.contains('dalam bangunan') ||
        normalized.contains('室内') ||
        normalized.contains('博物馆')) {
      return _generateIndoorAttractionsResponse();
    }

    // 6. Translation inquiries
    if (normalized.contains('translate') ||
        normalized.contains('terjemah') ||
        normalized.contains('bahasa') ||
        normalized.contains('翻译') ||
        normalized.contains('语言')) {
      return _generateTranslationResponse();
    }

    // Default Smart General Travel Guide
    return _generateGeneralResponse(prompt);
  }

  AssistantMessage _generateWeatherResponse() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Ramalan cuaca di Lembah Klang menunjukkan kebarangkalian hujan renyai sekitar 3:30 petang. '
              'Untuk keselesaan anda, kami cadangkan persinggahan dalam bangunan seperti Aquaria KLCC atau Muzium Kesenian Islam.',
          isUser: false,
          timestamp: DateTime.now(),
          weatherAlert: const AssistantWeatherAlert(
            city: 'Kuala Lumpur',
            temperature: '29°C',
            condition: 'Hujan Petang',
            rainProbability: 75,
            advisory: 'Hujan lebat diramalkan antara 3:30 PM - 5:00 PM. Laluan pejalan kaki berbumbung disyorkan.',
            suggestedIndoorPlace: 'Aquaria KLCC',
          ),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Aquaria KLCC',
              category: 'Akuarium & Alam Hidupan',
              rating: 4.6,
              location: 'Pusat Konvensyen Kuala Lumpur (KLCC)',
              description: 'Akuarium bertaraf dunia dengan terowong bawah air sepanjang 90 meter.',
              photoUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400&q=80',
              isIndoor: true,
            ),
          ],
          followUpChips: [
            '🏛️ Cadangkan muzium seni lain',
            '☕ Kafe berbumbung berdekatan',
          ],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              '根据气象数据，吉隆坡下午 3:30 左右有 75% 概率出现热带雷阵雨。'
              '建议您将露天行程调换为有顶棚走廊连接的室内景点，例如吉隆坡城中城水族馆（Aquaria KLCC）或柏威年广场。',
          isUser: false,
          timestamp: DateTime.now(),
          weatherAlert: const AssistantWeatherAlert(
            city: 'Kuala Lumpur',
            temperature: '29°C',
            condition: '午后阵雨',
            rainProbability: 75,
            advisory: '预计 15:30 - 17:00 有雷阵雨。推荐使用 KLCC 与 Pavilion 之间的空调全覆盖人行天桥。',
            suggestedIndoorPlace: 'Aquaria KLCC',
          ),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Aquaria KLCC (吉隆坡水族馆)',
              category: '室内景点 & 亲子海洋馆',
              rating: 4.6,
              location: '吉隆坡会展中心地下层 (KLCC)',
              description: '拥有 90 米海底隧道和逾 5,000 种陆生及水生动植物，全程空调舒适防雨。',
              photoUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400&q=80',
              isIndoor: true,
            ),
          ],
          followUpChips: [
            '🏛️ 附近还有哪些室内博物馆？',
            '🚇 KLCC 有直达地铁吗？',
          ],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Scattered tropical thunderstorms are expected around 3:30 PM across central Kuala Lumpur (75% probability). '
              'We suggest keeping indoor backups ready. You can take the fully air-conditioned covered walkway connecting Pavilion KL and Suria KLCC.',
          isUser: false,
          timestamp: DateTime.now(),
          weatherAlert: const AssistantWeatherAlert(
            city: 'Kuala Lumpur',
            temperature: '29°C',
            condition: 'Thunderstorms in PM',
            rainProbability: 75,
            advisory: 'Heavy shower predicted between 3:30 PM and 5:00 PM. Covered pedestrian walkways recommended.',
            suggestedIndoorPlace: 'Aquaria KLCC',
          ),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Aquaria KLCC',
              category: 'Oceanarium & Family',
              rating: 4.6,
              location: 'Kuala Lumpur Convention Centre (Concourse Level)',
              description: 'World-class aquarium with a 90-metre transparent underwater walkway tunnel.',
              photoUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400&q=80',
              isIndoor: true,
            ),
          ],
          followUpChips: [
            '🏛️ Show more indoor museums',
            '☕ Best indoor cafes nearby',
          ],
        );
    }
  }

  AssistantMessage _generateFoodResponse() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Untuk pilihan makanan halal dan rasa tempatan terbaik di Kuala Lumpur, '
              'pastikan anda mencuba Nasi Lemak Wanjo di Kampung Baru, Satay Kajang, dan pelbagai hidangan jalanan di Jalan Alor.',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Jalan Alor Food Street',
              category: 'Makanan Jalanan & Malam',
              rating: 4.5,
              location: 'Bukit Bintang, Kuala Lumpur',
              description: 'Pusat hidangan malam yang meriah dengan sate, char kuey teow, ikan bakar dan buah durian.',
              photoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
            ),
            AssistantPlaceSuggestion(
              name: 'Kampung Baru Food Haven',
              category: 'Masakan Melayu Tradisional (Halal)',
              rating: 4.7,
              location: 'Kampung Baru, Kuala Lumpur',
              description: 'Kampung warisan Melayu terkenal dengan Nasi Lemak Wanjo, bubur lambuk dan roti canai.',
              photoUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=400&q=80',
            ),
          ],
          followUpChips: [
            '🍢 Kedai satay terbaik di KL',
            '☕ Tempat sarapan Roti Canai',
          ],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              '吉隆坡堪称美食天堂！若您想品尝地道风味，阿罗街（Jalan Alor）是体验夜市排档的不二之选。'
              '若追求清真正宗马来餐点，推荐搭乘 MRT 前往甘榜峇鲁（Kampung Baru）品尝热腾腾的椰浆饭与沙爹。',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: '阿罗街美食夜市 (Jalan Alor)',
              category: '街头美食 & 夜市大排档',
              rating: 4.5,
              location: '吉隆坡武吉免登 (Bukit Bintang)',
              description: '集聚炒粿条、黄亚华烤鸡翅、沙爹肉串与猫山王榴莲的著名美食街。',
              photoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
            ),
            AssistantPlaceSuggestion(
              name: '甘榜峇鲁传统马来美食街',
              category: '正宗清真马来料理 (Halal)',
              rating: 4.7,
              location: 'Kampung Baru, Kuala Lumpur',
              description: '著名的吉隆坡传统马来村落，以香浓椰浆饭（Wanjo）、印度煎饼与香辣仁当牛肉闻名。',
              photoUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=400&q=80',
            ),
          ],
          followUpChips: [
            '🥟 茨厂街（唐人街）有哪些推荐？',
            '🍢 哪里能吃到最地道的炭烤沙爹？',
          ],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Malaysia is a global food paradise! For an electrifying hawker evening, visit Jalan Alor in Bukit Bintang. '
              'For authentic Halal Malay cuisine with postcard views of the Petronas Towers, head to Kampung Baru for warm Nasi Lemak and charcoal satay.',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Jalan Alor Food Street',
              category: 'Hawker Street Food & Night Market',
              rating: 4.5,
              location: 'Bukit Bintang, Kuala Lumpur',
              description: 'Iconic bustling food street famous for BBQ chicken wings, satay skewers, char kuey teow and Musang King durian.',
              photoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
            ),
            AssistantPlaceSuggestion(
              name: 'Kampung Baru Food Haven',
              category: 'Authentic Malay Halal Cuisine',
              rating: 4.7,
              location: 'Kampung Baru, Kuala Lumpur',
              description: 'Historic Malay enclave famed for legendary Nasi Lemak Wanjo, beef rendang, and crispy roti canai.',
              photoUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=400&q=80',
            ),
          ],
          followUpChips: [
            '🍢 Best satay spots in town',
            '🥟 Chinatown Petaling Street food',
          ],
        );
    }
  }

  AssistantMessage _generateBatuCavesResponse() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Panduan ke Batu Caves (Gua Batu):\n'
              '• Kod pakaian sopan: Bahu dan lutut mesti ditutup (kain sarung boleh disewa di tangga jika perlu).\n'
              '• Terdapat 272 anak tangga berwarna-warni menuju ke Kuil Gua.\n'
              '• Waktu terbaik melawat adalah awal pagi (7:30 - 9:00 pagi) untuk mengelakkan kepanasan terik dan monyet liar.',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Batu Caves (Gua Batu)',
              category: 'Tarikan Warisan & Budaya',
              rating: 4.6,
              location: 'Gombak, Selangor',
              description: 'Bukit batu kapur dengan patung Dewa Murugan emas setinggi 42.7 meter dan kuil purba.',
              photoUrl: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=400&q=80',
              isIndoor: false,
            ),
          ],
          followUpChips: [
            '🚇 Cara naik KTM Komuter ke Batu Caves',
            '📸 Spot foto terbaik di Batu Caves',
          ],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              '黑风洞（Batu Caves）游玩须知与文化礼仪：\n'
              '• 着装要求：作为印度教朝圣圣地，必须穿着过膝裤装或长裙，肩膀不可裸露（入口处提供围巾租赁服务）。\n'
              '• 272 级彩虹台阶：拾级而上即可抵达主庙洞穴，途中注意随身小物件以防野生猕猴掠夺。\n'
              '• 建议游玩时间：清晨 7:30 - 9:00 前往，避开中午烈日暴晒与游客高峰。',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: '黑风洞 (Batu Caves)',
              category: '印度教圣地 & 石灰岩奇观',
              rating: 4.6,
              location: '雪兰莪鹅唛 (Gombak, Selangor)',
              description: '拥有 42.7 米高的金色室建陀神像、彩虹台阶与四亿年石灰岩溶洞群。',
              photoUrl: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=400&q=80',
              isIndoor: false,
            ),
          ],
          followUpChips: [
            '🚇 如何从吉隆坡乘坐 KTM 到黑风洞？',
            '🎒 景区需要门票吗？',
          ],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Essential Visitor Guide for Batu Caves:\n'
              '• Strict dress code: Shoulders and knees must be covered (sarongs are available for rent at the base).\n'
              '• 272 Rainbow Steps: Climb to the Temple Cave with majestic limestone caverns.\n'
              '• Best timing: Arrive early (7:30 AM – 9:00 AM) to beat the midday tropical heat and avoid active macaque monkeys.',
          isUser: false,
          timestamp: DateTime.now(),
          places: const [
            AssistantPlaceSuggestion(
              name: 'Batu Caves',
              category: 'Cultural & Religious Landmark',
              rating: 4.6,
              location: 'Gombak, Selangor',
              description: 'Limestone hill features a 42.7m golden statue of Lord Murugan and colorful 272 steps.',
              photoUrl: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=400&q=80',
              isIndoor: false,
            ),
          ],
          followUpChips: [
            '🚇 How to take KTM Komuter to Batu Caves',
            '📸 Best photo spots around the caves',
          ],
        );
    }
  }

  AssistantMessage _generateTransportResponse() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Panduan Pengangkutan Awam di Kuala Lumpur:\n'
              '• Stesen KL Sentral adalah hab transit utama yang menghubungkan LRT Kelana Jaya, MRT Kajang Line, KLIA Ekspres dan KTM.\n'
              '• Untuk ke KLCC dari KL Sentral: Ambil LRT Laluan Kelana Jaya terus ke Stesen KLCC (hanya 5 stesen, lebih kurang 12 minit).\n'
              '• Pembayaran: Boleh menggunakan kad Touch \'n Go atau beli token di mesin layan diri stesen.',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '💳 Di mana boleh beli kad Touch \'n Go?',
            '🚗 Tips menggunakan aplikasi Grab',
          ],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              '吉隆坡公共交通便捷指南：\n'
              '• 吉隆坡中央车站（KL Sentral）是核心交通枢纽，整合了机场快线、LRT 轻快铁、MRT 捷运与 KTM 火车。\n'
              '• 从 KL Sentral 到 KLCC：乘坐 LRT 格拉那再也线（红线）直达 KLCC 站，无需换乘，仅需约 12 分钟。\n'
              '• 乘车支付方式：推荐在便利店或轻轨服务台购买 Touch \'n Go 交通卡，也可直接在自动售票机刷卡购买单程代币。',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '💳 哪里可以购买并充值 Touch \'n Go？',
            '🚗 马来西亚用 Grab 打车划算吗？',
          ],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Public Transit Guide for Kuala Lumpur:\n'
              '• KL Sentral is the central transportation hub connecting airport express (KLIA Ekspres), LRT, MRT, and monorail.\n'
              '• KL Sentral to KLCC: Board the Kelana Jaya Line (Red line) directly to KLCC Station (5 stops, ~12 minutes).\n'
              '• Fares & Payment: Use a Touch \'n Go card for seamless contactless tapping across trains and buses.',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '💳 Where to buy a Touch \'n Go card?',
            '🚗 Best practices for using Grab e-hailing',
          ],
        );
    }
  }

  AssistantMessage _generateIndoorAttractionsResponse() {
    return AssistantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          'Top indoor air-conditioned attractions perfect for hot afternoons or sudden rainy spells in Kuala Lumpur:',
      isUser: false,
      timestamp: DateTime.now(),
      places: const [
        AssistantPlaceSuggestion(
          name: 'Petrosains, The Discovery Centre',
          category: 'Sains & Penerokaan Interaktif',
          rating: 4.5,
          location: 'Suria KLCC Level 4',
          description: 'Hands-on interactive science museum suitable for all ages with space and oil exploration rides.',
          photoUrl: 'https://images.unsplash.com/photo-1580674285054-bed31e145f59?w=400&q=80',
          isIndoor: true,
        ),
        AssistantPlaceSuggestion(
          name: 'Islamic Arts Museum Malaysia',
          category: 'Muzium Warisan & Kesenian',
          rating: 4.7,
          location: 'Jalan Lembah Perdana (Near Tasik Perdana)',
          description: 'Largest Islamic art museum in Southeast Asia with 12 galleries of calligraphy, textiles and architectural models.',
          photoUrl: 'https://images.unsplash.com/photo-1548625361-195fe615177a?w=400&q=80',
          isIndoor: true,
        ),
      ],
      followUpChips: [
        '📍 How far is Islamic Arts Museum from KL Sentral?',
        '🎫 Opening hours and ticket prices',
      ],
    );
  }

  AssistantMessage _generateTranslationResponse() {
    switch (currentLanguage) {
      case AssistantLanguage.malay:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Frasa penting pelancongan di Malaysia:\n'
              '• "Terima kasih" = Thank you / 谢谢\n'
              '• "Sama-sama" = You\'re welcome / 不客气\n'
              '• "Berapa harga ini?" = How much is this? / 这个多少钱？\n'
              '• "Tandas di mana?" = Where is the restroom? / 洗手间在哪里？\n'
              '• "Kurang manis" = Less sugar (untuk teh tarik / kopi)',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: ['🍜 Cara pesan kopi dan teh tempatan', '💬 Frasa tawar-menawar di pasar malam'],
        );
      case AssistantLanguage.chinese:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              '马来西亚常用旅游马来语小贴士：\n'
              '• "Terima kasih"（特里玛卡西）= 谢谢\n'
              '• "Sama-sama"（萨玛萨玛）= 不客气\n'
              '• "Berapa harga?"（伯拉帕 哈尔加）= 多少钱？\n'
              '• "Tandas di mana?"（坦达斯 迪马纳）= 洗手间在哪里？\n'
              '• "Kurang manis"（古朗玛尼斯）= 少糖（点拉茶或咖啡时超实用）',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: ['🍜 大马茶餐厅点餐黑话（Kopi-O, Teh C）', '💬 出租车打招呼常用词'],
        );
      case AssistantLanguage.english:
        return AssistantMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text:
              'Useful Malaysian Travel Phrases:\n'
              '• "Terima kasih" = Thank you\n'
              '• "Sama-sama" = You\'re welcome\n'
              '• "Berapa harga?" = How much does this cost?\n'
              '• "Tandas di mana?" = Where is the restroom?\n'
              '• "Kurang manis" = Less sweet / less sugar (handy when ordering Teh Tarik)',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: ['🍜 How to order Malaysian Kopitiam drinks', '💬 Night market bargaining etiquette'],
        );
    }
  }

  AssistantMessage _generateGeneralResponse(String query) {
    return AssistantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text:
          'Regarding "$query": Malaysia is welcoming and easy to navigate! '
          'We recommend combining must-see heritage landmarks (like Merdeka Square and Batu Caves) '
          'with modern spots (KLCC, Saloma Bridge) and vibrant night markets. '
          'Let me know if you would like to add any specific stop to your saved trip itinerary!',
      isUser: false,
      timestamp: DateTime.now(),
      followUpChips: [
        '🌧️ Check weather forecast',
        '🍜 Recommend dinner spots',
        '🗺️ Optimize my schedule',
      ],
    );
  }
}
