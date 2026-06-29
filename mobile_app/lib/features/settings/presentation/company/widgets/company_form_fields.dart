import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/company_model.dart';

// ── Validators ────────────────────────────────────────────────────────────────

final _gstinRe = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z1-9]Z[A-Z\d]$');
final _panRe   = RegExp(r'^[A-Z]{5}\d{4}[A-Z]$');
final _cinRe   = RegExp(r'^[UL]\d{5}[A-Z]{2}\d{4}[A-Z]{3}\d{6}$');
final _tanRe   = RegExp(r'^[A-Z]{4}\d{5}[A-Z]$');
final _pinRe   = RegExp(r'^\d{6}$');
final _phoneRe = RegExp(r'^[+\d\s\-().\/]{7,20}$');
final _urlRe   = RegExp(r'^https?://');

// ── Widget ────────────────────────────────────────────────────────────────────

class CompanyFormFields extends StatefulWidget {
  final CompanyModel company;
  final ValueChanged<CompanyModel> onChanged;

  const CompanyFormFields({
    super.key,
    required this.company,
    required this.onChanged,
  });

  @override
  State<CompanyFormFields> createState() => _CompanyFormFieldsState();
}

class _CompanyFormFieldsState extends State<CompanyFormFields> {
  late final TextEditingController _name      = _ctrl(widget.company.companyName);
  late final TextEditingController _trade     = _ctrl(widget.company.tradeName);
  late final TextEditingController _gstin     = _ctrl(widget.company.gstin);
  late final TextEditingController _cin       = _ctrl(widget.company.cin);
  late final TextEditingController _pan       = _ctrl(widget.company.pan);
  late final TextEditingController _tan       = _ctrl(widget.company.tan);
  late final TextEditingController _address   = _ctrl(widget.company.address);
  late final TextEditingController _city      = _ctrl(widget.company.city);
  late final TextEditingController _pin       = _ctrl(widget.company.pinCode);
  late final TextEditingController _website   = _ctrl(widget.company.website);
  late final TextEditingController _phone     = _ctrl(widget.company.officialPhone);
  String? _selectedState;

  TextEditingController _ctrl(String value) => TextEditingController(text: value);

  @override
  void initState() {
    super.initState();
    _selectedState = widget.company.state.isEmpty ? null : widget.company.state;
  }

  CompanyModel _current() => widget.company.copyWith(
    companyName:   _name.text,
    tradeName:     _trade.text,
    gstin:         _gstin.text.toUpperCase(),
    cin:           _cin.text.toUpperCase(),
    pan:           _pan.text.toUpperCase(),
    tan:           _tan.text.toUpperCase(),
    address:       _address.text,
    city:          _city.text,
    state:         _selectedState ?? '',
    pinCode:       _pin.text,
    website:       _website.text,
    officialPhone: _phone.text,
  );

  void _notify() => widget.onChanged(_current());

  @override
  void dispose() {
    for (final c in [_name, _trade, _gstin, _cin, _pan, _tan, _address, _city, _pin, _website, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          icon: Icons.business_outlined,
          title: 'Basic Details',
          color: AppColors.primary,
          children: [
            _field(_name, 'Company Name *', validator: _required),
            _field(_trade, 'Trade Name'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.assignment_outlined,
          title: 'Registration Numbers',
          color: const Color(0xFF9C5700),
          children: [
            _field(_gstin, 'GSTIN *',
                validator: (v) => _regexVal(v, _gstinRe, 'Enter a valid 15-character GSTIN'),
                hint: 'e.g. 27AAPFU0939F1ZV'),
            _field(_cin, 'CIN *',
                validator: (v) => _regexVal(v, _cinRe, 'Enter a valid CIN'),
                hint: 'e.g. U74999MH2020PTC123456'),
            _field(_pan, 'PAN *',
                validator: (v) => _regexVal(v, _panRe, 'Enter a valid 10-character PAN'),
                hint: 'e.g. AAPFU0939F'),
            _field(_tan, 'TAN *',
                validator: (v) => _regexVal(v, _tanRe, 'Enter a valid 10-character TAN'),
                hint: 'e.g. MUMO3581G'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.location_on_outlined,
          title: 'Address',
          color: AppColors.success,
          children: [
            _field(_address, 'Street Address *', maxLines: 3, validator: _required),
            _field(_city, 'City *', validator: _required),
            _stateDropdown(),
            _field(_pin, 'PIN Code *',
                keyboardType: TextInputType.number,
                validator: (v) => _regexVal(v, _pinRe, 'Must be exactly 6 digits')),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.contact_phone_outlined,
          title: 'Contact',
          color: const Color(0xFF5B3599),
          children: [
            _field(_website, 'Website',
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (!_urlRe.hasMatch(v)) return 'Must start with http:// or https://';
                  return null;
                }),
            _field(_phone, 'Official Phone',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (!_phoneRe.hasMatch(v)) return 'Enter a valid phone number';
                  return null;
                }),
          ],
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.body,
        onChanged: (_) => _notify(),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _stateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        isExpanded: true,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: 'State / UT *',
          labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
        items: kIndianStates
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppTextStyles.body)))
            .toList(),
        onChanged: (val) {
          setState(() => _selectedState = val);
          _notify();
        },
      ),
    );
  }

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  static String? _regexVal(String? v, RegExp re, String msg) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    if (!re.hasMatch(v.trim().toUpperCase())) return msg;
    return null;
  }
}

// ── Section card with banner-fused header ─────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            color: color,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
