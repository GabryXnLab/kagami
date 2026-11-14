/// Messaggi privati: l'elenco delle conversazioni con i non letti e la
/// conversazione. Contratto in `docs/social.md` (`messages`): chi mi scrive lo
/// decide il destinatario, e un rifiuto non dice mai il motivo, nemmeno un
/// blocco. Una richiesta di proroga (`MessageKind.extension`) si legge come
/// frase e, a chi condivide, offre «Rinnova».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/social/backend.dart';
import '../data/social/content.dart';
import '../data/social/profile.dart';
import '../l10n.dart';
import '../providers_shares.dart';
import '../providers_social.dart';
import 'archive_server.dart' show RenewChoice;
import 'social_moderation.dart';
import 'social_tabs.dart';
import 'social_widgets.dart';
import 'theme.dart';
import 'widgets/kit.dart';

Future<void> openConversation(BuildContext context, String peer, {String? name}) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ConversationScreen(peer: peer, name: name)),
    );

/// L'icona della barra della Comunità: apre le conversazioni e dice quanti messaggi non sono letti.
class MessagesButton extends ConsumerWidget {
  const MessagesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(socialUnreadProvider);
    return IconButton(
      tooltip: context.l10n.messagesTitle,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(LucideIcons.messageSquare, size: 20),
      ),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConversationsScreen())),
    );
  }
}

String _extensionLine(AppLocalizations l10n, Message message, String name, {required bool mine}) =>
    mine ? l10n.messagesExtensionMine(message.body) : l10n.messagesExtensionTheirs(name, message.body);

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conversations = ref.watch(socialConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: switch (conversations) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => SocialLoadFailure(error: error, retry: () => ref.invalidate(socialConversationsProvider)),
        AsyncData(:final value) when value.isEmpty => KEmpty(icon: LucideIcons.messageSquare, title: l10n.messagesEmpty),
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [for (final conversation in value) _ConversationTile(conversation: conversation)],
          ),
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = conversation.card?.name.isNotEmpty == true ? conversation.card!.name : l10n.messagesUnknownPerson;
    final me = ref.watch(socialMeProvider);
    final last = conversation.last;
    final line = last.kind == MessageKind.extension ? _extensionLine(l10n, last, name, mine: last.from == me) : last.body;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SocialAvatar(name: name, photo: conversation.card?.photo, size: 44),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: conversation.unread > 0 ? Badge(label: Text('${conversation.unread}')) : null,
      onTap: () => openConversation(context, conversation.peer, name: conversation.card?.name),
    );
  }
}

/// Una conversazione: i messaggi più recenti in basso e il campo per scrivere.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.peer, this.name, super.key});

  final String peer;
  final String? name;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(socialMessagesControllerProvider.notifier).markRead(widget.peer);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => widget.name?.isNotEmpty == true ? widget.name! : context.l10n.messagesUnknownPerson;

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialMessagesControllerProvider.notifier).send(widget.peer, text);
      _controller.clear();
    } on Object {
      // Un blocco, un limite e una rete che manca dicono la stessa cosa.
      if (mounted) _say(context.l10n.socialRefusedSnack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Message message) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.messagesDeleteTitle),
        content: Text(l10n.messagesDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.messagesDeleteAction, style: TextStyle(color: context.tokens.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(socialMessagesControllerProvider.notifier).remove(message, widget.peer);
    } on Object {
      if (mounted) _say(context.l10n.socialRefusedSnack);
    }
  }

  /// Chi condivide rinnova dal messaggio, scegliendo per quanto come sul foglio.
  Future<void> _renew(Message message) async {
    final l10n = context.l10n;
    final duration = await showKagamiSheet<AccessDuration>(
      context,
      title: l10n.messagesRenew,
      builder: (context) => const RenewChoice(),
    );
    if (duration == null || !mounted) return;
    final access = ref.read(driveAccessProvider);
    try {
      if (access == null) throw const SocialUnavailable();
      final share = (await access.mine()).where((row) => row.id == message.share).firstOrNull;
      if (share == null) throw const SocialUnavailable();
      final renewed = await access.renew(share, duration.span);
      if (mounted) _say(l10n.messagesRenewed(renewed.expiresAt!.toLocal()));
    } on Object {
      if (mounted) _say(l10n.socialRefusedSnack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(socialMeProvider);
    final thread = ref.watch(socialThreadProvider(widget.peer));
    // Nuovi arrivi mentre la conversazione è aperta: sono già letti.
    ref.listen(socialThreadProvider(widget.peer), (before, after) {
      final unread = after.value?.any((m) => m.from == widget.peer && m.readAt == null) ?? false;
      if (unread) ref.read(socialMessagesControllerProvider.notifier).markRead(widget.peer);
    });
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      body: Column(
        children: [
          Expanded(
            child: switch (thread) {
              AsyncLoading() => const Center(child: CircularProgressIndicator()),
              AsyncError(:final error) => SocialLoadFailure(error: error, retry: () => ref.invalidate(socialThreadProvider(widget.peer))),
              AsyncData(:final value) when value.isEmpty => KEmpty(icon: LucideIcons.messageSquare, title: l10n.messagesThreadEmpty),
              AsyncData(:final value) => ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final message = value[index];
                    return _Bubble(
                      message: message,
                      mine: message.from == me,
                      name: _name,
                      onDelete: () => _delete(message),
                      onRenew: () => _renew(message),
                    );
                  },
                ),
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: SocialLimits.message,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: l10n.messagesHint),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.messagesSend,
                    icon: const Icon(LucideIcons.send, size: 20),
                    onPressed: _busy ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.name,
    required this.onDelete,
    required this.onRenew,
  });

  final Message message;
  final bool mine;
  final String name;
  final VoidCallback onDelete;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final extension = message.kind == MessageKind.extension;
    final text = extension ? _extensionLine(l10n, message, name, mine: mine) : message.body;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: GestureDetector(
                  onLongPress: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (extension) Icon(LucideIcons.clock, size: 15, color: context.tokens.muted),
                        Text(text, style: KagamiType.body(14.5)),
                        // La proroga la concede chi condivide: solo lui la riceve.
                        if (extension && !mine) ...[
                          const SizedBox(height: 6),
                          KButton(label: l10n.messagesRenew, icon: LucideIcons.refreshCw, height: 38, onPressed: onRenew),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!mine)
                ModerationMenu(
                  uid: message.from,
                  name: name,
                  target: ReportTarget.message,
                  targetId: message.id,
                  snapshot: message.body,
                  icon: Icon(LucideIcons.ellipsisVertical, size: 16, color: context.tokens.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
