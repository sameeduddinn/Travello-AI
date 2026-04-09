import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/chat.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:flight_app/widgets/action_headers/other_btn.dart';
import 'package:flight_app/widgets/chat/chat_input.dart';
import 'package:flight_app/widgets/chat/chat_message.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.messageData, required this.name, required this.avatar});

  final List<MessageItem> messageData;
  final String name;
  final String avatar;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<MessageItem> initMsg = [];
  final _scrollController = ScrollController();

  void _sendMessage(MessageItem message){
    setState(() {
      initMsg.add(message);
    });

    /// Scroll to bottom
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + kToolbarHeight + kBottomNavigationBarHeight + 32,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn
    );
  }

  @override
  void initState() {
    initMsg = widget.messageData;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GeneralLayout(
      content: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              Get.back();
            },
          ),
          title: GestureDetector(
            onTap: () {
              Get.toNamed('/user-profile');
            },
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(widget.avatar)
              ),
              const SizedBox(width: 8),
              Text(widget.name, style: TravelloTheme.subtitle),
            ]),
          ),
          actions: const [
            OtherBtn()
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ChatMessage(
              avatar: widget.avatar,
              name: widget.name,
              chatMessages: initMsg,
              scrollCtrl: _scrollController
            )
          ),
          ChatInput(sendMsg: _sendMessage),
        ]),
      ),
    );
  }
}