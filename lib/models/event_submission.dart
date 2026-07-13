class EventSubmission {
  final String title;
  final String startDate;
  final String startTime;
  final String venueName;
  final String venueCity;
  final String organizerName;
  final List<String> genres;
  final String contactEmail;
  final String eventUrl;
  final String description;

  const EventSubmission({
    required this.title,
    required this.startDate,
    required this.startTime,
    required this.venueName,
    required this.venueCity,
    required this.organizerName,
    required this.genres,
    required this.contactEmail,
    required this.eventUrl,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'start_date': startDate.trim(),
      'start_time': startTime.trim(),
      'venue_name': venueName.trim(),
      'venue_city': venueCity.trim(),
      'organizer_name': organizerName.trim(),
      'genres': genres,
      'contact_email': contactEmail.trim(),
      'event_url': eventUrl.trim(),
      'description': description.trim(),
      'website': '',
    };
  }
}
