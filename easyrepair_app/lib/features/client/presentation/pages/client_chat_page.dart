import 'package:flutter/material.dart';

import '../../../chat/presentation/pages/chat_list_page.dart';

class ClientChatPage extends StatelessWidget {
  const ClientChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListPage(
      detailRoutePrefix: '/client/chat',
      homeRoute: '/client/home',
      bottomNavigationBar: SizedBox.shrink(),
    );
  }
}
