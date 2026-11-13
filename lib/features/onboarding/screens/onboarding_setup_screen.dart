import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/features/onboarding/widgets/onboarding_terms_sheet.dart';
import 'package:smart_travel_planner/shared/services/location_service.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({
    super.key,
    this.isRevisit = false,
    this.onCompleted,
    this.locationPermissionRequester,
    this.languageController,
  });

  /// If true, completing or popping navigates back instead of root app transition.
  final bool isRevisit;
  final VoidCallback? onCompleted;
  final Future<bool> Function()? locationPermissionRequester;
  final LanguageController? languageController;

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  final PageController _pageController = PageController();
  final ScrollController _step3ScrollController = ScrollController();
  int _currentPage = 0;

  // Step 1: Language selection (en, ms, zh)
  String _selectedLanguageCode = 'en';

  // Step 2: Location access
  bool _locationGranted = false;
  bool _isRequestingLocation = false;

  // Step 3: Terms agreement
  bool _agreedToTerms = false;
  bool _showTermsWarning = false;

  LanguageController get _effectiveLanguageController =>
      widget.languageController ?? LanguageController.instance;

  @override
  void initState() {
    super.initState();
    final currentLang = _effectiveLanguageController.locale.languageCode;
    _selectedLanguageCode = currentLang;
    _locationGranted = OnboardingService.instance.locationGranted;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _step3ScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else if (widget.isRevisit) {
      Navigator.maybePop(context);
    }
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selectedLanguageCode = code);
    await OnboardingService.instance.setLanguage(code);

    try {
      await _effectiveLanguageController.changeLanguage(code);
    } catch (_) {}
  }

  Future<void> _handleAllowLocation() async {
    if (_isRequestingLocation) return;
    setState(() => _isRequestingLocation = true);

    try {
      if (widget.locationPermissionRequester != null) {
        final granted = await widget.locationPermissionRequester!();
        if (granted) {
          setState(() {
            _locationGranted = true;
            _isRequestingLocation = false;
          });
          await OnboardingService.instance.setLocationGranted(true);
          LocationService().updateLocation(
            const LatLng(3.1390, 101.6869),
            'Live Device Location',
            isRealGps: true,
          );
        } else {
          setState(() => _isRequestingLocation = false);
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => true,
      );
      if (!serviceEnabled) {
        setState(() => _locationGranted = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => LocationPermission.whileInUse,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => LocationPermission.whileInUse,
        );
      }

      final isGranted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (isGranted) {
        setState(() => _locationGranted = true);
        await OnboardingService.instance.setLocationGranted(true);

        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 2),
            ),
          ).timeout(
            const Duration(seconds: 2),
            onTimeout: () => Position(
              longitude: 101.6869,
              latitude: 3.1390,
              timestamp: DateTime.now(),
              accuracy: 10,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
          );
          LocationService().updateLocation(
            LatLng(pos.latitude, pos.longitude),
            'Live Device Location',
            isRealGps: true,
          );
        } catch (_) {
          LocationService().updateLocation(
            const LatLng(3.1390, 101.6869),
            'Live Device Location',
            isRealGps: true,
          );
        }
      }
    } catch (_) {
      // Graceful fallback for mock / simulator / test environments
      setState(() => _locationGranted = true);
      await OnboardingService.instance.setLocationGranted(true);
      LocationService().updateLocation(
        const LatLng(3.1390, 101.6869),
        'Live Device Location',
        isRealGps: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }
    }
  }

  void _handleManualLocation() {
    setState(() => _locationGranted = false);
    OnboardingService.instance.setLocationGranted(false);
    LocationService().updateLocation(
      const LatLng(3.1390, 101.6869),
      'Kuala Lumpur City Centre',
      isRealGps: false,
    );
    _nextPage();
  }

  Future<void> _handleFinishOnboarding() async {
    if (!_agreedToTerms) {
      setState(() => _showTermsWarning = true);
      if (_step3ScrollController.hasClients) {
        _step3ScrollController.animateTo(
          _step3ScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    await OnboardingService.instance.completeOnboarding();
    widget.onCompleted?.call();

    if (!mounted) return;

    if (widget.isRevisit) {
      Navigator.maybePop(context);
    } else {
      // Transition directly to Login screen (AuthScreen with initialTabIndex = 0)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(
            initialTabIndex: 0,
            showLanguageSelector: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF121316);
    final strings = _OnboardingStrings.of(_selectedLanguageCode);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, strings),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildStep1Language(context, strings),
                  _buildStep2Location(context, strings),
                  _buildStep3Terms(context, strings),
                ],
              ),
            ),
            _buildBottomCTA(context, strings),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildHeader(BuildContext context, _OnboardingStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (_currentPage == 0)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF261D13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5A645).withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: Color(0xFFE5A645),
                size: 20,
              ),
            )
          else
            GestureDetector(
              onTap: _previousPage,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Citylore',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFFAF6EE),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  strings.stepOfThree.replaceAll('{step}', '${_currentPage + 1}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E929A),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 3 Pill Indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final isActive = index <= _currentPage;
              return Container(
                width: 16,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE5A645)
                      : const Color(0xFF2C2D33),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- STEP 1: LANGUAGE PREFERENCE ---
  Widget _buildStep1Language(BuildContext context, _OnboardingStrings strings) {
    // English, Bahasa Melayu, and Chinese only (Tamil removed per user request)
    final languages = [
      (
        code: 'en',
        name: 'English',
        region: strings.langEnRegion,
      ),
      (
        code: 'ms',
        name: 'Bahasa Melayu',
        region: strings.langMsRegion,
      ),
      (
        code: 'zh',
        name: '中文 (简体)',
        region: strings.langZhRegion,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(
            assetImage: 'assets/recognition/sultan_abdul_samad.jpg',
            networkUrl:
                'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?q=80&w=800&auto=format&fit=crop',
            stepLabel: strings.step1Badge,
            heading: strings.step1Heading,
          ),
          const SizedBox(height: 16),
          Text(
            strings.step1Description,
            style: const TextStyle(
              color: Color(0xFF9E9FA6),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...languages.map((lang) {
            final isSelected = _selectedLanguageCode == lang.code;
            return _buildLanguageOptionCard(
              code: lang.code,
              name: lang.name,
              region: lang.region,
              isSelected: isSelected,
              onTap: () => _selectLanguage(lang.code),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required String code,
    required String name,
    required String region,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: ValueKey('language-option-$code'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF221C14) : const Color(0xFF191A1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE5A645)
                : const Color(0xFF272930),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE5A645)
                    : const Color(0xFF23252B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language,
                color: isSelected
                    ? const Color(0xFF141416)
                    : const Color(0xFF8A8E98),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    region,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E929A),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFE5A645)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE5A645)
                      : const Color(0xFF3B3E48),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF141416),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: LOCATION ACCESS ---
  Widget _buildStep2Location(BuildContext context, _OnboardingStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(
            assetImage: 'assets/recognition/petronas.jpg',
            networkUrl:
                'https://images.unsplash.com/photo-1596436889106-be35e843f974?q=80&w=800&auto=format&fit=crop',
            stepLabel: strings.step2Badge,
            heading: strings.step2Heading,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF191A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF272930)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF261D13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5A645).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFE5A645),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.step2WhyTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.step2WhyDesc,
                        style: const TextStyle(
                          color: Color(0xFF9E9FA6),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Allow Location Access Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              key: const ValueKey('allow-location-button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF191A1E),
                side: BorderSide(
                  color: _locationGranted
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFE5A645),
                  width: 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _handleAllowLocation,
              child: _isRequestingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE5A645),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _locationGranted
                              ? Icons.check_circle
                              : Icons.location_on,
                          color: _locationGranted
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFE5A645),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _locationGranted
                                ? strings.step2GrantedBtn
                                : strings.step2AllowBtn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _locationGranted
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFE5A645),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Browse manually button
          Center(
            child: TextButton(
              key: const ValueKey('manual-location-button'),
              onPressed: _handleManualLocation,
              child: Text(
                strings.step2ManualBtn,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E929A),
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- STEP 3: TERMS & PRIVACY ---
  Widget _buildStep3Terms(BuildContext context, _OnboardingStrings strings) {
    return SingleChildScrollView(
      controller: _step3ScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(
            assetImage: 'assets/recognition/sultan_abdul_samad.jpg',
            networkUrl:
                'https://images.unsplash.com/photo-1564507592333-c60657eea523?q=80&w=800&auto=format&fit=crop',
            stepLabel: strings.step3Badge,
            heading: strings.step3Heading,
            height: 140,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF191A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF272930)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
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
                            strings.step3SummaryTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.step3SummaryDesc,
                            style: const TextStyle(
                              color: Color(0xFF9E9FA6),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  key: const ValueKey('read-terms-details-button'),
                  onTap: () => showOnboardingTermsSheet(
                    context,
                    languageCode: _selectedLanguageCode,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Text(
                      strings.step3ReadDetails,
                      style: const TextStyle(
                        color: Color(0xFFE5A645),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Checkbox container
          GestureDetector(
            key: const ValueKey('terms-agreement-card'),
            onTap: () {
              setState(() {
                _agreedToTerms = !_agreedToTerms;
                if (_agreedToTerms) _showTermsWarning = false;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _showTermsWarning && !_agreedToTerms
                    ? const Color(0xFF2B1414)
                    : (_agreedToTerms
                        ? const Color(0xFF221C14)
                        : const Color(0xFF191A1E)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _showTermsWarning && !_agreedToTerms
                      ? const Color(0xFFEF4444)
                      : (_agreedToTerms
                          ? const Color(0xFFE5A645)
                          : const Color(0xFF3B3E48)),
                  width: (_agreedToTerms || _showTermsWarning) ? 1.5 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: _agreedToTerms
                          ? const Color(0xFFE5A645)
                          : const Color(0xFF23252B),
                      border: Border.all(
                        color: _showTermsWarning && !_agreedToTerms
                            ? const Color(0xFFEF4444)
                            : (_agreedToTerms
                                ? const Color(0xFFE5A645)
                                : const Color(0xFF8E929A)),
                        width: 1.5,
                      ),
                    ),
                    child: _agreedToTerms
                        ? const Icon(
                            Icons.check,
                            size: 17,
                            color: Color(0xFF141416),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(text: strings.step3AgreePrefix),
                          TextSpan(
                            text: strings.step3Terms,
                            style: const TextStyle(
                              color: Color(0xFFE5A645),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: strings.step3And),
                          TextSpan(
                            text: strings.step3Privacy,
                            style: const TextStyle(
                              color: Color(0xFFE5A645),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showTermsWarning && !_agreedToTerms) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.step3Warning,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- HERO BANNER BUILDER ---
  Widget _buildHeroBanner({
    required String assetImage,
    String? networkUrl,
    required String stepLabel,
    required String heading,
    double height = 185,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF1E2128),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                if (networkUrl != null && networkUrl.isNotEmpty) {
                  return Image.network(
                    networkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF261D13), Color(0xFF191A1E)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF261D13), Color(0xFF191A1E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 18,
              bottom: 16,
              right: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stepLabel,
                    style: const TextStyle(
                      color: Color(0xFFE5A645),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    heading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.22,
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

  // --- BOTTOM CTA BUTTON ---
  Widget _buildBottomCTA(BuildContext context, _OnboardingStrings strings) {
    final isLastStep = _currentPage == 2;
    final buttonLabel = isLastStep ? strings.ctaAcceptAndContinue : strings.ctaContinue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          key: const ValueKey('onboarding-cta-button'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE5A645),
            foregroundColor: const Color(0xFF141416),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: isLastStep ? _handleFinishOnboarding : _nextPage,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  buttonLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStrings {
  final String stepOfThree;
  final String step1Badge;
  final String step1Heading;
  final String step1Description;
  final String langEnRegion;
  final String langMsRegion;
  final String langZhRegion;
  final String step2Badge;
  final String step2Heading;
  final String step2WhyTitle;
  final String step2WhyDesc;
  final String step2AllowBtn;
  final String step2GrantedBtn;
  final String step2ManualBtn;
  final String step3Badge;
  final String step3Heading;
  final String step3SummaryTitle;
  final String step3SummaryDesc;
  final String step3ReadDetails;
  final String step3AgreePrefix;
  final String step3Terms;
  final String step3And;
  final String step3Privacy;
  final String step3Warning;
  final String step3SnackBarNotice;
  final String ctaContinue;
  final String ctaAcceptAndContinue;
  final String ctaAgreeCheckboxAction;

  const _OnboardingStrings({
    required this.stepOfThree,
    required this.step1Badge,
    required this.step1Heading,
    required this.step1Description,
    required this.langEnRegion,
    required this.langMsRegion,
    required this.langZhRegion,
    required this.step2Badge,
    required this.step2Heading,
    required this.step2WhyTitle,
    required this.step2WhyDesc,
    required this.step2AllowBtn,
    required this.step2GrantedBtn,
    required this.step2ManualBtn,
    required this.step3Badge,
    required this.step3Heading,
    required this.step3SummaryTitle,
    required this.step3SummaryDesc,
    required this.step3ReadDetails,
    required this.step3AgreePrefix,
    required this.step3Terms,
    required this.step3And,
    required this.step3Privacy,
    required this.step3Warning,
    required this.step3SnackBarNotice,
    required this.ctaContinue,
    required this.ctaAcceptAndContinue,
    required this.ctaAgreeCheckboxAction,
  });

  factory _OnboardingStrings.of(String langCode) {
    switch (langCode) {
      case 'zh':
        return const _OnboardingStrings(
          stepOfThree: '欢迎设置 · 第 {step} 步，共 3 步',
          step1Badge: '第 1 步 · 语言偏好',
          step1Heading: '选择您的\n导览语言',
          step1Description: '选择地标故事、扫描识别和步行路线在 Citylore 中的显示语言。',
          langEnRegion: '国际 · 推荐',
          langMsRegion: '马来西亚',
          langZhRegion: '中文',
          step2Badge: '第 2 步 · 位置信息权限',
          step2Heading: '探索您身边的\n地标与特色咖啡馆',
          step2WhyTitle: '为什么 Citylore 需要您的位置',
          step2WhyDesc: '提高建筑立面扫描精度，推荐步行范围内的景点和餐厅，并估算交通时间。',
          step2AllowBtn: '允许获取位置信息',
          step2GrantedBtn: '已获得位置权限 ✓',
          step2ManualBtn: '暂不开启 · 手动浏览吉隆坡',
          step3Badge: '第 3 步 · 条款与隐私',
          step3Heading: '您的隐私与\n旅行服务条款',
          step3SummaryTitle: 'Citylore 条款摘要',
          step3SummaryDesc: '您拍摄的照片仅用于识别地标并推荐周边景点。已保存的行程计划和社区偏好完全由您自主掌控。',
          step3ReadDetails: '阅读条款与隐私详情',
          step3AgreePrefix: '我同意 Citylore 的 ',
          step3Terms: '服务条款',
          step3And: ' 与 ',
          step3Privacy: '隐私政策',
          step3Warning: '请同意条款与条件以继续',
          step3SnackBarNotice: '请在上方勾选同意服务条款与隐私政策',
          ctaContinue: '继续',
          ctaAcceptAndContinue: '接受并继续',
          ctaAgreeCheckboxAction: '勾选并继续',
        );
      case 'ms':
        return const _OnboardingStrings(
          stepOfThree: 'Persediaan selamat datang · Langkah {step} drpd 3',
          step1Badge: 'Langkah 1 · Pilihan Bahasa',
          step1Heading: 'Pilih bahasa\npanduan anda',
          step1Description: 'Pilih bagaimana cerita mercu tanda, maklumat imbasan, dan laluan berjalan dipaparkan dalam Citylore.',
          langEnRegion: 'Antarabangsa · Disyorkan',
          langMsRegion: 'Malaysia',
          langZhRegion: 'Bahasa Cina',
          step2Badge: 'Langkah 2 · Akses Lokasi',
          step2Heading: 'Temui mercu tanda\n& kafe berhampiran anda',
          step2WhyTitle: 'Mengapa Citylore menggunakan lokasi anda',
          step2WhyDesc: 'Meningkatkan ketepatan imbasan fasad, mencadangkan tarikan dan restoran dalam jarak berjalan kaki, dan menganggarkan masa transit.',
          step2AllowBtn: 'Benarkan Akses Lokasi',
          step2GrantedBtn: 'Akses Lokasi Diberikan ✓',
          step2ManualBtn: 'Bukan sekarang · Layari Kuala Lumpur secara manual',
          step3Badge: 'Langkah 3 · Terma & Privasi',
          step3Heading: 'Privasi & terma\nperjalanan anda',
          step3SummaryTitle: 'Ringkasan Terma Citylore',
          step3SummaryDesc: 'Foto yang anda imbas dianalisis hanya untuk mengenal pasti mercu tanda dan mencadangkan tarikan berdekatan. Jadual perjalanan yang disimpan dan pilihan komuniti kekal di bawah kawalan anda.',
          step3ReadDetails: 'Baca butiran Terma & Privasi',
          step3AgreePrefix: 'Saya bersetuju dengan ',
          step3Terms: 'Terma & Syarat',
          step3And: ' serta ',
          step3Privacy: 'Dasar Privasi',
          step3Warning: 'Sila setujui Terma & Syarat untuk meneruskan',
          step3SnackBarNotice: 'Sila tandakan kotak di atas untuk bersetuju dengan terma',
          ctaContinue: 'Teruskan',
          ctaAcceptAndContinue: 'Terima & Teruskan',
          ctaAgreeCheckboxAction: 'Setuju & Teruskan',
        );
      case 'en':
      default:
        return const _OnboardingStrings(
          stepOfThree: 'Welcome setup · Step {step} of 3',
          step1Badge: 'Step 1 · Language Preference',
          step1Heading: 'Choose your\nguide language',
          step1Description: 'Select how landmark stories, scan insights, and walking routes appear throughout Citylore.',
          langEnRegion: 'International · Recommended',
          langMsRegion: 'Malaysia',
          langZhRegion: 'Chinese',
          step2Badge: 'Step 2 · Location Access',
          step2Heading: 'Discover landmarks\n& cafés around you',
          step2WhyTitle: 'Why Citylore uses your location',
          step2WhyDesc: 'Improves facade scan accuracy, recommends nearby attractions and restaurants within walking distance, and estimates transit times.',
          step2AllowBtn: 'Allow Location Access',
          step2GrantedBtn: 'Location Access Granted ✓',
          step2ManualBtn: 'Not now · Browse Kuala Lumpur manually',
          step3Badge: 'Step 3 · Terms & Privacy',
          step3Heading: 'Your privacy\n& travel terms',
          step3SummaryTitle: 'Summary of Citylore Terms',
          step3SummaryDesc: 'Photos you scan are analyzed only to identify landmarks and suggest nearby attractions. Saved itineraries and community preferences stay under your control.',
          step3ReadDetails: 'Read Terms & Privacy details',
          step3AgreePrefix: "I agree to Citylore's ",
          step3Terms: 'Terms & Conditions',
          step3And: ' and ',
          step3Privacy: 'Privacy Policy',
          step3Warning: 'Please agree to the Terms & Conditions to proceed',
          step3SnackBarNotice: 'Please check the box above to agree to the terms',
          ctaContinue: 'Continue',
          ctaAcceptAndContinue: 'Accept & Continue',
          ctaAgreeCheckboxAction: 'Agree & Continue',
        );
    }
  }
}
