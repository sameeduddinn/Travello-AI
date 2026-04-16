import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class FlightDetailProfessional extends StatelessWidget {
  const FlightDetailProfessional({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments ?? {};
    final flight = args['flight'] as FlightResult?;
    final searchParams = args['searchParams'] as Map<String, dynamic>? ?? {};
    final isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    final outboundFlight = args['outboundFlight'] as FlightResult?;
    final returnFlight = args['returnFlight'] as FlightResult?;

    if (flight == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(title: const Text('Flight Details')),
        body: const Center(child: Text('Flight not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Flight Details'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Flight summary card
            Container(
              margin: EdgeInsets.all(R.r(context, 16)),
              padding: EdgeInsets.all(R.r(context, 16)),
              decoration: BoxDecoration(
                color: TravelloTheme.paperLight,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Badge
                  if (flight.badge.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: flight.badge == 'Cheapest'
                                ? [Colors.green, Colors.greenAccent]
                                : flight.badge == 'Fastest'
                                    ? [Colors.blue, Colors.blueAccent]
                                    : [Colors.orange, Colors.orangeAccent],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              flight.badge == 'Cheapest'
                                  ? CupertinoIcons.money_dollar_circle
                                  : flight.badge == 'Fastest'
                                      ? CupertinoIcons.bolt_fill
                                      : CupertinoIcons.star_fill,
                              size: R.r(context, 14),
                              color: Colors.white,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              flight.badge,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: R.sp(context, 12),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (flight.badge.isNotEmpty)
                    SizedBox(height: R.rh(context, 16)),

                  // Airline info
                  Row(
                    children: [
                      Container(
                        width: R.r(context, 60),
                        height: R.r(context, 60),
                        decoration: BoxDecoration(
                          color: TravelloTheme.primaryMainContainer,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Text(
                            flight.airlineLogo,
                            style: TextStyle(fontSize: R.sp(context, 32)),
                          ),
                        ),
                      ),
                      SizedBox(width: R.r(context, 16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flight.airlineName,
                              style: TravelloTheme.title2,
                            ),
                            Text(
                              '${flight.airlineCode} • ${flight.cabinClass}',
                              style: TravelloTheme.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: R.rh(context, 24)),

                  // Flight timeline
                  Row(
                    children: [
                      // Departure
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flight.departureTime,
                              style: TravelloTheme.title2,
                            ),
                            Text(
                              searchParams['fromAirport']?.code ?? 'DEP',
                              style: TravelloTheme.subtitle,
                            ),
                            Text(
                              searchParams['fromAirport']?.city ?? 'Departure',
                              style: TravelloTheme.caption,
                            ),
                          ],
                        ),
                      ),

                      // Duration
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.airplane,
                              color: TravelloTheme.primaryMain,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              flight.duration,
                              style: TravelloTheme.caption,
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              height: 2.h,
                              color: TravelloTheme.primaryMain,
                              margin: EdgeInsets.symmetric(
                                  horizontal: R.r(context, 16)),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              flight.stops == 0
                                  ? 'Non-stop'
                                  : '${flight.stops} ${flight.stops == 1 ? 'stop' : 'stops'}',
                              style: TravelloTheme.caption,
                            ),
                          ],
                        ),
                      ),

                      // Arrival
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              flight.arrivalTime,
                              style: TravelloTheme.title2,
                            ),
                            Text(
                              searchParams['toAirport']?.code ?? 'ARR',
                              style: TravelloTheme.subtitle,
                            ),
                            Text(
                              searchParams['toAirport']?.city ?? 'Arrival',
                              style: TravelloTheme.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Layover details (if stops > 0)
            if (flight.stops > 0)
              Container(
                margin: EdgeInsets.symmetric(horizontal: R.r(context, 16)),
                padding: EdgeInsets.all(R.r(context, 16)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.info_circle,
                          color: Colors.orange,
                          size: R.r(context, 20),
                        ),
                        SizedBox(width: 8.w),
                        const Text(
                          'Layover Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ...flight.stopCities.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          '• Stop ${entry.key + 1}: ${entry.value} (2h 30m layover)',
                          style: TravelloTheme.caption,
                        ),
                      );
                    }),
                  ],
                ),
              ),

            if (flight.stops > 0) SizedBox(height: R.rh(context, 16)),

            // Baggage information
            _buildInfoSection(
              context,
              'Baggage Information',
              CupertinoIcons.bag,
              [
                _buildInfoRow('Check-in', '30 kg (2 pieces)'),
                _buildInfoRow('Cabin', '7 kg (1 piece)'),
              ],
            ),

            SizedBox(height: R.rh(context, 16)),

            // Cancellation policy
            _buildInfoSection(
              context,
              'Cancellation Policy',
              CupertinoIcons.xmark_shield,
              [
                if (flight.isRefundable) ...[
                  _buildInfoRow('Refundable', 'Yes'),
                  _buildInfoRow('Cancellation before 24h', '100% refund'),
                  _buildInfoRow('Cancellation before 12h', '50% refund'),
                  _buildInfoRow('Within 12h', 'No refund'),
                ] else ...[
                  _buildInfoRow('Refundable', 'No'),
                  _buildInfoRow('Cancellation', 'Not allowed'),
                ],
              ],
            ),

            SizedBox(height: R.rh(context, 16)),

            // Fare breakdown
            _buildInfoSection(
              context,
              'Fare Breakdown',
              CupertinoIcons.money_dollar_circle,
              [
                _buildInfoRow(
                  'Base Fare (${searchParams['adults'] ?? 1} Adult${(searchParams['adults'] ?? 1) > 1 ? 's' : ''})',
                  'PKR ${(flight.price * 0.85).toStringAsFixed(0)}',
                ),
                if ((searchParams['children'] ?? 0) > 0)
                  _buildInfoRow(
                    'Children (${searchParams['children']})',
                    'PKR ${((flight.price * 0.75) * (searchParams['children'] ?? 0)).toStringAsFixed(0)}',
                  ),
                if ((searchParams['infants'] ?? 0) > 0)
                  _buildInfoRow(
                    'Infants (${searchParams['infants']})',
                    'PKR ${((flight.price * 0.25) * (searchParams['infants'] ?? 0)).toStringAsFixed(0)}',
                  ),
                _buildInfoRow(
                  'Taxes & Fees',
                  'PKR ${(flight.price * 0.15).toStringAsFixed(0)}',
                ),
                Divider(height: 16.h),
                _buildInfoRow(
                  'Total',
                  'PKR ${flight.price.toStringAsFixed(0)}',
                  isTotal: true,
                  ctx: context,
                ),
              ],
            ),

            SizedBox(height: R.rh(context, 80)),
          ],
        ),
      ),

      // Continue button
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(R.r(context, 16)),
        decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Price', style: TravelloTheme.caption),
                        Text(
                          'PKR ${flight.price.toStringAsFixed(0)}',
                          style: TravelloTheme.title2.copyWith(
                            color: TravelloTheme.primaryMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () {
                      Get.toNamed(
                        AppLink.bookingStep1,
                        arguments: {
                          'flight': flight,
                          'searchParams': searchParams,
                          'isRoundTrip': isRoundTrip,
                          'outboundFlight': outboundFlight,
                          'returnFlight': returnFlight,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TravelloTheme.primaryMain,
                      foregroundColor: colorScheme(context).onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: R.r(context, 32),
                        vertical: R.rh(context, 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: R.sp(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.r(context, 16)),
      padding: EdgeInsets.all(R.r(context, 16)),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: TravelloTheme.primaryMain,
                size: R.r(context, 20),
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TravelloTheme.subtitle
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: R.rh(context, 12)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isTotal = false, BuildContext? ctx}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal && ctx != null
                ? TextStyle(
                    fontWeight: FontWeight.bold, fontSize: R.sp(ctx, 16))
                : TravelloTheme.caption,
          ),
          Text(
            value,
            style: isTotal && ctx != null
                ? TextStyle(
                    fontWeight: FontWeight.bold, fontSize: R.sp(ctx, 16))
                : TravelloTheme.subtitle,
          ),
        ],
      ),
    );
  }
}
