import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

  const BranchLocationSelector({
    super.key,
    this.initialState,
    this.initialCity,
    this.initialCode = '',
    required this.onChanged,
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

  bool _isLoadingCode = false;
  String? _stateError;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    selectedState = widget.initialState;
    selectedCity = widget.initialCity;
    branchCode = widget.initialCode;
  }

  bool validate() {
    setState(() {
      _stateError = selectedState == null ? 'Please select a state' : null;
      _cityError = selectedCity == null ? 'Please select a city' : null;
    });
    return selectedState != null && selectedCity != null;
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(statesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        statesAsync.when(
          loading: () => _shimmer('State / Region'),
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
      decoration: _dec('State / Region *', _stateError),
      hint: Text('Select state', style: AppTextStyles.caption),
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
          branchCode = '';
          _stateError = null;
          _cityError = null;
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
        decoration: _dec('City').copyWith(
          enabled: false,
          hintText: 'Select state first',
          hintStyle: AppTextStyles.caption,
        ),
        items: const [],
        onChanged: null,
      );
    }
    final citiesAsync = ref.watch(citiesProvider(selectedState!.id));
    return citiesAsync.when(
      loading: () => _shimmer('City'),
      error: (e, _) => _errorTile('Could not load cities'),
      data: (cities) {
        CityEntity? effective;
        if (selectedCity != null) {
          try {
            effective = cities.firstWhere((c) => c.id == selectedCity!.id);
          } catch (_) {}
        }
        return DropdownButtonFormField<CityEntity>(
          key:
              ValueKey('city-${selectedState?.id}-${selectedCity?.id}'),
          initialValue: effective,
          isExpanded: true,
          style: AppTextStyles.body,
          decoration: _dec('City *', _cityError),
          hint: Text('Select city', style: AppTextStyles.caption),
          items: cities
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (c) async {
            setState(() {
              selectedCity = c;
              _cityError = null;
              branchCode = '';
            });
            if (c != null) await _loadCode(c.id);
            widget.onChanged(selectedState, c, branchCode);
          },
        );
      },
    );
  }

  Widget _codeField() {
    return TextFormField(
      readOnly: true,
      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      controller: TextEditingController(text: branchCode),
      decoration: _dec('Branch Code (auto-generated)').copyWith(
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

  Widget _shimmer(String label) {
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
          Text('Loading...', style: AppTextStyles.caption),
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
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
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
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _loadCode(int cityId) async {
    setState(() => _isLoadingCode = true);
    try {
      final code =
          await ref.read(branchRepositoryProvider).previewBranchCode(cityId);
      if (mounted) setState(() => branchCode = code);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCode = false);
  }
}
