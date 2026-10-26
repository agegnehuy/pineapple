import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/files/document_picker.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/coaching/data/coaching_repository.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({
    required this.repository,
    this.pickDocument = selectDocument,
    this.initialPrompt = '',
    super.key,
  });
  final CoachingRepository repository;
  final DocumentPicker pickDocument;
  final String initialPrompt;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _prompt = TextEditingController();
  final _conversationScroll = ScrollController();
  final _messages = <({String role, String text})>[];
  bool _busy = false;
  bool _loadingHistory = false;
  bool _confirming = false;
  bool _allowPop = false;
  bool _useProfile = true;
  bool _useSaved = true;
  String? _conversationId;
  String? _error;
  final _attachments = <String, String>{};

  @override
  void initState() {
    super.initState();
    _prompt.text = widget.initialPrompt;
    _prompt.addListener(_changed);
  }

  void _changed() => setState(() {});

  bool get _controlsBusy => _busy || _loadingHistory || _confirming;

  bool _isActive(BuildContext context) {
    final navigation = WorkspaceNavigationScope.maybeOf(context);
    return navigation == null ||
        ModalRoute.of(context)?.isFirst != true ||
        navigation.selectedIndex == 4;
  }

  Future<void> _leave() async {
    if (_busy ||
        _confirming ||
        (_prompt.text.isEmpty && _attachments.isEmpty)) {
      return;
    }
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const AppText('Discard unsaved changes?'),
        content: const AppText('Your question has not been sent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Discard'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _allowPop = discard == true;
    });
    if (_allowPop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_conversationScroll.hasClients) return;
      final end = _conversationScroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _conversationScroll.jumpTo(end);
      } else {
        _conversationScroll.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _attach() async {
    if (_controlsBusy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await readSelectedDocument(widget.pickDocument);
      if (file == null || !mounted) return;
      final response = await widget.repository.uploadDocument(
        file.name,
        file.bytes,
      );
      final upload = response['upload'] as Map<String, dynamic>;
      if (mounted) {
        setState(
          () => _attachments[upload['id'].toString()] = upload['fileName']
              .toString(),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not attach this document. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _conversationScroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _prompt.text.trim();
    if (_controlsBusy || question.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reply = await widget.repository.ask(
        question,
        conversationId: _conversationId,
        useProfile: _useProfile,
        useSaved: _useSaved,
        attachmentIds: _attachments.keys.toList(),
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply['conversationId'] as String?;
        _messages.add((
          role: 'user',
          text: [
            question,
            if (_attachments.isNotEmpty)
              'Attached: ${_attachments.values.join(', ')}',
          ].join('\n'),
        ));
        _attachments.clear();
        final plan = (reply['plan'] as List? ?? [])
            .map((s) => '• $s')
            .join('\n');
        _messages.add((
          role: 'assistant',
          text: [
            if (reply['aiUnavailable'] == true)
              AppStrings.tr(
                context,
                'AI is currently unavailable. The server provided the guidance below.',
              ),
            (reply['summary'] ?? '').toString(),
            plan,
          ].where((s) => s.isNotEmpty).join('\n\n'),
        ));
        _prompt.clear();
      });
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not get a response. Your question is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _showLatest();
    }
  }

  Future<void> _history() async {
    if (_controlsBusy) return;
    setState(() => _loadingHistory = true);
    try {
      final history = await widget.repository.history();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (history['memoryEnabled'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Saved conversation history is not included with your current plan.',
            ),
          ),
        );
        return;
      }
      final conversations = (history['conversations'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final id = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: AppText('Saved conversations')),
              if (conversations.isEmpty)
                const ListTile(title: AppText('No saved conversations yet')),
              for (final c in conversations)
                ListTile(
                  title: c['title'] == null
                      ? const AppText('Conversation')
                      : Text(c['title'].toString()),
                  onTap: () => Navigator.pop(
                    context,
                    (c['conversationId'] ?? c['id']).toString(),
                  ),
                ),
            ],
          ),
        ),
      );
      if (id == null) return;
      final conversation = await widget.repository.history(id: id);
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages.clear();
        for (final m in conversation['messages'] as List? ?? []) {
          _messages.add((
            role: m['role'].toString(),
            text: m['content'].toString(),
          ));
        }
      });
      _showLatest();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              error is ApiException ? error.message : 'Could not load history.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        !_isActive(context) ||
        _allowPop ||
        (!_busy &&
            !_confirming &&
            _prompt.text.isEmpty &&
            _attachments.isEmpty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: LayoutBuilder(
      builder: (context, viewport) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: _conversationScroll,
              padding: const EdgeInsets.all(24),
              children: [
                AppText(
                  'A little guidance.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const AppText('Your AI companion for the next step.'),
                const SizedBox(height: 16),
                const StatusPill(label: 'AI support · Check important details'),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: _controlsBusy ? null : _history,
                      icon: const Icon(Icons.history),
                      label: const AppText('History'),
                    ),
                    TextButton(
                      onPressed: _controlsBusy
                          ? null
                          : () => setState(() {
                              _messages.clear();
                              _conversationId = null;
                            }),
                      child: const AppText('New conversation'),
                    ),
                  ],
                ),
                ExpansionTile(
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : null,
                  tilePadding: EdgeInsets.zero,
                  title: const AppText('Personalization'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Use my profile'),
                      value: _useProfile,
                      onChanged: _controlsBusy
                          ? null
                          : (v) => setState(() => _useProfile = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Use my saved opportunities'),
                      value: _useSaved,
                      onChanged: _controlsBusy
                          ? null
                          : (v) => setState(() => _useSaved = v),
                    ),
                  ],
                ),
                if (_messages.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'What would you like to work on?',
                    message:
                        'Ask about an opportunity, your story, or your next application step. AI guidance can use your saved profile when enabled.',
                  ),
                for (final message in _messages)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Align(
                      alignment: message.role == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: message.role == 'user' ? 0.88 : 1,
                        child: Card(
                          color: message.role == 'user'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  message.role == 'user' ? 'You' : 'MyOccasio',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: message.role == 'user'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : null,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  message.text,
                                  style: TextStyle(
                                    color: message.role == 'user'
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: AppText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: viewport.maxHeight * 0.45),
            child: SingleChildScrollView(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_attachments.isNotEmpty)
                        SizedBox(
                          height:
                              (MediaQuery.textScalerOf(context).scale(14) *
                                          1.5 +
                                      24)
                                  .clamp(52, 120),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final file in _attachments.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InputChip(
                                    label: Text(file.value),
                                    deleteButtonTooltipMessage: AppStrings.tr(
                                      context,
                                      'Remove from this question',
                                    ),
                                    onDeleted: _controlsBusy
                                        ? null
                                        : () => setState(
                                            () => _attachments.remove(file.key),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _prompt,
                              enabled: !_controlsBusy,
                              maxLength: 12000,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr(
                                  context,
                                  'Ask a question…',
                                ),
                                counterText: '',
                              ),
                            ),
                          ),
                          IconButton.filled(
                            tooltip: AppStrings.tr(context, 'Send question'),
                            onPressed:
                                _controlsBusy || _prompt.text.trim().isEmpty
                                ? null
                                : _send,
                            icon: _busy
                                ? SizedBox.square(
                                    dimension: 20,
                                    child: AppBusyIndicator(
                                      label: 'Waiting for response',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: AppStrings.tr(context, 'Attach document'),
                            onPressed: _controlsBusy ? null : _attach,
                            icon: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                      const AppText(
                        'Attachments are uploaded to your account and included with your question.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
