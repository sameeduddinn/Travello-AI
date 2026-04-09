import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TicketSettingsPopup extends StatelessWidget {
  const TicketSettingsPopup({super.key, this.whiteIcon = false});

  final bool whiteIcon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.more_horiz, size: 32, color: whiteIcon ? Colors.white : colorScheme(context).onSurfaceVariant),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Widget>>[
        PopupMenuItem<Widget>(
          child: ListTile(
            leading: Transform.flip(flipX: true, child: const Icon(Icons.reply, color: TravelloTheme.primaryMain)),
            title: const Text('Share'),
          ),
        ),
        const PopupMenuItem<Widget>(
          child: ListTile(
            leading: Icon(Icons.download, color: TravelloTheme.primaryMain),
            title: Text('Download'),
          ),
        ),
        const PopupMenuItem<Widget>(
          child: ListTile(
            leading: Icon(Icons.print, color: TravelloTheme.primaryMain),
            title: Text('Print'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<Widget>(
          child: ListTile(
            leading: Icon(CupertinoIcons.question_circle, color: TravelloTheme.primaryMain),
            title: Text('Ask for supports'),
          ),
        ),
        const PopupMenuItem<Widget>(
          child: ListTile(
            leading: Icon(CupertinoIcons.time, color: TravelloTheme.primaryMain),
            title: Text('Reschedule'),
          ),
        ),
        const PopupMenuItem<Widget>(
          child: ListTile(
            leading: Icon(CupertinoIcons.arrow_uturn_left, color: TravelloTheme.primaryMain,),
            title: Text('Request for refund'),
          ),
        ),
      ],
    );
  }
}

class TicketSettingsList extends StatelessWidget {
  const TicketSettingsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TitleBasic(title: 'Other Options', size: 'small',),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () {},
        child: Row(children: [
          const SizedBox(width: 16),
          const Icon(CupertinoIcons.question_circle, color: TravelloTheme.primaryMain),
          const SizedBox(width: 4),
          Text('Ask for support', style: TravelloTheme.paragraph.copyWith(color: TravelloTheme.primaryMain, fontWeight: FontWeight.w500),)
        ]),
      ),
      const VSpaceShort(),
      GestureDetector(
        onTap: () {},
        child: Row(children: [
          const SizedBox(width: 16),
          const Icon(CupertinoIcons.time, color: TravelloTheme.primaryMain),
          const SizedBox(width: 4),
          Text('Reschedule', style: TravelloTheme.paragraph.copyWith(color: TravelloTheme.primaryMain, fontWeight: FontWeight.w500),)
        ]),
      ),
      const VSpaceShort(),
      GestureDetector(
        onTap: () {},
        child: Row(children: [
          const SizedBox(width: 16),
          const Icon(CupertinoIcons.arrow_uturn_left, color: TravelloTheme.primaryMain),
          const SizedBox(width: 4),
          Text('Request for refund', style: TravelloTheme.paragraph.copyWith(color: TravelloTheme.primaryMain, fontWeight: FontWeight.w500),)
        ]),
      ),
    ]);
  }
}

class TicketSettingsBottomSheet extends StatelessWidget {
  const TicketSettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: Transform.flip(flipX: true, child: const Icon(Icons.reply, color: TravelloTheme.primaryMain)),
          title: const Text('Share'),
        ),
        const ListTile(
          leading: Icon(Icons.download, color: TravelloTheme.primaryMain),
          title: Text('Download'),
        ),
        const ListTile(
          leading: Icon(Icons.print, color: TravelloTheme.primaryMain),
          title: Text('Print'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(CupertinoIcons.question_circle, color: TravelloTheme.primaryMain),
          title: Text('Ask for supports'),
        ),
        const ListTile(
          leading: Icon(CupertinoIcons.time, color: TravelloTheme.primaryMain),
          title: Text('Reschedule'),
        ),
        const ListTile(
          leading: Icon(CupertinoIcons.arrow_uturn_left, color: TravelloTheme.primaryMain),
          title: Text('Request for refund'),
        ),
        const VSpace()
      ],
    );
  }
}