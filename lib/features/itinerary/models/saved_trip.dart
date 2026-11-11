class SavedTrip {
  const SavedTrip({
    required this.title,
    required this.date,
    required this.detail,
    required this.destination,
    required this.budget,
    required this.interests,
    this.totalDays = 3,
    this.startsOn,
    this.isGenerated = false,
  });

  final String title;
  final String date;
  final String detail;
  final String destination;
  final String budget;
  final List<String> interests;
  final int totalDays;

  /// Typed presentation metadata; does not change stored itinerary records.
  final DateTime? startsOn;
  final bool isGenerated;
}
