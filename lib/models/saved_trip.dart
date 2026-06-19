class SavedTrip {
  const SavedTrip({
    required this.title,
    required this.date,
    required this.detail,
    required this.destination,
    required this.budget,
    required this.interests,
  });

  final String title;
  final String date;
  final String detail;
  final String destination;
  final String budget;
  final List<String> interests;
}
