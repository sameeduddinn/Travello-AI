import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/action_headers/home_action_group.dart';
import 'package:flight_app/widgets/profile/panel_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/image_viewer.dart';
import 'package:flight_app/widgets/decorations/rounded_deco_main.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ProfileBannerHeader extends SliverPersistentHeaderDelegate {
  const ProfileBannerHeader({
    required this.maxExtent,
    required this.minExtent,
    this.userName = 'User',
    this.userAvatar = '',
    this.onPickAvatar,
  });

  final String userName;
  final String userAvatar;
  final VoidCallback? onPickAvatar;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final showItem = shrinkOffset < 50;
    final safeTop = MediaQuery.of(context).padding.top;
    final compactTop = safeTop + 8;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraint) {
        double maxWidth = constraint.maxWidth;

        return SizedBox(
          width: maxWidth,
          child: Stack(fit: StackFit.expand, children: [
            /// BACKGROUND
            Container(
              decoration: const BoxDecoration(
                  color: TravelloTheme.primaryMainContainer),
              child: SvgPicture.asset(
                ImgApi.profileBanner,
                fit: BoxFit.cover,
              ),
            ),

            /// CURVE DECORATION
            const Positioned(
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
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                )),

            /// TOP BAR
            Positioned(
              top: compactTop,
              left: 16,
              right: 80, // keeps username clear of action buttons on the right
              child: AnimatedOpacity(
                opacity: showItem ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: TravelloTheme.primaryMain,
                        backgroundImage: userAvatar.isNotEmpty
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar.isEmpty
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          userName,
                          style: TravelloTheme.title2,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ]),
              ),
            ),
            Positioned(
              top: compactTop,
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
                                GestureDetector(
                                  onTap: userAvatar.isNotEmpty
                                      ? () => Get.to(
                                          () => ImageViewer(img: userAvatar))
                                      : onPickAvatar,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: TravelloTheme.primaryMain,
                                    backgroundImage: userAvatar.isNotEmpty
                                        ? NetworkImage(userAvatar)
                                        : null,
                                    child: userAvatar.isEmpty
                                        ? Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  child: GestureDetector(
                                    onTap: onPickAvatar,
                                    child: const CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          TravelloTheme.secondaryMain,
                                      child: Icon(Icons.camera_alt,
                                          size: 16,
                                          color: TravelloTheme.secondaryDark),
                                    ),
                                  ),
                                ),
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
                      ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: ThemeSize.sm,
                          ),
                          child: const PanelPoint()),

                      /// DECORATION
                      Container(
                          width: maxWidth,
                          height: 10,
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: TravelloTheme.paperLightContainerLowest,
                                blurRadius: 0.0,
                                spreadRadius: 0.0,
                                offset: Offset(0, 2),
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
