class PlannerSmartFill {
  static Map<String, String> validate(Object? data) {
    if (data is! Map) return {};
    const allowed = {
      'traveler': {'solo', 'couple', 'family', 'friends', 'seniors'},
      'pace': {'relaxed', 'balanced', 'packed'},
      'diet': {'unrestricted', 'halalFriendly', 'vegetarian', 'streetFood'},
      'accommodation': {'Bukit Bintang', 'KLCC', 'KL Sentral'},
      'transport': {'Driving', 'Walking', 'Public Transport', 'E-hailing'},
      'interest': {
        'Culture',
        'Food',
        'Nature',
        'Shopping',
        'History',
        'Adventure',
        'Family',
        'Nightlife',
      },
    };
    return {
      for (final entry in allowed.entries)
        if (entry.value.contains(data[entry.key]))
          entry.key: data[entry.key] as String,
    };
  }

  static Map<String, String> localSuggestions(String description) {
    final value = description.toLowerCase();
    bool mentions(String pattern) => RegExp(pattern).hasMatch(value);
    return {
      if (mentions(r'\b(family|children|kids|parents)\b|家庭|父母|keluarga'))
        'traveler': 'family',
      if (mentions(r'\b(relaxed|slow pace)\b|轻松|santai')) 'pace': 'relaxed',
      if (mentions(r'\bvegetarian\b|素食'))
        'diet': 'vegetarian'
      else if (mentions(r'\bhalal\b|清真'))
        'diet': 'halalFriendly',
      if (mentions(r'\b(local food|street food)\b|美食|makanan tempatan'))
        'interest': 'Food',
    };
  }
}
