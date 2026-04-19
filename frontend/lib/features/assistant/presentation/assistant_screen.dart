import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../dashboard/state/dashboard_provider.dart';
import '../models/chat_message.dart';
import '../state/assistant_provider.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _typingDotController;
  int _lastMessageCount = -1;
  bool _lastLoading = false;
  int? _lastEnsuredShelfId;

  @override
  void initState() {
    super.initState();
    _typingDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _typingDotController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  TextStyle _poppins(BuildContext context, TextStyle? base) {
    return GoogleFonts.poppins(textStyle: base);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final assistant = context.watch<AssistantProvider>();
    final shelfId = dashboard.selectedShelfId;
    final shelfName = dashboard.selectedShelf?.name;
    final shelfLabel = shelfName ?? (shelfId != null ? 'Shelf $shelfId' : '—');

    if (shelfId != null && shelfId != _lastEnsuredShelfId) {
      _lastEnsuredShelfId = shelfId;
      final label = shelfLabel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<AssistantProvider>().ensureShelfContext(shelfId, label);
      });
    }
    if (shelfId == null) {
      _lastEnsuredShelfId = null;
    }

    final msgCount = assistant.messages.length;
    final loading = assistant.isLoading;
    if (msgCount != _lastMessageCount || loading != _lastLoading) {
      _lastMessageCount = msgCount;
      _lastLoading = loading;
      _scrollToBottom();
    }

    final timeFmt = DateFormat.Hm();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'AI-Agronomist · $shelfLabel',
          style: _poppins(context, Theme.of(context).appBarTheme.titleTextStyle),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: dashboard.isLoading ? null : dashboard.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: shelfId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Load the dashboard first to select a shelf.',
                  textAlign: TextAlign.center,
                  style: _poppins(
                    context,
                    Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                if (assistant.error != null)
                  Material(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              assistant.error!,
                              style: _poppins(
                                context,
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: assistant.messages.length + (assistant.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (assistant.isLoading && index == assistant.messages.length) {
                        return _TypingBubble(
                          animation: _typingDotController,
                          poppins: (s) => _poppins(context, s),
                        );
                      }
                      final msg = assistant.messages[index];
                      return _MessageTile(
                        message: msg,
                        timeFmt: timeFmt,
                        poppins: (s) => _poppins(context, s),
                      );
                    },
                  ),
                ),
                _ChatInputBar(
                  controller: _textController,
                  enabled: !assistant.isLoading,
                  bottomInset: MediaQuery.viewInsetsOf(context).bottom,
                  onSend: () async {
                    final text = _textController.text;
                    if (text.trim().isEmpty) return;
                    _textController.clear();
                    await assistant.sendMessage(text, shelfId);
                  },
                  poppins: (s) => _poppins(context, s),
                ),
              ],
            ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.timeFmt,
    required this.poppins,
  });

  final ChatMessage message;
  final DateFormat timeFmt;
  final TextStyle Function(TextStyle? base) poppins;

  static const _emerald = Color(0xFF00E676);
  static const _aiSurface = Color(0xFF1A2332);

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
          child: Column(
            crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.isUser)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _emerald.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      message.text,
                      style: poppins(
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF0B0F14),
                              height: 1.35,
                            ),
                      ),
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _aiSurface.withValues(alpha: 0.55),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.06),
                            _aiSurface.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Text(
                          message.text,
                          style: poppins(
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  height: 1.38,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                timeFmt.format(message.timestamp),
                style: poppins(
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({
    required this.animation,
    required this.poppins,
  });

  final Animation<double> animation;
  final TextStyle Function(TextStyle? base) poppins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332).withValues(alpha: 0.55),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final t = (animation.value + i * 0.22) % 1.0;
                          final y = -5 * math.sin(t * math.pi);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Transform.translate(
                              offset: Offset(0, y),
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Thinking…',
                    style: poppins(
                      Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.bottomInset,
    required this.onSend,
    required this.poppins,
  });

  final TextEditingController controller;
  final bool enabled;
  final double bottomInset;
  final VoidCallback onSend;
  final TextStyle Function(TextStyle? base) poppins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF0B0F14),
      elevation: 12,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF121826),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  style: poppins(theme.textTheme.bodyMedium),
                  decoration: InputDecoration(
                    hintText: 'Ask about VPD, CO₂, climate…',
                    hintStyle: poppins(
                      theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? (_) => onSend() : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: enabled ? onSend : null,
              child: Text(
                'Send',
                style: poppins(theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
