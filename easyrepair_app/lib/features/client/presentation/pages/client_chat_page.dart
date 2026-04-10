import 'package:flutter/material.dart';

import '../../../chat/presentation/pages/chat_list_page.dart';
import '../widgets/client_bottom_nav_bar.dart';

class ClientChatPage extends StatelessWidget {
  const ClientChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListPage(
      detailRoutePrefix: '/client/chat',
      bottomNavigationBar: ClientBottomNavBar(currentIndex: 2),
    );
  }
}
