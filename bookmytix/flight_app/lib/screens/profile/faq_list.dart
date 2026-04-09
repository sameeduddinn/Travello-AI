import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/search_filters/search_input_btn.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/models/faq.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FaqList extends StatefulWidget {
  const FaqList({super.key});

  @override
  State<FaqList> createState() => _FaqListState();
}

class _FaqListState extends State<FaqList> {
  bool _showSearch = false;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final isGuest = await AuthService.isGuestMode();

    if (isGuest) {
      final guestUser = AuthService.getGuestUser();
      setState(() {
        _userName = guestUser['name'];
      });
    } else {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _userName = user['name'] ?? 'User';
        });
      } else {
        setState(() {
          _userName = 'Guest User';
        });
      }
    }
  }

  void toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
        titleSpacing: 0,
        title: _showSearch
            ? Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
                child: SearchInputBtn(
                  location: '/search-list',
                  title: 'Search Topic',
                  onCancel: () {
                    toggleSearch();
                  },
                ),
              )
            : Container(),
        centerTitle: true,
        actions: [
          /// SEARCH BUTTON
          !_showSearch
              ? IconButton(
                  icon: const Icon(Icons.search, size: 32, color: Colors.black),
                  onPressed: () {
                    toggleSearch();
                  },
                )
              : Container(),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: TravelloTheme.secondaryMain),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// BANNER
            Padding(
              padding: EdgeInsets.only(
                  top: spacingUnit(8),
                  bottom: 8,
                  left: 16,
                  right: 16),
              child: RichText(
                  text: TextSpan(
                      text: 'Hello ',
                      style: TravelloTheme.title2.copyWith(
                          fontWeight: FontWeight.normal, color: Colors.black),
                      children: [
                    TextSpan(
                        text: _userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: TravelloTheme.primaryMain))
                  ])),
            ),
            Padding(
                padding: const EdgeInsets.only(
                    bottom: 24,
                    left: 16,
                    right: 16),
                child: Text('How can we help you today?',
                    style: TravelloTheme.title.copyWith(color: Colors.black))),

            /// CONTENTS
            Expanded(
              child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ThemeSize.sm),
                      child: ListView(
                        padding: const EdgeInsets.all(0),
                        shrinkWrap: true,
                        children: [
                          /// FAQ LIST
                          ExpansionPanelList(
                            elevation: 0,
                            expansionCallback: (int index, bool isExpanded) {
                              setState(() {
                                faqData[index].isExpanded = isExpanded;
                              });
                            },
                            children: faqData
                                .asMap()
                                .entries
                                .map<ExpansionPanel>((entry) {
                              Faq item = entry.value;
                              int index = entry.key;

                              return ExpansionPanel(
                                headerBuilder:
                                    (BuildContext context, bool isExpanded) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        faqData[index].isExpanded =
                                            !faqData[index].isExpanded;
                                      });
                                    },
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        item.headerValue,
                                        style: TravelloTheme.subtitle2,
                                      ),
                                    ),
                                  );
                                },
                                body: Text(item.expandedValue),
                                isExpanded: item.isExpanded,
                              );
                            }).toList(),
                          ),
                          const VSpace(),

                          /// CONTACT BUTTON
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: ThemeRadius.medium,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                              ),
                              child: Column(
                                children: [
                                  Text('Need More Help?',
                                      style: TravelloTheme.subtitle.copyWith(
                                        color: colorScheme(context)
                                            .onPrimaryContainer,
                                      )),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Our support team is available 24/7 to assist you with any questions or concerns.',
                                    textAlign: TextAlign.center,
                                    style: TravelloTheme.paragraph,
                                  ),
                                  const VSpaceShort(),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Get.toNamed(AppLink.contact);
                                      },
                                      style:
                                          ThemeButton.outlinedPrimary(context),
                                      child: const Text('CONTACT US'),
                                    ),
                                  )
                                ],
                              )),
                        ],
                      ),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
