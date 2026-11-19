import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../profile/presentation/widgets/profile_sections.dart' show ProfileFieldGrid;
import '../../../../profile/presentation/widgets/profile_widgets.dart';
import '../../../data/models/company_model.dart';
import '../../../domain/company_validation.dart';
import 'company_widgets.dart';

/// The Company Information form (web settings/company/page.tsx): Branding
/// name fields, Legal & Statutory, Registered Address, Contact. Editable with
/// settings.edit, otherwise the same values read-only. Errors appear under the
/// fields on Save and clear as the field is edited (web `handleField`).
///
/// [branding] is shown inside the Branding card, above the name fields (the
/// logo controls — the screen owns the logo state).
class CompanyFormFields extends StatefulWidget {
  const CompanyFormFields({
    super.key,
    required this.company,
    required this.onChanged,
    this.readOnly = false,
    this.branding,
  });

  final CompanyModel company;
  final ValueChanged<CompanyModel> onChanged;
  final bool readOnly;
  final Widget? branding;

  @override
  State<CompanyFormFields> createState() => CompanyFormFieldsState();
}

class CompanyFormFieldsState extends State<CompanyFormFields> {
  late final TextEditingController _name = TextEditingController(text: widget.company.companyName);
  late final TextEditingController _trade = TextEditingController(text: widget.company.tradeName);
  late final TextEditingController _gstin = TextEditingController(text: widget.company.gstin);
  late final TextEditingController _cin = TextEditingController(text: widget.company.cin);
  late final TextEditingController _pan = TextEditingController(text: widget.company.pan);
  late final TextEditingController _tan = TextEditingController(text: widget.company.tan);
  late final TextEditingController _address = TextEditingController(text: widget.company.address);
  late final TextEditingController _city = TextEditingController(text: widget.company.city);
  late final TextEditingController _pin = TextEditingController(text: widget.company.pinCode);
  late final TextEditingController _website = TextEditingController(text: widget.company.website);
  late final TextEditingController _phone = TextEditingController(text: widget.company.officialPhone);
  String _state = '';
  Map<String, String> _errors = {};
  final Map<String, GlobalKey> _keys = {for (final k in kCompanyFieldOrder) k: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _state = widget.company.state;
  }

  @override
  void dispose() {
    for (final c in [_name, _trade, _gstin, _cin, _pan, _tan, _address, _city, _pin, _website, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  CompanyModel _current() => widget.company.copyWith(
        companyName: _name.text,
        tradeName: _trade.text,
        gstin: _gstin.text,
        cin: _cin.text,
        pan: _pan.text,
        tan: _tan.text,
        address: _address.text,
        city: _city.text,
        state: _state,
        pinCode: _pin.text,
        website: _website.text,
        officialPhone: _phone.text,
      );

  /// Web `handleField`: notify, and clear that field's error.
  void _changed(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
    widget.onChanged(_current());
  }

  /// Runs web's validation; shows the messages and scrolls to the first one.
  bool validate() {
    final errs = validateCompany(_current());
    setState(() => _errors = errs);
    if (errs.isEmpty) return true;
    final first = kCompanyFieldOrder.firstWhere(errs.containsKey);
    final ctx = _keys[first]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 200));
    return false;
  }

  Widget _text(
    String key,
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool upper = false,
    List<TextInputFormatter> formatters = const [],
  }) {
    if (widget.readOnly) {
      return ProfileDisplayField(label: label.replaceAll(' *', ''), value: c.text.trim(), padBottom: false);
    }
    return CompanyField(
      fieldKey: _keys[key],
      controller: c,
      label: label,
      hint: hint,
      errorText: _errors[key],
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      capitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
      formatters: [if (upper) const UpperCaseFormatter(), ...formatters],
      onChanged: (_) => _changed(key),
    );
  }

  Widget _stateField() {
    if (widget.readOnly) return ProfileDisplayField(label: 'State / UT', value: _state, padBottom: false);
    return Column(
      key: _keys['state'],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State / UT *',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _state.isEmpty ? null : _state,
          isExpanded: true,
          hint: Text('Select…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            errorText: _errors['state'],
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.error)),
          ),
          items: [
            for (final s in kIndianStates) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            setState(() => _state = v ?? '');
            _changed('state');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionCard(
          icon: Icons.business_outlined,
          title: 'Branding',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.branding != null) ...[widget.branding!, const SizedBox(height: 16)],
              ProfileFieldGrid(children: [
                _text('company_name', _name, 'Company Name *', hint: 'Registered company name'),
                _text('trade_name', _trade, 'Trade Name', hint: 'DBA or brand name (optional)'),
              ]),
            ],
          ),
        ),
        gap,
        ProfileSectionCard(
          icon: Icons.verified_outlined,
          title: 'Legal & Statutory',
          child: ProfileFieldGrid(children: [
            _text('gstin', _gstin, 'GSTIN *', hint: '22AAAAA0000A1Z5', maxLength: 15, upper: true),
            _text('cin', _cin, 'CIN *', hint: 'U74999MH2020PTC123456', maxLength: 21, upper: true),
            _text('pan', _pan, 'PAN *', hint: 'AAAAA0000A', maxLength: 10, upper: true),
            _text('tan', _tan, 'TAN *', hint: 'PNEA12345B', maxLength: 10, upper: true),
          ]),
        ),
        gap,
        ProfileSectionCard(
          icon: Icons.location_on_outlined,
          title: 'Registered Address',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text('address', _address, 'Address *', hint: 'Street address, building, floor…', maxLines: 3),
              const SizedBox(height: 16),
              ProfileFieldGrid(children: [
                _text('city', _city, 'City *', hint: 'Mumbai'),
                _stateField(),
                _text('pin_code', _pin, 'PIN Code *',
                    hint: '400001',
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly]),
              ]),
            ],
          ),
        ),
        gap,
        ProfileSectionCard(
          icon: Icons.contact_phone_outlined,
          title: 'Contact',
          child: ProfileFieldGrid(children: [
            _text('website', _website, 'Website', hint: 'https://royalstaffing.in', keyboardType: TextInputType.url),
            _text('official_phone', _phone, 'Official Phone',
                hint: '+91 98765 43210', keyboardType: TextInputType.phone),
          ]),
        ),
      ],
    );
  }
}
