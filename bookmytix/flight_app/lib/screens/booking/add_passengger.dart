import 'package:flight_app/models/list_item.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/picker.dart';
import 'package:flight_app/widgets/alert_info/alert_info.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AddPassengger extends StatefulWidget {
  const AddPassengger({super.key});

  @override
  State<AddPassengger> createState() => _AddPassenggerState();
}

class _AddPassenggerState extends State<AddPassengger> {
  final _addPassenggerKey = GlobalKey<FormState>();
  bool _isNotValid = false;

  String? type;
  String? idType;
  final TextEditingController _chooseType = TextEditingController();
  final TextEditingController _chooseId = TextEditingController();
  final TextEditingController _datePickerRef = TextEditingController();

  List<ListItem> typeOptions = [
    ListItem(
      value: 'adult',
      label: 'Adult',
      text: 'Age 12 and over',
    ),
    ListItem(
      value: 'child',
      label: 'Child',
      text: 'Age 2-11',
    ),
    ListItem(
      value: 'infant',
      label: 'Infant',
      text: 'Below age 2',
    ),
  ];

  List<ListItem> idOptions = [
    ListItem(
      value: 'id_card',
      label: 'Identity Card',
    ),
    ListItem(
      value: 'passport',
      label: 'Pasport',
    ),
    ListItem(
      value: 'driving_license',
      label: 'Diriving License',
    ),
  ];

  void openTypePicker(BuildContext context) {
    openRadioPicker(
      context: context,
      options: typeOptions,
      title: 'Choose Type',
      onSelected: (value) {
        if (value != null) {
          String result = typeOptions.firstWhere((e) => e.value == value).label;
          _chooseType.text = result;
        }
        setState(() {
          type = value;
        });
      },
      initialValue: type,
    );
  }

  void openIdPicker(BuildContext context) {
    openRadioPicker(
      context: context,
      options: idOptions,
      title: 'Choose ID Type',
      onSelected: (value) {
        if (value != null) {
          String result = idOptions.firstWhere((e) => e.value == value).label;
          _chooseId.text = result;
        }
        setState(() {
          idType = value;
        });
      },
      initialValue: idType,
    );
  }

  Future _selectDate(TextEditingController targetRef) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime(2015),
    );

    if (picked != null) {
      setState(() {
        targetRef.text = picked.toString().split(" ")[0];
      });
    }
  } 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Add New Passengger', style: TravelloTheme.subtitle),
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
        centerTitle: true,
      ),
      body: Form(
        key: _addPassenggerKey,
        child: Column(children: [
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ThemeSize.sm),
              child: ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, physics: const ClampingScrollPhysics(), children: [
                const AlertInfo(type: AlertType.info, text: 'Please fill the data information for new passenges.'),
                const VSpaceShort(),
                AppTextField(
                  label: 'Full Name',
                  initialValue: '',
                  onChanged: (_) {},
                  validator: FormBuilderValidators.required(),
                  errorText: _isNotValid ? 'Please fill passengger name' : null,
                ),
                const VSpace(),
                AppTextField(
                  controller: _chooseType,
                  label: 'Choose type',
                  onChanged: (_) {},
                  validator: FormBuilderValidators.required(),
                  errorText: _isNotValid ? 'Please fill passengger type' : null,
                  onTap: () {
                    openTypePicker(context);
                  },
                  suffix: const Icon(Icons.arrow_drop_down),
                ),
                const VSpace(),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(
                    child: AppTextField(
                      controller: _chooseId,
                      label: 'Choose ID Type',
                      onChanged: (_) {},
                      onTap: () {
                        openIdPicker(context);
                      },
                      suffix: const Icon(Icons.arrow_drop_down),
                      validator: FormBuilderValidators.required(),
                      errorText: _isNotValid ? 'Please fill ID type' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      label: 'ID Number',
                      initialValue: '',
                      onChanged: (_) {},
                      validator: FormBuilderValidators.required(),
                      errorText: _isNotValid ? 'Please fill id number' : null,
                    ),
                  ),
                ]),
                const VSpace(),
                AppTextField(
                  controller: _datePickerRef,
                  readOnly: true,
                  prefixIcon: Icons.date_range,
                  label: 'Date of birth',
                  onChanged: (_) {},
                  onTap: () {
                    _selectDate(_datePickerRef);
                  },
                ),
              ]),
            )
          ),
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: ThemeSize.sm),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 32
              ),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_addPassenggerKey.currentState!.validate()) {
                      Get.back();
                    } else {
                      setState(() {
                        _isNotValid = true;
                      });
                    }
                  },
                  style: ThemeButton.btnBig.merge(ThemeButton.primary),
                  child: const Text('SAVE', style: TravelloTheme.subtitle2)
                ),
              ),
            ),
          )
        ]),
      )
    );
  }
}