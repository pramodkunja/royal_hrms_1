import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/branch_form_rules.dart';
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';

typedef LocationChanged = void Function(
  StateEntity? state,
  CityEntity? city,
  String code,
);

class BranchLocationSelector extends ConsumerStatefulWidget {
  final StateEntity? initialState;
  final CityEntity? initialCity;
  final String initialCode;
  final LocationChanged onChanged;
  // Web previews / validates the branch code on Add only; Edit keeps the
  // branch's own code.
  final bool isAdd;

  const BranchLocationSelector({
    super.key,
    this.initialState,
    this.initialCity,
    this.initialCode = '',
    required this.onChanged,
    this.isAdd = true,
  });

  @override
  BranchLocationSelectorState createState() => BranchLocationSelectorState();
}

// Public state so parent can call validate() and read selection via GlobalKey.
class BranchLocationSelectorState
    extends ConsumerState<BranchLocationSelector> {
  StateEntity? selectedState;
  CityEntity? selectedCity;
  String branchCode = '';

  // Web OTHER_CITY: "Other (type city name)" + the typed new_city_name.
  static const _otherCity = CityEntity(id: -1, name: kOtherCityLabel, stateId: 0, stateName: '');
  bool isOtherCity = false;
  final newCityCtrl = TextEditingController();
  String get newCityName => newCityCtrl.text.trim();
  Timer? _debounce;
  int _codeToken = 0;

  bool _isLoadingCode = false;
  String? _stateError;
  String? _cityError;
  String? _newCityError;
  String? _codeError;

  @override
  void dispose() {
    _debounce?.cancel();
    newCityCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    selectedState = widget.initialState;
    selectedCity = widget.initialCity;
    branchCode = widget.initialCode;
  }

  // Web validate(): state, city (or the new city name), then — on Add — the
  // branch code.
  bool validate() {
    final cityChosen = isOtherCity || selectedCity != null;
    String? codeErr;
    if (widget.isAdd) {
      if (_isLoadingCode) {
        codeErr = 'Branch code is still generating, please wait.';
      } else if (branchCode.isEmpty) {
        codeErr = 'Branch code could not be generated. Try re-selecting the city.';
      }
    }
    setState(() {
      _stateError = selectedState == null ? 'Please select a state.' : null;
      _cityError = cityChosen ? null : 'Please select a city.';
      _newCityError = isOtherCity ? validateNewCityName(newCityCtrl.text) : null;
      _codeError = codeErr;
    });
    return selectedState != null && cityChosen && _newCityError == null && codeErr == null;
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(statesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        statesAsync.when(
          loading: () => _shimmer('State/Region *'),
          error: (e, _) => _errorTile('Could not load states'),
          data: (states) => _stateDropdown(states),
        ),
        const SizedBox(height: 12),
        _cityDropdown(),
        const SizedBox(height: 12),
        _codeField(),
      ],
    );
  }

  Widget _stateDropdown(List<StateEntity> states) {
    StateEntity? effective;
    if (selectedState != null) {
      try {
        effective = states.firstWhere((s) => s.id == selectedState!.id);
      } catch (_) {}
    }
    return DropdownButtonFormField<StateEntity>(
      key: ValueKey('state-${selectedState?.id}'),
      initialValue: effective,
      isExpanded: true,
      style: AppTextStyles.body,
      decoration: _dec('State/Region *', _stateError),
      hint: Text('Select State', style: AppTextStyles.caption),
      items: states
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (s) {
        setState(() {
          selectedState = s;
          selectedCity = null;
          isOtherCity = false;
          newCityCtrl.clear();
          _debounce?.cancel();
          _codeToken++;
          _isLoadingCode = false;
          branchCode = '';
          _stateError = null;
          _cityError = null;
          _newCityError = null;
          _codeError = null;
        });
        widget.onChanged(s, null, '');
      },
    );
  }

  Widget _cityDropdown() {
    if (selectedState == null) {
      return DropdownButtonFormField<CityEntity>(
        key: const ValueKey('city-empty'),
        initialValue: null,
        decoration: _dec('City *', _cityError).copyWith(
          enabled: false,
          hintText: 'Select a state first',
          hintStyle: AppTextStyles.caption,
        ),
        items: const [],
        onChanged: null,
      );
    }
    final citiesAsync = ref.watch(citiesProvider(selectedState!.id));
    return citiesAsync.when(
      loading: () => _shimmer('City *', 'Loading cities…'),
      // Web: a failed cities request leaves an empty list; Other still works.
      error: (e, _) => _cityPicker(const []),
      data: _cityPicker,
    );
  }

  Widget _cityPicker(List<CityEntity> cities) {
    CityEntity? effective;
    if (isOtherCity) {
      effective = _otherCity;
    } else if (selectedCity != null) {
      try {
        effective = cities.firstWhere((c) => c.id == selectedCity!.id);
      } catch (_) {}
    }
    final picker = DropdownButtonFormField<CityEntity>(
      key: ValueKey('city-${selectedState?.id}-${selectedCity?.id}-$isOtherCity'),
      initialValue: effective,
      isExpanded: true,
      style: AppTextStyles.body,
      decoration: _dec('City *', _cityError),
      hint: Text('Select City', style: AppTextStyles.caption),
      // Web: the Other option is always last, once a state is chosen.
      items: [
        ...cities.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            )),
        const DropdownMenuItem(value: _otherCity, child: Text(kOtherCityLabel)),
      ],
      onChanged: (c) async {
        final other = identical(c, _otherCity);
        setState(() {
          isOtherCity = other;
          selectedCity = other ? null : c;
          if (!other) newCityCtrl.clear();
          _cityError = null;
          _newCityError = null;
          _codeError = null;
          _debounce?.cancel();
          _codeToken++;
          _isLoadingCode = false;
          if (widget.isAdd) branchCode = '';
        });
        if (widget.isAdd && c != null && !other) await _loadCode(cityId: c.id);
        widget.onChanged(selectedState, other ? null : c, branchCode);
      },
    );
    if (!isOtherCity) return picker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        picker,
        const SizedBox(height: 8),
        TextField(
          key: const Key('branch-new-city-name'),
          controller: newCityCtrl,
          style: AppTextStyles.body,
          maxLength: 100,
          // Web strips everything but letters, space, apostrophe and hyphen.
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z '-]"))],
          decoration: _dec('Enter new city name', _newCityError).copyWith(counterText: ''),
          onChanged: (_) {
            setState(() {
              _newCityError = null;
              _codeError = null;
            });
            _schedulePreview();
          },
        ),
      ],
    );
  }

  // Web: preview the code of a not-yet-created city, debounced 400 ms on the
  // typed name; an invalid / empty name clears the code.
  void _schedulePreview() {
    if (!widget.isAdd) return;
    _debounce?.cancel();
    final name = newCityName;
    if (!kCityNameRe.hasMatch(name)) {
      _codeToken++;
      setState(() {
        _isLoadingCode = false;
        branchCode = '';
      });
      return;
    }
    setState(() => _isLoadingCode = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadCode(cityName: name));
  }

  Widget _codeField() {
    return TextFormField(
      readOnly: true,
      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      controller: TextEditingController(text: _isLoadingCode ? '' : branchCode),
      decoration: _dec('Branch Code (auto-generated)', _codeError).copyWith(
        hintText: !(isOtherCity || selectedCity != null)
            ? 'Select a city first'
            : _isLoadingCode
                ? 'Generating…'
                : null,
        hintStyle: AppTextStyles.caption,
        helperText: branchCode.isNotEmpty && !_isLoadingCode && _codeError == null
            ? 'Additional branches in the same city get suffixed automatically (e.g. MUM-01, MUM-02)'
            : null,
        helperMaxLines: 2,
        suffixIcon: _isLoadingCode
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.backgroundLow,
      ),
    );
  }

  Widget _shimmer(String label, [String text = 'Loading...']) {
    return InputDecorator(
      decoration: _dec(label),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _errorTile(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _loadCode({int? cityId, String? cityName}) async {
    final token = ++_codeToken;
    setState(() => _isLoadingCode = true);
    String code = '';
    try {
      code = await ref
          .read(branchRepositoryProvider)
          .previewBranchCode(cityId: cityId, cityName: cityName);
    } catch (_) {}
    // A newer selection / keystroke owns the code now.
    if (!mounted || token != _codeToken) return;
    setState(() {
      branchCode = code;
      _isLoadingCode = false;
    });
    widget.onChanged(selectedState, selectedCity, branchCode);
  }
}
