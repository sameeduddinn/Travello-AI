import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/voucher.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/widgets/cards/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class PromoVoucherList extends StatelessWidget {
  const PromoVoucherList({super.key, required this.dataList});

  final List<Voucher> dataList;

  @override
  Widget build(BuildContext context) {
    return dataList.isNotEmpty
        ? ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: dataList.length,
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 80,
            ),
            itemBuilder: ((BuildContext context, int index) {
              Voucher item = dataList[index];
              return Container(
                width: double.infinity,
                height: 100,
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Get.toNamed(AppLink.voucherDetail);
                  },
                  child: VoucherCard(
                      title: item.title,
                      desc: item.desc,
                      onSelected: (_) {},
                      isSelected: false,
                      color: item.color,
                      image: item.image ?? item.image,
                      status: VoucherStatus.readonly),
                ),
              );
            }),
          )
        : _emptyList(context);
  }

  Widget _emptyList(BuildContext context) {
    return NoData(
      image: ImgApi.emptyVoucher,
      title: 'You don\'t any vouchers yet',
      desc:
          'No vouchers available. Check back later for exclusive travel deals and discounts.',
    );
  }
}
