import 'package:flutter/material.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SeatPicker extends StatelessWidget {
  const SeatPicker({
    super.key,
    required this.index, required this.setSeat,
    required this.selectedSeat, required this.setDeepState
  });

  final int index;
  final Function(String, int) setSeat;
  final String selectedSeat;
  final StateSetter setDeepState;

  @override
  Widget build(BuildContext context) {
    /// BOTTOMSHEET CONTENT
    return LayoutBuilder(
      builder: (context, constraints) {
        // Available width = sheet width − outer padding (32) − inner padding (16) − border (2)
        final availableWidth = constraints.maxWidth - 50;
        // Nominal grid needs 2×40 + 4×60 = 320 dp; scale down proportionally on narrow screens
        final scale = (availableWidth / 320.0).clamp(0.7, 1.0);
        final colWidth = 60.0 * scale;
        final spacingWidth = 40.0 * scale;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(children: [
            Column(children: [
              const GrabberIcon(),
              const VSpaceShort(),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.airline_seat_recline_normal_rounded, size: 22),
                SizedBox(width: 8),
                Text('Change Seat', style: TravelloTheme.subtitle2),
              ]),
              const VSpaceShort(),
              /// COLOR INFO
              SizedBox(
                height: 25,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _seatBox(context, '', 'available'),
                  const SizedBox(width: 4),
                  const Text('Available'),
                  const SizedBox(width: 20),
                  _seatBox(context, '', 'selected'),
                  const SizedBox(width: 4),
                  const Text('Selected'),
                  const SizedBox(width: 20),
                  _seatBox(context, '', 'disabled'),
                  const SizedBox(width: 4),
                  const Text('Reserved'),
                ]),
              ),
              const VSpaceShort(),

              /// SEAT PICKER
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 1,
                    color: TravelloTheme.primaryMain,
                  ),
                  borderRadius: ThemeRadius.medium,
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    SizedBox(width: spacingWidth, child: const Text('No.')),
                    SizedBox(width: colWidth, child: const Text('A')),
                    SizedBox(width: colWidth, child: const Text('B')),
                    SizedBox(width: spacingWidth),
                    SizedBox(width: colWidth, child: const Text('C')),
                    SizedBox(width: colWidth, child: const Text('D')),
                  ]),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: 13,
                    itemBuilder: (context, rowIndex) {
                      return Row(children: [
                        SizedBox(width: spacingWidth, child: Text('${rowIndex + 1}')),
                        InkWell(
                          onTap: () {
                            setDeepState(() {
                              setSeat('A${rowIndex+1}', index);
                            });
                          },
                          child: SizedBox(width: colWidth, child: _seatBox(context, 'A${rowIndex+1}', selectedSeat == 'A${rowIndex+1}' ? 'selected' : 'available')),
                        ),
                        InkWell(
                          onTap: () {
                            setDeepState(() {
                              setSeat('B${rowIndex+1}', index);
                            });
                          },
                          child: SizedBox(width: colWidth, child: _seatBox(context, 'B${rowIndex+1}', selectedSeat == 'B${rowIndex+1}' ? 'selected' : 'available')),
                        ),
                        SizedBox(width: spacingWidth),
                        InkWell(
                          onTap: () {
                            setDeepState(() {
                              setSeat('C${rowIndex+1}', index);
                            });
                          },
                          child: SizedBox(width: colWidth, child: _seatBox(context, 'C${rowIndex+1}', selectedSeat == 'C${rowIndex+1}' ? 'selected' : 'available')),
                        ),
                        InkWell(
                          onTap: () {
                            setDeepState(() {
                              setSeat('D${rowIndex+1}', index);
                            });
                          },
                          child: SizedBox(width: colWidth, child: _seatBox(context, 'D${rowIndex+1}', selectedSeat == 'D${rowIndex+1}' ? 'selected' : 'available')),
                        ),
                      ]);
                    },
                  ),
                ]),
              ),
              const VSpaceShort(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Get.back();
                  },
                  style: ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
                  child: Text('Done'.toUpperCase(), style: TravelloTheme.subtitle),
                ),
              ),
              const VSpace(),
            ]),
          ]),
        );
      },
    );
  }

  /// SEAT BOX
  Widget _seatBox(BuildContext context, String text, String status) {

    Color checkStatus(st) {
      switch(st) {
        case 'selected':
          return TravelloTheme.primaryMain;
        case 'disabled':
          return colorScheme(context).outline;
        default:
          return TravelloTheme.paperLight;
      }
    }

    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.small,
        color: checkStatus(status),
        border: Border.all(
          width: 1,
          color: status == 'available' ? colorScheme(context).outlineVariant : Colors.transparent,
        ),
      ),
      child: Text(text, style: TravelloTheme.caption.copyWith(color: status == 'available' ? colorScheme(context).onSurface : TravelloTheme.secondaryMain)),
    );
  }
}
