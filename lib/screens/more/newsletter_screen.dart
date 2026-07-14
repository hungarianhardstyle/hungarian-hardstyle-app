import 'package:flutter/material.dart';

import '../../core/navigation/in_app_browser.dart';
import '../../services/wordpress_service.dart';

class NewsletterScreen extends StatefulWidget {
  const NewsletterScreen({super.key});

  @override
  State<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen> {
  static const _hostedSignupUrl = 'https://mailchi.mp/fccf4f34b297/hunhs-app';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _service = WordpressService();
  bool _consent = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A feliratkozáshoz fogadd el a hozzájárulást.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.subscribeNewsletter(
        email: _emailController.text,
        consent: _consent,
      );
      if (!mounted) return;
      _emailController.clear();
      setState(() => _consent = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ellenőrizd az e-mail-fiókodat a megerősítéshez.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hírlevél')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 72,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 18),
            const Text(
              'Maradj képben',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Értesülj az új hírekről és fontos eseményekről e-mailben.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'E-mail-cím',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Adj meg érvényes e-mail-címet.';
                  }
                  return null;
                },
              ),
            ),
            CheckboxListTile(
              value: _consent,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _consent = value ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Hozzájárulok a hírlevél küldéséhez.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Feliratkozom'),
            ),
            const SizedBox(height: 14),
            const Text(
              'A feliratkozás megerősítő e-mailhez kötött.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            TextButton(
              onPressed: () => openInAppBrowser(
                context,
                _hostedSignupUrl,
                title: 'Webes hírlevél-feliratkozás',
              ),
              child: const Text('Webes feliratkozási oldal megnyitása'),
            ),
          ],
        ),
      ),
    );
  }
}
