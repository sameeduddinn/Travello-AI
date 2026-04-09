import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/widgets/search_filters/passengger_class.dart';
import 'package:flight_app/widgets/search_filters/city_selector_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SearchFlightForm extends StatefulWidget {
  const SearchFlightForm({super.key, required this.roundTrip});

  final bool roundTrip;

  @override
  State<SearchFlightForm> createState() => _SearchFlightFormState();
}

class _SearchFlightFormState extends State<SearchFlightForm> {
  final TextEditingController _dateFromRef =
      TextEditingController(text: '1/1/2025');
  final TextEditingController _dateToRef = TextEditingController();
  final TextEditingController _passenggerClassRef = TextEditingController();
  final TextEditingController _flyingFromRef = TextEditingController();
  final TextEditingController _flyingToRef = TextEditingController();

  String _fromCityCode = '';
  String _toCityCode = '';
  bool _showFromDropdown = false;
  bool _showToDropdown = false;

  double _adults = 1;
  double _children = 0;
  double _infants = 0;
  String _classType = 'Economy';

  void _showBottomSheet() async {
    Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
      return Wrap(children: [
        PassenggerClass(

            /// ADD PASSENGERS
            addPassenggers: (String type) {
              final double totalPassengers = _adults + _children + _infants;
              setState(() {
                switch (type) {
                  case 'adults':
                    _adults++;
                    break;
                  case 'children':
                    _children++;
                    break;
                  case 'infants':
                    _infants++;
                    break;
                  default:
                    break;
                }
                _passenggerClassRef.text =
                    '$totalPassengers Passengger${totalPassengers > 1 ? 's' : ''}, $_classType';
              });
            },

            /// REMOVE PASSENGERS
            removePassenggers: (String type) {
              final double totalPassengers = _adults + _children + _infants;
              setState(() {
                switch (type) {
                  case 'adults':
                    _adults--;
                    break;
                  case 'children':
                    _children--;
                    break;
                  case 'infants':
                    _infants--;
                    break;
                  default:
                    break;
                }
                _passenggerClassRef.text =
                    '$totalPassengers Passengger${totalPassengers > 1 ? 's' : ''}, $_classType';
              });
            },
            passengers: [_adults, _children, _infants],
            classType: _classType,
            setClass: (String type) {
              /// SET CLASS
              final double totalPassengers = _adults + _children + _infants;
              setState(() {
                _classType = type;
                _passenggerClassRef.text =
                    '$totalPassengers Passengger${totalPassengers > 1 ? 's' : ''}, $_classType';
              });
            })
      ]);
    }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))));
  }

  Future _selectDate(TextEditingController targetRef) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );

    if (picked != null) {
      setState(() {
        targetRef.text = picked.toString().split(" ")[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 16),
        child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(0),
            physics: const ClampingScrollPhysics(),
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AppTextField(
                            label: 'Flying From',
                            controller: _flyingFromRef,
                            readOnly: false,
                            onChanged: (value) {
                              setState(() {
                                _showFromDropdown = value.isNotEmpty;
                                _showToDropdown = false;
                              });
                            },
                            prefixIcon: FontAwesomeIcons.planeDeparture),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final tempCity = _flyingFromRef.text;
                            final tempCode = _fromCityCode;
                            _flyingFromRef.text = _flyingToRef.text;
                            _fromCityCode = _toCityCode;
                            _flyingToRef.text = tempCity;
                            _toCityCode = tempCode;
                          });
                        },
                        child: Container(
                            width: 50,
                            height: 50,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                borderRadius: ThemeRadius.small,
                                color: const Color(0xFF1A1A1A)),
                            child: const Icon(
                                CupertinoIcons.arrow_up_arrow_down,
                                size: 24,
                                color: Color(0xFFD4AF37))),
                      )
                    ],
                  ),
                  if (_showFromDropdown && _flyingFromRef.text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: TravelloTheme.paperLight,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CitySelectorDropdown(
                        keyword: _flyingFromRef.text,
                        onCitySelected: (cityName, cityCode) {
                          setState(() {
                            _flyingFromRef.text = cityName;
                            _fromCityCode = cityCode;
                            _showFromDropdown = false;
                          });
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  AppTextField(
                      label: 'Flying To',
                      controller: _flyingToRef,
                      readOnly: false,
                      onChanged: (value) {
                        setState(() {
                          _showToDropdown = value.isNotEmpty;
                          _showFromDropdown = false;
                        });
                      },
                      prefixIcon: FontAwesomeIcons.planeArrival),
                  if (_showToDropdown && _flyingToRef.text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: TravelloTheme.paperLight,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CitySelectorDropdown(
                        keyword: _flyingToRef.text,
                        onCitySelected: (cityName, cityCode) {
                          setState(() {
                            _flyingToRef.text = cityName;
                            _toCityCode = cityCode;
                            _showToDropdown = false;
                          });
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Departure Date',
                onChanged: (_) => {},
                controller: _dateFromRef,
                readOnly: true,
                prefixIcon: FontAwesomeIcons.calendar,
                onTap: () {
                  _selectDate(_dateFromRef);
                },
              ),
              widget.roundTrip
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppTextField(
                        label: 'Return Date',
                        onChanged: (_) => {},
                        controller: _dateToRef,
                        readOnly: true,
                        prefixIcon: FontAwesomeIcons.calendar,
                        onTap: () {
                          _selectDate(_dateToRef);
                        },
                      ),
                    )
                  : Container(),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Passenger and Class',
                onChanged: (_) => {},
                prefixIcon: FontAwesomeIcons.user,
                readOnly: true,
                controller: _passenggerClassRef,
                onTap: _showBottomSheet,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () {
                      if (widget.roundTrip) {
                        Get.toNamed(AppLink.flightListRoundTrip);
                      } else {
                        Get.toNamed(AppLink.flightList);
                      }
                    },
                    style: ThemeButton.btnBig.merge(ThemeButton.primary),
                    child: Text('SEARCH FLIGHTS',
                        style:
                            TravelloTheme.subtitle.copyWith(color: Colors.white))),
              ),
            ]));
  }
}
