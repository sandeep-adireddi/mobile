import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lichess_mobile/src/utils/async_value.dart';
import 'package:lichess_mobile/src/features/user/domain/user.dart';
import 'package:lichess_mobile/src/features/authentication/ui/auth_widget.dart';
import 'package:lichess_mobile/src/features/authentication/ui/auth_widget_notifier.dart';
import 'package:lichess_mobile/src/features/authentication/data/auth_repository.dart';
import '../../domain/game.dart';
import '../board/screen.dart';
import './time_control_modal.dart';
import './form_providers.dart';
import './play_action_notifier.dart';

const maiaChoices = [
  ComputerOpponent.maia1,
  ComputerOpponent.maia5,
  ComputerOpponent.maia9,
];

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('lichess.org'), actions: const [
        AuthWidget(),
      ]),
      body: Center(
        child: authState.maybeWhen(
          data: (account) => PlayForm(account: account),
          orElse: () => const CircularProgressIndicator.adaptive(),
        ),
      ),
    );
  }
}

class PlayForm extends ConsumerWidget {
  const PlayForm({this.account, super.key});

  final User? account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opponentPref = ref.watch(computerOpponentPrefProvider);
    final stockfishLevel = ref.watch(stockfishLevelProvider);
    final maiaBots = ref.watch(maiaBotsProvider);
    final timeControlPref = ref.watch(timeControlPrefProvider);
    final authActionsAsync = ref.watch(authWidgetProvider);
    final playActionAsync = ref.watch(playActionProvider);

    ref.listen<AsyncValue>(playActionProvider, (_, state) {
      state.showSnackbarOnError(context);

      if (state.valueOrNull is Game) {
        ref.invalidate(playActionProvider);
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
              builder: (context) => BoardScreen(game: state.value!)),
        );
      }
    });

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20.0),
      children: [
        Row(
          children: const [
            Text(
              'Play with the computer',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 5),
            Tooltip(
              message:
                  'Maia is a human-like neural network chess engine. It was trained by learning from over 10 million Lichess games.',
              child: Icon(Icons.help_sharp),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          children: [
            Wrap(
              spacing: 10.0,
              children: maiaChoices.map((opponent) {
                final isSelected = opponentPref == opponent;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check, size: 18),
                        const SizedBox(width: 3),
                      ],
                      Text(opponent.name),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    if (selected) {
                      ref
                          .read(computerOpponentPrefProvider.notifier)
                          .set(opponent);
                    }
                  },
                );
              }).toList(),
            ),
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (opponentPref == ComputerOpponent.stockfish) ...[
                    const Icon(Icons.check, size: 18),
                    const SizedBox(width: 3),
                  ],
                  const Text('Fairy-Stockfish 14'),
                ],
              ),
              selected: opponentPref == ComputerOpponent.stockfish,
              onSelected: (bool selected) {
                if (selected) {
                  ref
                      .read(computerOpponentPrefProvider.notifier)
                      .set(ComputerOpponent.stockfish);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 5),
        Builder(builder: (BuildContext context) {
          int value = stockfishLevel;
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return Slider(
              value: value.toDouble(),
              min: 1,
              max: 8,
              divisions: 8,
              label: 'Level $value',
              onChanged: opponentPref != ComputerOpponent.stockfish
                  ? null
                  : (double newVal) {
                      setState(() {
                        value = newVal.round();
                      });
                    },
              onChangeEnd: (double value) {
                ref.read(stockfishLevelProvider.notifier).set(value.round());
              },
            );
          });
        }),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: opponentPref == ComputerOpponent.stockfish
                ? const Text('Fairy-Stockfish 14')
                : Text(opponentPref.name, style: _titleStyle),
            subtitle: opponentPref == ComputerOpponent.stockfish
                ? Text('Level $stockfishLevel')
                : maiaBots.when(
                    data: (bots) {
                      final bot = bots
                          .firstWhere((b) => b.item1.id == opponentPref.name)
                          .item1;
                      return Row(
                        children:
                            [Perf.blitz, Perf.rapid, Perf.classical].map((p) {
                          return Row(children: [
                            Icon(p.icon, size: 14.0),
                            const SizedBox(width: 3.0),
                            Text(bot.perfs[p]!.rating.toString()),
                            const SizedBox(width: 12.0),
                          ]);
                        }).toList(),
                      );
                    },
                    error: (err, __) {
                      debugPrint(
                          'SEVERE [PlayScreen] could not load bot info: ${err.toString()}');
                      return const Text('Could not load bot ratings.');
                    },
                    loading: () => const CircularProgressIndicator.adaptive(),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        OutlinedButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (BuildContext context) {
                return const TimeControlModal();
              },
            );
          },
          style: _buttonStyle,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(timeControlPref.perf.icon, size: 20),
                      const SizedBox(width: 5),
                      Text(timeControlPref.value.toString())
                    ],
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 28.0),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: account == null
              ? authActionsAsync.isLoading
                  ? null
                  : () => ref.read(authWidgetProvider.notifier).signIn()
              : playActionAsync.isLoading
                  ? null
                  : () => ref.read(playActionProvider.notifier).createGame(
                      account: account!,
                      opponent: opponentPref,
                      timeControl: timeControlPref.value,
                      level: stockfishLevel),
          style: _buttonStyle,
          child: authActionsAsync.isLoading || playActionAsync.isLoading
              ? const CircularProgressIndicator.adaptive()
              : Text(account == null ? 'Sign in to start playing' : 'Play'),
        ),
      ],
    );
  }
}

final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
  textStyle: const TextStyle(fontSize: 20),
);
const TextStyle _titleStyle = TextStyle(fontSize: 18);
