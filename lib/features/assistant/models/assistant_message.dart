class AssistantPlaceSuggestion {
  const AssistantPlaceSuggestion({
    required this.name,
    required this.category,
    this.rating,
    this.location = '',
    this.description = '',
    this.catalogDetails,
    this.photoUrl,
    this.isIndoor = true,
    this.placeId,
  });

  final String name;
  final String category;
  final double? rating;
  final String location;
  final String description;
  final String? catalogDetails;
  final String? photoUrl;
  final bool isIndoor;
  final String? placeId;
}

class AssistantWeatherAlert {
  const AssistantWeatherAlert({
    required this.city,
    required this.temperature,
    required this.condition,
    this.rainProbability,
    required this.advisory,
    this.suggestedIndoorPlace,
  });

  final String city;
  final String temperature;
  final String condition;
  final int? rainProbability;
  final String advisory;
  final String? suggestedIndoorPlace;
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.places = const [],
    this.weatherAlert,
    this.followUpChips = const [],
    this.isTyping = false,
    this._stopProposals = const [],
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AssistantPlaceSuggestion> places;
  final AssistantWeatherAlert? weatherAlert;
  final List<String> followUpChips;
  final bool isTyping;
  final List<Map<String, dynamic>>? _stopProposals;
  List<Map<String, dynamic>> get stopProposals => _stopProposals ?? const [];

  AssistantMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<AssistantPlaceSuggestion>? places,
    AssistantWeatherAlert? weatherAlert,
    List<String>? followUpChips,
    bool? isTyping,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      places: places ?? this.places,
      weatherAlert: weatherAlert ?? this.weatherAlert,
      followUpChips: followUpChips ?? this.followUpChips,
      isTyping: isTyping ?? this.isTyping,
      stopProposals: stopProposals,
    );
  }
}
