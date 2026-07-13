import 'dart:typed_data';

class SubmissionImage {
  final Uint8List bytes;
  final String name;

  const SubmissionImage({required this.bytes, required this.name});
}
