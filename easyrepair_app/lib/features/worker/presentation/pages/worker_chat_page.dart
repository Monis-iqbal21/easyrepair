import 'package:flutter/material.dart';

import '../../../chat/presentation/pages/chat_list_page.dart';
import '../widgets/worker_bottom_nav_bar.dart';

class WorkerChatPage extends StatelessWidget {
  const WorkerChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListPage(
      detailRoutePrefix: '/worker/chat',
      bottomNavigationBar: WorkerBottomNavBar(currentIndex: 2),
    );
  }
}
