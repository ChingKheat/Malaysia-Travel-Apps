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
  });

  /// Converts Cloud Firestore document data to UserModel
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      avatarUrl: data['avatarUrl'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
      nationality: data['nationality'] ?? 'Malaysia 🇲🇾',
      travelStyle: data['travelStyle'] ?? 'Cultural Explorer',
      tripsPlanned: data['tripsPlanned'] ?? 0,
      placesVisited: data['placesVisited'] ?? 0,
      memberSince: data['memberSince'] ?? 'Recent Member',
    );
  }

  /// Converts UserModel to map format stored in Cloud Firestore (FR100_9).
  /// EXCLUDES password per Constraint C8.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'nationality': nationality,
      'travelStyle': travelStyle,
      'tripsPlanned': tripsPlanned,
      'placesVisited': placesVisited,
      'memberSince': memberSince,
    };
  }
}
