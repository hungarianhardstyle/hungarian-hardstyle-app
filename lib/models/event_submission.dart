class EventSubmission {
  final String title;
  final String startDate;
  final String startTime;
  final String endDate;
  final String endTime;
  final String venueName;
  final String venueCity;
  final String venueAddress;
  final String organizerName;
  final int organizerId;
  final List<String> genres;
  final String contactEmail;
  final String eventUrl;
  final String description;
  final String flyerUrl;

  const EventSubmission({
    required this.title,
    required this.startDate,
    required this.startTime,
    this.endDate = '',
    this.endTime = '',
    required this.venueName,
    required this.venueCity,
    this.venueAddress = '',
    required this.organizerName,
    this.organizerId = 0,
    required this.genres,
    required this.contactEmail,
    required this.eventUrl,
    required this.description,
    this.flyerUrl = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'start_date': startDate.trim(),
      'start_time': startTime.trim(),
      'end_date': endDate.trim(),
      'end_time': endTime.trim(),
      'venue_name': venueName.trim(),
      'venue_city': venueCity.trim(),
      'venue_address': venueAddress.trim(),
      'organizer_name': organizerName.trim(),
      'organizer_id': organizerId,
      'genres': genres,
      'contact_email': contactEmail.trim(),
      'event_url': eventUrl.trim(),
      'description': description.trim(),
      'flyer_url': flyerUrl.trim(),
      'website': '',
    };
  }
}
