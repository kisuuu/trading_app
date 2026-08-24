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
  return showDialog<String>(
    context: context,
    builder: (_) => _NamePromptDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

/// The dialog owns its [TextEditingController].
///
/// Disposing the controller when `showDialog`'s future completes looks
/// equivalent but is not: the future resolves the moment the route is popped,
/// while the dialog keeps rebuilding through its exit transition. The field
/// would then read a disposed controller. Tying the controller to this
/// widget's own lifecycle disposes it only once the dialog is really gone.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection.collapsed(
          offset: widget.initialValue.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Banking',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // Rebuilds as the field changes so an empty name cannot be confirmed.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
