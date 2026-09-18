import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poll.dart';
import '../providers/poll_provider.dart';

/// Kozvelemenykutatas - Kerdőív kartyaja a főoldalon.
///
/// A kartya csak akkor jelenik meg, ha a WordPress szerint van **nyitott**
/// kerdőív, tehat az időablak dontese a szerveren szuletik. Az app nem szamol
/// datumot, így egy elállított keszülék-ido nem tudja kitolni az ablakot.
///
/// Csak regisztralt fiok szavazhat; vendeget a kartya figyelmeztet, de a
/// szavazat VEGSO ellenorzese a szerveren van (a `pollVote` callable), ezert a
/// felulet megkerülése sem ad érvényes szavazatot.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key});

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  int? _selected;
  bool _submitting = false;
  bool _voted = false;
  String? _message;

  int? _statusPollId;
  Future<bool>? _statusFuture;

  /// A "mar szavazott?" allapot kerdőívenkent egyszer kerdődik le.
  Future<bool> _statusFor(int pollId) {
    if (_statusPollId != pollId || _statusFuture == null) {
      _statusPollId = pollId;
      _statusFuture = ref
          .read(pollServiceProvider)
          .hasVoted(pollId)
          .catchError((Object _) => false);
    }
    return _statusFuture!;
  }

  Future<void> _submit(HuhsPoll poll) async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final alreadyVoted = await ref
          .read(pollServiceProvider)
          .vote(pollId: poll.id, optionIndex: selected);
      if (!mounted) return;
      setState(() {
        _voted = true;
        _submitting = false;
        _message = alreadyVoted ? 'Ebben a kérdőívben már szavaztál.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _message = error is Exception
            ? _readableError(error)
            : 'A szavazatot most nem sikerült rögzíteni. Próbáld újra.';
      });
    }
  }

  String _readableError(Exception error) {
    final text = error.toString();
    if (text.contains('unauthenticated') || text.contains('permission-denied')) {
      return 'A szavazáshoz regisztrált fiók szükséges.';
    }
    if (text.contains('failed-precondition') || text.contains('nem elérhető')) {
      return 'A kérdőív jelenleg nem elérhető.';
    }
    if (text.contains('resource-exhausted')) {
      return 'Túl sok próbálkozás. Próbáld kicsit később.';
    }
    return 'A szavazatot most nem sikerült rögzíteni. Próbáld újra.';
  }

  @override
  Widget build(BuildContext context) {
    final poll = ref.watch(activePollProvider);
    return poll.maybeWhen(
      data: (value) => value == null
          ? const SizedBox.shrink()
          : _buildCard(context, value),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context, HuhsPoll poll) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final registered = user != null && !user.isAnonymous;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.poll_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'KÉRDŐÍV',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  poll.question,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (!registered)
                  const Text(
                    'A szavazáshoz regisztrált fiók szükséges. Regisztrálj, vagy jelentkezz be, és utána szavazhatsz.',
                  )
                else
                  FutureBuilder<bool>(
                    future: _statusFor(poll.id),
                    initialData: _voted,
                    builder: (context, status) {
                      final voted = _voted || status.data == true;
                      if (voted) return const _PollThanks();
                      return _buildBallot(context, poll);
                    },
                  ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBallot(BuildContext context, HuhsPoll poll) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plain ListTiles instead of RadioListTile: the Material radio API is
        // being migrated to RadioGroup in this Flutter version, and a poll only
        // needs a single selection that is read back once.
        ...poll.options.map(
          (option) => ListTile(
            onTap: _submitting
                ? null
                : () => setState(() => _selected = option.index),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              _selected == option.index
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _selected == option.index
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(option.label),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _selected == null || _submitting
                ? null
                : () => _submit(poll),
            child: Text(_submitting ? 'Küldés…' : 'Szavazok'),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Egy fiók egyszer szavazhat, a szavazat utólag nem módosítható. Az eredmény nem nyilvános.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }
}

class _PollThanks extends StatelessWidget {
  const _PollThanks();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.check_circle_outline, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('Köszönjük, a szavazatod rögzítettük.')),
      ],
    );
  }
}
