import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/models/notification.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/widgets/notifications/filters.dart';
import 'package:flight_app/widgets/notifications/notif_item.dart';

class NotificationsList extends StatefulWidget {
  const NotificationsList({super.key});

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList> {
  List _filteredItems = [];
  String _selectedFilter = 'all';
  bool _isClear = false;

  void handleFilter(type) {
    var result = notifList.where((item) => item.type == type).toList();

    setState(() {
      _selectedFilter = type;
      if (type != 'all') {
        _filteredItems = result;
      } else {
        _filteredItems = notifList;
      }
    });
  }

  @override
  void initState() {
    setState(() {
      _filteredItems = notifList;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacingUnit(2)),
              child: Text('${_filteredItems.length} Notifications'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isClear = true;
                  _filteredItems = [];
                });
              },
              child: const Row(children: [
                Icon(Icons.clear_all_outlined, size: 18),
                SizedBox(
                  width: 4,
                ),
                Text('Clear All')
              ]),
            ),
          ],
        ),

        /// FILTER
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(2)),
          child: NotificationFilters(
            selected: _selectedFilter,
            onChangeFilter: handleFilter,
          ),
        ),

        /// NOTIFICATION ITEMS
        _isClear
            ? _emptyList(context)
            : Expanded(
                child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _filteredItems.length,
                    padding: EdgeInsets.only(bottom: spacingUnit(3)),
                    itemBuilder: ((BuildContext context, int index) {
                      NotificationModel item = _filteredItems[index];
                      return NotifItem(
                          type: item.type,
                          title: item.title,
                          subtitle: item.subtitle,
                          date: item.date,
                          image: item.image,
                          isRead: item.isRead,
                          isLast: true);
                    })),
              ),
      ],
    );
  }

  Widget _emptyList(BuildContext context) {
    return NoData(
      image: ImgApi.emptyNotification,
      title: 'All Clear Now',
      desc: "You're all caught up! No new notifications at the moment.",
    );
  }
}
