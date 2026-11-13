import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';

Future<void> showOnboardingTermsSheet(
  BuildContext context, {
  String? languageCode,
}) {
  final lang = languageCode ??
      LanguageController.instance.locale.languageCode;

  final content = _TermsContent.forLanguage(lang);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141519),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B3E48),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF261D13),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE5A645).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFE5A645),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            content.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF8E929A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF90939A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF26282E), height: 24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: content.sections.length,
                    itemBuilder: (context, index) {
                      final s = content.sections[index];
                      return _TermsSection(
                        number: '${index + 1}',
                        title: s.title,
                        body: s.body,
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE5A645),
                          foregroundColor: const Color(0xFF141416),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          content.buttonLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _TermsContent {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final List<({String title, String body})> sections;

  const _TermsContent({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.sections,
  });

  factory _TermsContent.forLanguage(String lang) {
    switch (lang) {
      case 'zh':
        return const _TermsContent(
          title: '服务条款与隐私政策',
          subtitle: 'Citylore 智能旅行导览 · 马来西亚',
          buttonLabel: '我已了解',
          sections: [
            (
              title: '服务范围与 Citylore 导览',
              body:
                  'Citylore 为前往马来西亚的游客提供智能行程规划、地标视觉识别、精选步行路线以及文化历史故事。所有功能旨在为游客提供教育及出行规划便利。',
            ),
            (
              title: '地标识别与相机使用规范',
              body:
                  '通过应用拍摄的照片仅在本地及高安全计算机视觉引擎中分析，专门用于识别建筑立面、历史遗迹和文化地标。图像绝不向第三方出售，亦不用于人脸识别或商业广告。',
            ),
            (
              title: '位置信息与本地周边发现',
              body:
                  '在启用位置信息时，Citylore 会为您计算步行距离、估算交通耗时并推荐附近的咖啡馆和旅游景点。您可以随时在手机系统设置中关闭位置权限，或选择手动浏览城市目的地。',
            ),
            (
              title: '数据隐私与合规 (PDPA 2010)',
              body:
                  '严格遵循马来西亚 2010 年个人数据保护法 (PDPA) 与国际隐私合规准则。您保存的行程计划与个人偏好均在安全加密下存储，离线缓存方案确保在未连接互联网时仍能安心使用。',
            ),
            (
              title: '用户权利与账户自主权',
              body:
                  '您对自己保存的所有旅行计划、笔记和个人资料享有完全掌控权。您可以随时在“账户设置”中导出或删除您的个人数据。',
            ),
          ],
        );
      case 'ms':
        return const _TermsContent(
          title: 'Terma & Dasar Privasi',
          subtitle: 'Panduan Pintar Citylore · Malaysia',
          buttonLabel: 'Saya Faham',
          sections: [
            (
              title: 'Skop Perkhidmatan & Panduan Citylore',
              body:
                  'Citylore menyediakan jadual perjalanan pintar, pengecaman mercu tanda, laluan berjalan kaki terpilih, dan naratif sejarah untuk pelancong di Malaysia. Ciri-ciri ini disediakan untuk tujuan pendidikan dan bantuan perancangan perjalanan.',
            ),
            (
              title: 'Pengecaman Mercu Tanda & Penggunaan Kamera',
              body:
                  'Foto yang diimbas diproses secara selamat pada peranti dan analisis penglihatan komputer semata-mata untuk mengenal pasti fasad seni bina dan mercu tanda budaya. Imej tidak akan dijual kepada pihak ketiga atau digunakan untuk pengecaman wajah atau pengiklanan.',
            ),
            (
              title: 'Maklumat Lokasi & Penemuan Tempatan',
              body:
                  'Apabila akses lokasi diaktifkan, Citylore mengira jarak berjalan kaki, anggaran masa transit, dan meneroka kafe serta tarikan berhampiran. Anda boleh mematikan akses lokasi pada bila-bila masa atau memilih melayari secara manual.',
            ),
            (
              title: 'Privasi Data & Pematuhan (PDPA 2010)',
              body:
                  'Mematuhi sepenuhnya Akta Perlindungan Data Peribadi Malaysia 2010 (PDPA) dan amalan terbaik privasi antarabangsa. Jadual perjalanan dan pilihan pengguna anda disimpan dengan selamat dan disulitkan, dengan sokongan luar talian yang selamat.',
            ),
            (
              title: 'Hak Pengguna & Kawalan Akaun',
              body:
                  'Anda mempunyai kawalan penuh terhadap semua rancangan perjalanan, nota, dan profil anda. Anda boleh mengeksport atau memadam data anda pada bila-bila masa melalui Tetapan Akaun.',
            ),
          ],
        );
      case 'en':
      default:
        return const _TermsContent(
          title: 'Terms & Privacy Policy',
          subtitle: 'Citylore Smart Travel Guide · Malaysia',
          buttonLabel: 'I Understand',
          sections: [
            (
              title: 'Scope of Service & Citylore Guide',
              body:
                  'Citylore provides tourists and travelers with intelligent scheduling, landmark recognition, curated walking routes, and contextual historical narratives for points of interest across Malaysia. Features are provided for educational and trip planning assistance.',
            ),
            (
              title: 'Landmark Recognition & Camera Usage',
              body:
                  'Photographs scanned through the app are processed on-device and via secure computer vision analysis solely to identify architectural facades, monuments, and cultural landmarks. Images are never sold to third parties or used for facial recognition or commercial advertising.',
            ),
            (
              title: 'Location Information & Local Discovery',
              body:
                  'When location access is enabled, Citylore calculates walking distances, estimates transit durations, and discovers nearby cafes and attractions. You may revoke location access anytime or choose to browse destinations manually.',
            ),
            (
              title: 'Data Privacy & Compliance (PDPA 2010)',
              body:
                  'In full compliance with Malaysia\'s Personal Data Protection Act 2010 (PDPA) and international privacy best practices, your saved itineraries and user preferences remain encrypted. Offline fallbacks ensure full data privacy without requiring external internet transmission for cached trips.',
            ),
            (
              title: 'User Rights & Account Control',
              body:
                  'You retain complete control of your saved travel plans, notes, and profile. You may export or delete your stored data anytime through Account Settings.',
            ),
          ],
        );
    }
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF261D13),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFFE5A645),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xFF9E9FA6),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
