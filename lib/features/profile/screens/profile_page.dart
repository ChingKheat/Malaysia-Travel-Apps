import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:smart_travel_planner/features/profile/services/profile_avatar_service.dart';

import 'package:smart_travel_planner/features/itinerary/screens/my_trips_screen.dart';
import 'package:smart_travel_planner/features/itinerary/screens/planner_page.dart';
import 'package:smart_travel_planner/features/itinerary/services/supabase_itinerary_service.dart';
import 'package:smart_travel_planner/features/profile/services/travel_footprint.dart';
import 'package:smart_travel_planner/features/profile/widgets/profile_sheets.dart';
import 'package:smart_travel_planner/l10n/localized_labels.dart';
import 'package:flutter/material.dart';
import 'package:smart_travel_planner/core/localization/language_controller.dart';
import 'package:smart_travel_planner/shared/widgets/language_selector.dart';

import 'package:smart_travel_planner/core/theme/app_colors.dart';
import 'package:smart_travel_planner/core/theme/app_decorations.dart';
import 'package:smart_travel_planner/shared/utils/demo_feedback.dart';
import 'package:smart_travel_planner/features/auth/services/auth_service.dart';
import 'package:smart_travel_planner/features/auth/screens/auth_screen.dart';
import 'package:smart_travel_planner/features/admin/screens/admin_places_screen.dart';
import 'package:smart_travel_planner/features/onboarding/screens/onboarding_setup_screen.dart';
import 'package:smart_travel_planner/features/onboarding/services/onboarding_service.dart';
import 'package:smart_travel_planner/shared/models/attraction.dart';
import 'package:smart_travel_planner/features/places/services/place_wishlist_store.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_detail_page.dart';
import 'package:smart_travel_planner/features/places/screens/attraction_list_screen.dart';
import 'package:smart_travel_planner/features/places/utils/attraction_image_resolver.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onMyTripsTap, this.imagePicker});

  final VoidCallback? onMyTripsTap;
  final ImagePicker? imagePicker;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final _authService = AuthService();
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  final _trips = SupabaseItineraryService();
  TravelFootprint? _footprint;
  int? _tripCount;
  bool _savingPhoto = false;
  int _statsRequest = 0;
  List<Attraction> _savedPlaces = [];
  bool _savedPlacesLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trips.addListener(_loadStats);
    _loadStats(refresh: true);
    _loadSavedPlaces();
    unawaited(_authService.syncAvatar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trips.removeListener(_loadStats);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_authService.syncAvatar());
      _loadSavedPlaces();
    }
  }

  Future<void> _loadSavedPlaces() async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    try {
      final places = await PlaceWishlistStore(uid).load();
      if (mounted) {
        setState(() {
          _savedPlaces = places;
          _savedPlacesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savedPlacesLoaded = true);
      }
    }
  }

  Future<void> _removeSavedPlace(Attraction place) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    demoHaptic();
    try {
      await PlaceWishlistStore(uid).remove(place.xid);
      if (mounted) {
        setState(() {
          _savedPlaces.removeWhere((p) => p.xid == place.xid);
        });
        showDemoSnackBar(
          context,
          context.l10n.removedValueFromSaved(place.name),
        );
      }
    } catch (_) {}
  }

  Future<void> _openAttractionDetails(Attraction place) async {
    final uid = _authService.currentUser?.uid ?? 'guest';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttractionDetailPage(
          attraction: place,
          isSaved: true,
          onToggleSaved: (p) {
            PlaceWishlistStore(uid).toggle(p);
            return true;
          },
        ),
      ),
    );
    if (mounted) _loadSavedPlaces();
  }

  Widget _buildPlaceThumbnail(Attraction place) {
    final asset = AttractionImageResolver.resolveAsset(place);
    final photoUrl = AttractionImageResolver.resolvePhotoUrl(place);
    final (color, icon, _) = ModernAttractionCard.getCategoryMeta(
      place.category,
    );

    Widget fallback() =>
        ModernAttractionCard.buildFallbackThumbnail(color, icon);

    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (photoUrl != null) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return fallback();
  }

  void _showSavedPlacesSheet() {
    showProfileSheet<void>(
      context,
      title: context.l10n.yourSavedPlaces,
      body: (sheetContext) {
        if (_savedPlaces.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                context.l10n.noSavedPlacesYet,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < _savedPlaces.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  color: AppColors.nightLine,
                  indent: 60,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildPlaceThumbnail(_savedPlaces[i]),
                  ),
                ),
                title: Text(
                  _savedPlaces[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  _savedPlaces[i].category.isNotEmpty
                      ? _savedPlaces[i].category
                      : context.l10n.attractions,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.bookmark_remove_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  tooltip: context.l10n.removeFromSaved,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _removeSavedPlace(_savedPlaces[i]);
                  },
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _openAttractionDetails(_savedPlaces[i]);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _loadStats({bool refresh = false}) async {
    final request = ++_statsRequest;
    final uid = _authService.currentUser?.uid;
    final trips = await _trips.getSavedItineraries(refresh: refresh);
    final footprint = await TravelFootprint.fromTrips(trips);
    if (!mounted ||
        request != _statsRequest ||
        uid != _authService.currentUser?.uid) {
      return;
    }
    setState(() {
      _tripCount = trips.length;
      _footprint = footprint;
    });
  }

  Future<void> _changePhoto() async {
    if (_savingPhoto) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 78,
      );
      if (picked == null || !mounted) return;
      setState(() => _savingPhoto = true);
      final bytes = await picked.readAsBytes();
      if (ProfileAvatarService.format(bytes) == null) {
        if (mounted) {
          showDemoSnackBar(context, context.l10n.profilePhotoInvalid);
        }
        return;
      }
      final saved = await _authService.updateAvatar(bytes);
      if (!mounted) return;
      if (saved) {
        setState(() {});
        showDemoSnackBar(context, context.l10n.profilePhotoSaved);
      } else {
        showDemoSnackBar(context, context.l10n.profileSaveFailed);
      }
    } catch (_) {
      if (mounted) showDemoSnackBar(context, context.l10n.profileSaveFailed);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _openTrips() async {
    final open = widget.onMyTripsTap;
    if (open != null) {
      Navigator.pop(context);
      open();
      return;
    }
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MyTripsScreen(
          onBackTap: () => navigator.pop(),
          onPlanTap: () => navigator.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PlannerPage(onItineraryReady: () => navigator.pop()),
            ),
          ),
        ),
      ),
    );
    if (mounted) _loadStats();
  }

  void _showFootprint() {
    final footprint = _footprint;
    if (footprint == null) return;
    showProfileSheet<void>(
      context,
      title: context.l10n.profileFootprint,
      body: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.l10n.placesVisited} · ${context.localNumber(footprint.places.length)}',
          ),
          if (footprint.places.isEmpty) ...[
            const SizedBox(height: 8),
            Text(context.l10n.profileNoVisits),
          ],
          for (final name in footprint.places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.place_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                name == 'Saved Google place'
                    ? context.l10n.savedGooglePlace
                    : name,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialName: user.name,
        email: user.email,
        initialPhone: user.phone,
        initialNationality: user.nationality,
        onSave: (name, phone, nationality) => _authService.updateProfile(
          name: name,
          phone: phone,
          nationality: nationality,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    setState(() {});
    showDemoSnackBar(context, AuthService.m1ProfileUpdated);
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.logOut),
        content: Text(
          dialogContext.l10n.areYouSureYouWantToLogOutOfYourTravelProfile,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              final messenger = ScaffoldMessenger.of(context);
              final loggedOutMsg = context.l10n.successfullyLoggedOut;

              await _authService.logout();

              if (mounted) {
                final targetScreen = !OnboardingService.instance.isCompleted
                    ? const OnboardingSetupScreen()
                    : const AuthScreen(
                        initialTabIndex: 0,
                        showLanguageSelector: false,
                      );

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => targetScreen),
                  (route) => false,
                );
              }

              demoHaptic();
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.logout_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(loggedOutMsg)),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 3),
                  ),
                );
            },
            child: Text(
              dialogContext.l10n.logOut,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.l10n.noActiveProfileFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.myProfile,
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        backgroundColor: AppColors.nightSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.nightAccentContainer,
                    foregroundImage: ProfileAvatarService.imageProvider(
                      user.avatarUrl,
                    ),
                    onForegroundImageError: (_, _) {},
                    child: const Icon(
                      Icons.person_outline,
                      size: 42,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('profile-change-photo'),
                    onPressed: _savingPhoto ? null : _changePhoto,
                    icon: _savingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(context.l10n.profileChangePhoto),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Travel preferences are shown in their own section below.
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  _profileDetail(Icons.explore_outlined, user.travelStyle),
                  if (user.nationality.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _profileDetail(
                      Icons.public_outlined,
                      user.nationality.trim(),
                    ),
                  ],
                  if (user.phone.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _profileDetail(Icons.phone_outlined, user.phone.trim()),
                  ],
                  if (user.isAdmin) ...[
                    const SizedBox(height: 8),
                    _profileDetail(
                      Icons.admin_panel_settings_outlined,
                      context.l10n.admin,
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.l10n.editProfile),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildStatistics(),
            const SizedBox(height: 20),
            _buildSavedPlacesSection(),
            const SizedBox(height: 20),

            // Profile Settings
            Container(
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      context.l10n.accountSettings,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _buildListTile(
                    icon: Icons.language,
                    title: context.l10n.appLanguage,
                    subtitle:
                        LanguageController.languageNames[LanguageScope.of(
                          context,
                        ).locale.languageCode]!,
                    onTap: () => showLanguageSelector(context),
                  ),
                  const Divider(height: 1, color: AppColors.line, indent: 56),
                  _buildListTile(
                    icon: Icons.auto_stories_outlined,
                    title: _setupGuideTitle(context),
                    subtitle: _setupGuideSubtitle(context),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OnboardingSetupScreen(isRevisit: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // General & Support
            Container(
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      context.l10n.information,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _buildListTile(
                    icon: Icons.emergency_outlined,
                    title: context.l10n.profileHotlines,
                    subtitle: context.l10n.profileHotlinesSubtitle,
                    onTap: () => showEmergencyHotlines(context),
                  ),
                  if (user.isAdmin) ...[
                    const Divider(height: 1, color: AppColors.line, indent: 56),
                    _buildListTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: context.l10n.adminDatabaseHub,
                      subtitle: user.isAdmin
                          ? context.l10n.secretPortalToFetchSyncPlaces
                          : context.l10n.adminHubAccess,
                      onTap: () {
                        if (_authService.currentUser?.isAdmin != true) {
                          _showAdminLoginDialog(context);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPlacesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: Text(
                  context.l10n.logOut,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileDetail(IconData icon, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.nightRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.nightLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.nightAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.nightBody,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlacesSection() {
    final places = _savedPlaces;

    return Container(
      width: double.infinity,
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.yourSavedPlaces,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (places.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      context.localNumber(places.length),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (places.length > 3) ...[
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: _showSavedPlacesSheet,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        context.l10n.seeAll,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (places.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.noSavedPlacesYet,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.scanWishlistEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Divider(height: 1, color: AppColors.nightLine),
            for (
              var i = 0;
              i < (places.length > 3 ? 3 : places.length);
              i++
            ) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  color: AppColors.nightLine,
                  indent: 76,
                ),
              _buildSavedPlaceTile(places[i]),
            ],
            if (places.length > 3) ...[
              const Divider(height: 1, color: AppColors.nightLine),
              InkWell(
                onTap: _showSavedPlacesSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${context.l10n.seeAll} (${places.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSavedPlaceTile(Attraction place) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAttractionDetails(place),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: _buildPlaceThumbnail(place),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.category.isNotEmpty
                          ? place.category
                          : context.l10n.attractions,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.bookmark_remove_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                tooltip: context.l10n.removeFromSaved,
                onPressed: () => _removeSavedPlace(place),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final count = _tripCount;
    final footprint = _footprint;
    final cards = [
      _buildStatCard(
        context.l10n.tripsPlanned,
        count == null ? null : context.localNumber(count),
        Icons.event_note,
        _openTrips,
      ),
      _buildStatCard(
        context.l10n.savedAttractions,
        _savedPlacesLoaded ? context.localNumber(_savedPlaces.length) : null,
        Icons.bookmark_outline_rounded,
        _showSavedPlacesSheet,
      ),
      _buildStatCard(
        context.l10n.placesVisited,
        footprint == null ? null : context.localNumber(footprint.places.length),
        Icons.explore_outlined,
        footprint == null ? null : _showFootprint,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = width / scale >= 540 ? 3 : 2;
        const gap = 8.0;

        final rows = <List<Widget>>[];
        for (var i = 0; i < cards.length; i += columns) {
          final end = (i + columns < cards.length) ? i + columns : cards.length;
          rows.add(cards.sublist(i, end));
        }

        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < rows[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: gap),
                      Expanded(child: rows[r][c]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String? value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final decoration = cardDecoration();
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: decoration.borderRadius as BorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value ?? '—',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _setupGuideTitle(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'zh':
        return '欢迎设置导览 (3步)';
      case 'ms':
        return 'Panduan Persediaan (3 Langkah)';
      default:
        return 'Welcome Setup Guide (3 Steps)';
    }
  }

  String _setupGuideSubtitle(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'zh':
        return '重新查看语言选择、位置授权与服务条款';
      case 'ms':
        return 'Semak semula pilihan bahasa, lokasi dan terma';
      default:
        return 'Review language, location and travel terms';
    }
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.muted,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAdminLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text(ctx.l10n.adminHubAccess)),
          ],
        ),
        content: Text(ctx.l10n.profileAdminSignIn),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.email,
    required this.initialPhone,
    required this.initialNationality,
    required this.onSave,
  });

  final String initialName;
  final String email;
  final String initialPhone;
  final String initialNationality;
  final Future<bool> Function(String, String, String) onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalityController;
  String? _inlineError;
  bool _saving = false;

  bool get _hasChanges =>
      _nameController.text.trim() != widget.initialName.trim() ||
      _phoneController.text.trim() != widget.initialPhone.trim() ||
      _nationalityController.text.trim() != widget.initialNationality.trim();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _nationalityController = TextEditingController(
      text: widget.initialNationality,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving || !_hasChanges) return;
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _inlineError = context.tr(AuthService.m2NameRequired);
      });
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    final saved = await widget.onSave(
      text,
      _phoneController.text.trim(),
      _nationalityController.text.trim(),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _inlineError = context.tr(AuthService.m3ProfileSaveError);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: AppColors.nightSurface,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.nightLine, width: 1),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clean dialog header with title, subtitle, and close button
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.nightRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.nightLine),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.editProfile2,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.nightMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.nightMuted,
                      ),
                      splashRadius: 18,
                      tooltip: context.l10n.cancel,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.nightLine),
                const SizedBox(height: 16),

                // Individual Rounded Soft Card 1: Full Name
                _buildFieldCard(
                  label: context.l10n.fullName2,
                  icon: Icons.badge_outlined,
                  isRequired: true,
                  errorText: _inlineError,
                  child: TextField(
                    controller: _nameController,
                    readOnly: _saving,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (_inlineError != null) {
                        setState(() => _inlineError = null);
                      } else {
                        setState(() {});
                      }
                    },
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: context.l10n.eGAliBinAhmad,
                      hintStyle: TextStyle(
                        color: AppColors.nightMuted.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Individual Rounded Soft Card 2: Email Address (Read-only)
                _buildFieldCard(
                  label: context.l10n.emailAddress,
                  icon: Icons.email_outlined,
                  isReadOnly: true,
                  child: TextFormField(
                    initialValue: widget.email,
                    readOnly: true,
                    style: const TextStyle(
                      color: AppColors.nightMuted,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Individual Rounded Soft Card 3: Phone Number
                _buildFieldCard(
                  label: context.l10n.phone,
                  icon: Icons.phone_outlined,
                  child: TextField(
                    controller: _phoneController,
                    readOnly: _saving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '+60 12 345 6789',
                      hintStyle: TextStyle(
                        color: AppColors.nightMuted.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Individual Rounded Soft Card 4: Country / Region
                _buildFieldCard(
                  label: context.l10n.profileCountry,
                  icon: Icons.public_outlined,
                  child: TextField(
                    controller: _nationalityController,
                    readOnly: _saving,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _handleSave(),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'e.g. Malaysia',
                      hintStyle: TextStyle(
                        color: AppColors.nightMuted.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Horizontal Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.nightMuted,
                          side: const BorderSide(color: AppColors.nightLine),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          context.l10n.cancel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _hasChanges && !_saving ? _handleSave : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onNightAccent,
                          disabledBackgroundColor: AppColors.nightRaised,
                          disabledForegroundColor: AppColors.nightMuted
                              .withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.onNightAccent,
                                  ),
                                ),
                              )
                            : Text(
                                context.l10n.save,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required String label,
    required IconData icon,
    required Widget child,
    bool isReadOnly = false,
    bool isRequired = false,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isReadOnly ? AppColors.nightCanvas : AppColors.nightRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? Colors.redAccent : AppColors.nightLine,
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasError ? Colors.redAccent : AppColors.nightMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (isRequired)
                    const Text(
                      ' *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  if (isReadOnly) ...[
                    const Spacer(),
                    const Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: AppColors.nightMuted,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isReadOnly
                        ? AppColors.nightMuted.withValues(alpha: 0.5)
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }
}
