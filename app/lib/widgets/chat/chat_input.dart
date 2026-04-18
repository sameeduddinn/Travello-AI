import 'package:flutter/material.dart';
import 'package:flight_app/models/chat.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.sendMsg,
    this.hasBorder = true,
    this.hintText = 'Write Message'
  });

  final Function(MessageItem) sendMsg;
  final bool hasBorder;
  final String hintText;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final textController = TextEditingController();

  void handleSendMsg(String msgVal) {
    /// Generate Message
    final generateMessage = MessageItem(
      message: msgVal,
      date: DateTime.now().toString(),
      isMe: true
    );

    /// Send Message
    widget.sendMsg(generateMessage);

    /// Clear Textfield
    textController.clear();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        top: 8,
        left: 8,
        right: 8,
        bottom: 24
      ),
      height: 80,
      decoration: const BoxDecoration(
        color: TravelloTheme.paperLightContainerHighest,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: TextField(
            controller: textController,
            style: const TextStyle(height: 1),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: ThemeRadius.big,
                borderSide: BorderSide(color: colorScheme(context).outline),
              ),
              border: OutlineInputBorder(
                borderRadius: ThemeRadius.big,
                borderSide: BorderSide(color: colorScheme(context).outline),
              ),
              filled: true,
              hintText: widget.hintText
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            handleSendMsg(textController.text);
          },
          icon: const Icon(Icons.send, size: 24, color: Colors.white,),
          style: IconButton.styleFrom(
            backgroundColor: TravelloTheme.primaryMain
          )
        )
      ]),
    );
  }
}