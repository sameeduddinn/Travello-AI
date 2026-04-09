import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/action_headers/home_action_group.dart';
import 'package:flight_app/widgets/profile/panel_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/utils/image_viewer.dart';
import 'package:flight_app/widgets/decorations/rounded_deco_main.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ProfileBannerHeader extends SliverPersistentHeaderDelegate {
  const ProfileBannerHeader({
    required this.maxExtent,
    required this.minExtent,
    this.userName = 'User',
    this.userAvatar = '',
  });

  final String userName;
  final String userAvatar;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final showItem = shrinkOffset < 50;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraint) {
        double maxWidth = constraint.maxWidth;

        return SizedBox(
          width: maxWidth,
          child: Stack(fit: StackFit.expand, children: [
            /// BACKGROUND
            Container(
              decoration:
                  BoxDecoration(color: TravelloTheme.primaryMainContainer),
              child: SvgPicture.asset(
                ImgApi.profileBanner,
                fit: BoxFit.cover,
              ),
            ),

            /// CURVE DECORATION
            Positioned(
                bottom: 0,
                left: 0,
                child: RoundedDecoMain(
                  height: 80,
                  bgDecoration: BoxDecoration(
                    color: TravelloTheme.paperLightContainerLowest,
                    boxShadow: [
                      BoxShadow(
                        color: TravelloTheme.paperLightContainerLowest,
                        blurRadius: 0.0,
                        spreadRadius: 0.0,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                )),

            /// TOP BAR
            Positioned(
              top: 8,
              left: 16,
              child: AnimatedOpacity(
                opacity: showItem ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundImage: NetworkImage(
                            userAvatar.isEmpty ? userDummy.avatar : userAvatar),
                      ),
                      const SizedBox(width: 8),
                      Text(userName, style: TravelloTheme.title2),
                    ]),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(children: homeActionGroup(context, false)),
            ),

            /// USER PROFILE
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: maxWidth,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// AVATAR
                      AnimatedOpacity(
                        opacity: showItem ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedScale(
                            scale: showItem ? 1 : 0,
                            curve: Curves.easeOutBack,
                            duration: const Duration(milliseconds: 300),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Hero(
                                  tag: userAvatar.isEmpty
                                      ? userDummy.avatar
                                      : userAvatar,
                                  child: GestureDetector(
                                    onTap: () {
                                      Get.to(() => ImageViewer(
                                          img: userAvatar.isEmpty
                                              ? userDummy.avatar
                                              : userAvatar));
                                    },
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(
                                          userAvatar.isEmpty
                                              ? userDummy.avatar
                                              : userAvatar),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                    child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: TravelloTheme.secondaryMain,
                                  child: Icon(Icons.verified,
                                      size: 20,
                                      color: TravelloTheme.secondaryDark),
                                ))
                              ],
                            )),
                      ),

                      /// NAME
                      AnimatedOpacity(
                        opacity: showItem ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(userName, style: TravelloTheme.title),
                      ),

                      /// POINTS
                      GestureDetector(
                          onTap: () {
                            Get.toNamed(AppLink.reward);
                          },
                          child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: ThemeSize.sm,
                              ),
                              child: const PanelPoint())),

                      /// DECORATION
                      Container(
                          width: maxWidth,
                          height: 10,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color:
                                    TravelloTheme.paperLightContainerLowest,
                                blurRadius: 0.0,
                                spreadRadius: 0.0,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ))
                    ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration =>
      OverScrollHeaderStretchConfiguration();
}
