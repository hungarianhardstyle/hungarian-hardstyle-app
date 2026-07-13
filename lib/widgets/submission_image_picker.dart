import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/submission_image.dart';

class SubmissionImagePicker extends StatelessWidget {
  static const maxBytes = 5 * 1024 * 1024;

  final SubmissionImage? image;
  final String title;
  final String helperText;
  final ValueChanged<SubmissionImage?> onChanged;

  const SubmissionImagePicker({
    super.key,
    required this.image,
    required this.title,
    required this.helperText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(helperText, style: const TextStyle(color: Colors.white60)),
          if (image != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.memory(
                  image!.bytes,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              image!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(image == null ? 'Kép kiválasztása' : 'Csere'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Fotó készítése'),
              ),
              if (image != null)
                TextButton.icon(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Törlés'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!context.mounted) return;

      if (bytes.length > maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A kép legfeljebb 5 MB lehet.')),
        );
        return;
      }

      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JPG, PNG vagy WebP képet válassz.')),
        );
        return;
      }

      onChanged(SubmissionImage(bytes: bytes, name: file.name));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem sikerült kiválasztani a képet.')),
      );
    }
  }
}
