import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/widgets/settings/account_info.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SettingList extends StatefulWidget {
  const SettingList({super.key});

  @override
  State<SettingList> createState() => _SettingListState();
}

class _SettingListState extends State<SettingList> {
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isGuest = await AuthService.isGuestMode();
    final isLoggedIn = await AuthService.isLoggedIn();

    setState(() {
      _isGuestMode = isGuest || !isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          /// AUTH PAGES - Only show for guest users
          if (_isGuestMode) ...[
            const TitleBasicSmall(title: 'Quick Access'),
            PaperCard(
                content: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(children: [
                      ListTile(
                        leading: const Icon(Icons.login, color: Colors.green),
                        title: const Text('Login',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Access your account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                        onTap: () {
                          Get.toNamed('/login');
                        },
                      ),
                      const LineList(),
                      ListTile(
                        leading:
                            const Icon(Icons.person_add, color: Colors.blue),
                        title: const Text('Sign Up',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Create a new account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                        onTap: () {
                          Get.toNamed('/register');
                        },
                      ),
                    ]))),
            const VSpace(),
          ],

          /// SAVED / WISHLIST
          const TitleBasicSmall(title: 'My Activity'),
          PaperCard(
              content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFD4AF37)),
                    title: const Text('Saved Packages',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Your liked hotels, flights & trains'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                    onTap: () {
                      Get.toNamed(AppLink.wishlist);
                    },
                  ))),
          const VSpace(),

          /// ACCOUNT SETTING
          const TitleBasicSmall(title: 'Help and Account'),
          PaperCard(
              content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Account Information'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        return const Wrap(
                          children: [AccountInfo()],
                        );
                      });
                },
              ),
              const LineList(),
              ListTile(
                onTap: () {
                  Get.toNamed('/faq');
                },
                leading: const Icon(Icons.help_outline),
                title: const Text('FAQ'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              ),
              const LineList(),
              ListTile(
                onTap: () {
                  Get.toNamed('/contact');
                },
                leading: const Icon(Icons.message_outlined),
                title: const Text('Contact Admin'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              ),
              const LineList(),
              ListTile(
                onTap: () {
                  Get.toNamed('/terms-conditions');
                },
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Terms and Conditions'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              ),
            ]),
          )),
          const VSpace(),

          /// GENERAL PAGES
          const TitleBasicSmall(title: 'General Pages'),
          PaperCard(
              content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_on_rounded),
                      title: const Text('Notification'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.notification);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('Intro'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.intro);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.store_mall_directory),
                      title: const Text('Home Page'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.home);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Search Flight'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.searchFlight);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Search List'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.searchList);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.crop_square_sharp),
                      title: const Text('Not Found'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.notFound);
                      },
                    ),
                  ]))),
          const VSpace(),

          /// PAGE FLIGHT LIST
          const TitleBasicSmall(title: 'Flights'),
          PaperCard(
              content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Flight List'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.flightList);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Flight List Round Trip'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.flightListRoundTrip);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.flight),
                title: const Text('Flight Detail'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.flightDetail);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.flight_takeoff_sharp),
                title: const Text('Flight Package Detail'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.flightDetailPackage);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: const Text('Explore'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.explore);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.airplanemode_inactive_rounded),
                title: const Text('Flight Not Found'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.flightNotFound);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.label_off_rounded),
                title: const Text('Package Not Found'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.packageNotFound);
                },
              ),
            ]),
          )),
          const VSpace(),

          /// TICKET
          const TitleBasicSmall(title: 'Ticket'),
          PaperCard(
              content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.airplane_ticket),
                      title: const Text('My Ticket'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.myTicket);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.airplane_ticket_outlined),
                      title: const Text('Ticket Detail'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.ticketDetail);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Transaction History'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.orderHistory);
                      },
                    ),
                    const LineList(),
                    ListTile(
                      leading: const Icon(Icons.money),
                      title: const Text('E-Ticket'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Get.toNamed(AppLink.eTicket);
                      },
                    ),
                  ]))),
          const VSpace(),

          /// UI LIST
          const TitleBasicSmall(title: 'UI List'),
          PaperCard(
              content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.ads_click),
                title: const Text('Buttons'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.buttonCollection);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.rounded_corner),
                title: const Text('Shadow and Border Radius'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.shadowRoundedCollection);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.abc),
                title: const Text('Typography'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.typographyCollection);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Colors and Gradient'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.colorCollection);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.format_list_bulleted),
                title: const Text('Form Input'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.formSample);
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: const Text('Card Collection'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  Get.toNamed(AppLink.cardCollection);
                },
              ),
            ]),
          )),
          const VSpace(),

          /// FOOTER
          SizedBox(
            height: 50,
            child: FilledButton(
                onPressed: () async {
                  // Check if guest mode or logged in
                  final prefs = await SharedPreferences.getInstance();
                  final isGuest = prefs.getBool('guest_mode') ?? false;

                  if (isGuest) {
                    // Exit guest mode - go to welcome page
                    await prefs.remove('guest_mode');
                    Get.snackbar(
                      'Goodbye!',
                      'Thank you for visiting. Login to access all features!',
                      backgroundColor: Colors.blue.shade600,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                      duration: const Duration(seconds: 2),
                    );
                    // Navigate to welcome page
                    Get.offAllNamed(AppLink.welcome);
                  } else {
                    // Logout regular user using AuthService (clears session + city preference)
                    await AuthService.logout();

                    // Enable guest mode automatically
                    await prefs.setBool('guest_mode', true);

                    Get.snackbar(
                      'Signed Out Successfully',
                      'Now browsing as guest. Login anytime for full access!',
                      backgroundColor: Colors.green.shade600,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                      duration: const Duration(seconds: 3),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                    );
                    // Navigate to home as guest
                    Get.offAllNamed(AppLink.home);
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('LOGOUT'),
                      SizedBox(width: 4),
                      Icon(Icons.exit_to_app)
                    ])),
          ),
          const VSpace(),
          Center(
              child: Text('${branding.name} Version: ${branding.version}',
                  style: TravelloTheme.caption)),
          const VSpaceBig(),
        ]);
  }
}
