import 'package:flutter/material.dart';

import '../app.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Auto-prune candidates'),
                subtitle: const Text(
                    'Remove pencil marks from peers when you place a number.'),
                value: settings.autoPrune,
                onChanged: (v) => settings.autoPrune = v,
              ),
              SwitchListTile(
                title: const Text('Flag mistakes'),
                subtitle: const Text(
                    'Highlight entries that disagree with the solution as you play.'),
                value: settings.flagMistakes,
                onChanged: (v) => settings.flagMistakes = v,
              ),
              SwitchListTile(
                title: const Text('Show timer'),
                subtitle: const Text(
                    'Display the elapsed time and a pause button while playing.'),
                value: settings.showTimer,
                onChanged: (v) => settings.showTimer = v,
              ),
            ],
          );
        },
      ),
    );
  }
}
