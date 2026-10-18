class UserModel {
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;
  final String avatarUrl;
  final String nationality;
  final String travelStyle;
  final int tripsPlanned;
  final int placesVisited;
  final String memberSince;
  final String preferredLanguage;
  final String role;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.avatarUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
    this.nationality = 'Malaysia 🇲🇾',
    this.travelStyle = 'Cultural Explorer',
    this.tripsPlanned = 0,
    this.placesVisited = 0,
    this.memberSince = 'Recent Member',
    this.preferredLanguage = 'en',
    this.role = 'user',
  });

  /// True if user has administrative privileges to access Admin Database Hub
  bool get isAdmin => role.toLowerCase() == 'admin' || email.toLowerCase().contains('admin');

  /// Factory constructor to deserialize from Supabase `profiles` table row (Table 4.2)
  factory UserModel.fromSupabase(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['full_name'] ?? data['name'] ?? '',
      email: data['email'] ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
      avatarUrl: data['avatar_url'] ?? data['avatarUrl'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
      nationality: data['nationality'] ?? 'Malaysia 🇲🇾',
      travelStyle: data['travel_style'] ?? data['travelStyle'] ?? 'Cultural Explorer',
      tripsPlanned: data['trips_planned'] ?? data['tripsPlanned'] ?? 0,
      placesVisited: data['places_visited'] ?? data['placesVisited'] ?? 0,
      memberSince: data['member_since'] ?? data['memberSince'] ?? 'Recent Member',
      preferredLanguage: data['preferred_language'] ?? 'en',
      role: data['role']?.toString() ?? 'user',
    );
  }

  /// Converts UserModel to map payload for Supabase `profiles` table (Table 4.2)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': uid,
      'email': email,
      'full_name': name,
      'preferred_language': preferredLanguage,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts Cloud Firestore document data to UserModel (backwards-compatible)
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel.fromSupabase(data, id);
  }

  /// Converts UserModel to map format stored in Cloud Firestore (backwards-compatible)
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'user_id': uid,
      'name': name,
      'full_name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'nationality': nationality,
      'travelStyle': travelStyle,
      'tripsPlanned': tripsPlanned,
      'placesVisited': placesVisited,
      'memberSince': memberSince,
    };
  }
}
