class Event {
  final String title;
  final String? description;
  final DateTime dateTime;
  final int timeOnCollegePeriod;

  Event(
      {required this.title, this.description, required this.dateTime, required this.timeOnCollegePeriod});
}