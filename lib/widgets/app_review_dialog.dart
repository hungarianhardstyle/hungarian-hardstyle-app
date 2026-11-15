import 'package:flutter/material.dart';

import '../services/app_review_prompt.dart';
import 'app_text.dart';

class AppReviewDialog extends StatelessWidget {
  const AppReviewDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Értékeld az alkalmazást!'),
    content: const AppText(
      'Megosztanád a véleményed a Hungarian Hardstyle alkalmazásról a Google Playen?',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, AppReviewChoice.never),
        child: const AppText('Ne kérdezd többet'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, AppReviewChoice.later),
        child: const AppText('Később'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, AppReviewChoice.rate),
        child: const AppText('Értékelem'),
      ),
    ],
  );
}
