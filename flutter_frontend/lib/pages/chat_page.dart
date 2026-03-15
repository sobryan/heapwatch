import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loaded) {
        context.read<ChatProvider>().loadHistory();
        _loaded = true;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    // Scroll to bottom when messages change
    if (chat.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Column(
      children: [
        // Messages area
        Expanded(
          child: chat.messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chat.messages.length && chat.sending) {
                      return _buildTypingIndicator();
                    }
                    final msg = chat.messages[index];
                    return _buildMessageBubble(msg.role, msg.content);
                  },
                ),
        ),

        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 15, color: textColor),
                  decoration: InputDecoration(
                    hintText:
                        'Ask about JVM performance, memory leaks, or get recommendations...',
                    hintStyle:
                        const TextStyle(fontSize: 14, color: textSecondary),
                    filled: true,
                    fillColor: bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                  enabled: !chat.sending,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    chat.sending || _controller.text.trim().isEmpty
                        ? null
                        : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: bgColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy, size: 48, color: textSecondary),
          const SizedBox(height: 12),
          const Text(
            'HeapWatch AI Advisor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me about your JVM performance. Try:',
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 12),
          ...[
            "What's the status of my JVMs?",
            'Analyze heap memory usage',
            'What do you recommend?',
          ].map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () {
                    _controller.text = q;
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: Text(q),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String role, String content) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? primaryDark : surface2Color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 12),
          ),
        ),
        child: SelectableText(
          content,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: isUser ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surface2Color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Analyzing...',
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
