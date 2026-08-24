import 'package:flutter/material.dart';

import '../../domain/watchlist.dart';

/// Horizontal selector across the user's watchlists, with a trailing action to
/// create another. Scrolls rather than truncating, so any number of lists is
/// reachable.
class WatchlistTabBar extends StatelessWidget {
  const WatchlistTabBar({
    required this.watchlists,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
    super.key,
  });

  final List<Watchlist> watchlists;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: watchlists.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == watchlists.length) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New'),
              onPressed: onCreate,
            );
          }
          final watchlist = watchlists[index];
          return ChoiceChip(
            label: Text('${watchlist.name}  ·  ${watchlist.length}'),
            selected: watchlist.id == selectedId,
            onSelected: (_) => onSelected(watchlist.id),
          );
        },
      ),
    );
  }
}

/// Prompts for a watchlist name. Returns `null` when cancelled.
Future<String?> promptWatchlistName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Banking',
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
