import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

class CountryCode {
  const CountryCode(this.flag, this.name, this.code, this.digits);
  final String flag, name, code;
  final int digits;
}

const _countries = [
  CountryCode('🇮🇳', 'India',               '+91',   10),
  CountryCode('🇦🇫', 'Afghanistan',          '+93',   9),
  CountryCode('🇦🇱', 'Albania',              '+355',  9),
  CountryCode('🇩🇿', 'Algeria',              '+213',  9),
  CountryCode('🇦🇴', 'Angola',               '+244',  9),
  CountryCode('🇦🇷', 'Argentina',            '+54',   10),
  CountryCode('🇦🇲', 'Armenia',              '+374',  8),
  CountryCode('🇦🇺', 'Australia',            '+61',   9),
  CountryCode('🇦🇹', 'Austria',              '+43',   10),
  CountryCode('🇦🇿', 'Azerbaijan',           '+994',  9),
  CountryCode('🇧🇭', 'Bahrain',              '+973',  8),
  CountryCode('🇧🇩', 'Bangladesh',           '+880',  10),
  CountryCode('🇧🇾', 'Belarus',              '+375',  9),
  CountryCode('🇧🇪', 'Belgium',              '+32',   9),
  CountryCode('🇧🇿', 'Belize',               '+501',  7),
  CountryCode('🇧🇧', 'Barbados',             '+1246', 7),
  CountryCode('🇧🇴', 'Bolivia',              '+591',  8),
  CountryCode('🇧🇦', 'Bosnia Herzegovina',   '+387',  8),
  CountryCode('🇧🇷', 'Brazil',               '+55',   11),
  CountryCode('🇧🇳', 'Brunei',               '+673',  7),
  CountryCode('🇧🇬', 'Bulgaria',             '+359',  9),
  CountryCode('🇨🇲', 'Cameroon',             '+237',  9),
  CountryCode('🇨🇦', 'Canada',               '+1',    10),
  CountryCode('🇨🇱', 'Chile',                '+56',   9),
  CountryCode('🇨🇳', 'China',                '+86',   11),
  CountryCode('🇨🇴', 'Colombia',             '+57',   10),
  CountryCode('🇨🇬', 'Congo',                '+242',  9),
  CountryCode('🇨🇷', 'Costa Rica',           '+506',  8),
  CountryCode('🇭🇷', 'Croatia',              '+385',  9),
  CountryCode('🇨🇺', 'Cuba',                 '+53',   8),
  CountryCode('🇨🇾', 'Cyprus',               '+357',  8),
  CountryCode('🇨🇿', 'Czech Republic',       '+420',  9),
  CountryCode('🇩🇰', 'Denmark',              '+45',   8),
  CountryCode('🇪🇬', 'Egypt',                '+20',   10),
  CountryCode('🇪🇹', 'Ethiopia',             '+251',  9),
  CountryCode('🇫🇮', 'Finland',              '+358',  10),
  CountryCode('🇫🇷', 'France',               '+33',   9),
  CountryCode('🇬🇪', 'Georgia',              '+995',  9),
  CountryCode('🇩🇪', 'Germany',              '+49',   10),
  CountryCode('🇬🇭', 'Ghana',                '+233',  9),
  CountryCode('🇬🇷', 'Greece',               '+30',   10),
  CountryCode('🇬🇹', 'Guatemala',            '+502',  8),
  CountryCode('🇭🇰', 'Hong Kong',            '+852',  8),
  CountryCode('🇭🇺', 'Hungary',              '+36',   9),
  CountryCode('🇮🇸', 'Iceland',              '+354',  7),
  CountryCode('🇮🇩', 'Indonesia',            '+62',   10),
  CountryCode('🇮🇷', 'Iran',                 '+98',   10),
  CountryCode('🇮🇶', 'Iraq',                 '+964',  10),
  CountryCode('🇮🇪', 'Ireland',              '+353',  9),
  CountryCode('🇮🇱', 'Israel',               '+972',  9),
  CountryCode('🇮🇹', 'Italy',                '+39',   10),
  CountryCode('🇯🇲', 'Jamaica',              '+1876', 7),
  CountryCode('🇯🇵', 'Japan',                '+81',   10),
  CountryCode('🇯🇴', 'Jordan',               '+962',  9),
  CountryCode('🇰🇿', 'Kazakhstan',           '+7',    10),
  CountryCode('🇰🇪', 'Kenya',                '+254',  9),
  CountryCode('🇰🇼', 'Kuwait',               '+965',  8),
  CountryCode('🇱🇧', 'Lebanon',              '+961',  8),
  CountryCode('🇲🇾', 'Malaysia',             '+60',   9),
  CountryCode('🇲🇻', 'Maldives',             '+960',  7),
  CountryCode('🇲🇱', 'Mali',                 '+223',  8),
  CountryCode('🇲🇽', 'Mexico',               '+52',   10),
  CountryCode('🇲🇳', 'Mongolia',             '+976',  8),
  CountryCode('🇲🇦', 'Morocco',              '+212',  9),
  CountryCode('🇲🇿', 'Mozambique',           '+258',  9),
  CountryCode('🇲🇲', 'Myanmar',              '+95',   9),
  CountryCode('🇳🇵', 'Nepal',                '+977',  10),
  CountryCode('🇳🇱', 'Netherlands',          '+31',   9),
  CountryCode('🇳🇿', 'New Zealand',          '+64',   9),
  CountryCode('🇳🇬', 'Nigeria',              '+234',  10),
  CountryCode('🇳🇴', 'Norway',               '+47',   8),
  CountryCode('🇴🇲', 'Oman',                 '+968',  8),
  CountryCode('🇵🇰', 'Pakistan',             '+92',   10),
  CountryCode('🇵🇸', 'Palestine',            '+970',  9),
  CountryCode('🇵🇦', 'Panama',               '+507',  8),
  CountryCode('🇵🇭', 'Philippines',          '+63',   10),
  CountryCode('🇵🇱', 'Poland',               '+48',   9),
  CountryCode('🇵🇹', 'Portugal',             '+351',  9),
  CountryCode('🇶🇦', 'Qatar',                '+974',  8),
  CountryCode('🇷🇴', 'Romania',              '+40',   9),
  CountryCode('🇷🇺', 'Russia',               '+7',    10),
  CountryCode('🇸🇦', 'Saudi Arabia',         '+966',  9),
  CountryCode('🇸🇳', 'Senegal',              '+221',  9),
  CountryCode('🇷🇸', 'Serbia',               '+381',  9),
  CountryCode('🇸🇬', 'Singapore',            '+65',   8),
  CountryCode('🇿🇦', 'South Africa',         '+27',   9),
  CountryCode('🇰🇷', 'South Korea',          '+82',   10),
  CountryCode('🇪🇸', 'Spain',                '+34',   9),
  CountryCode('🇱🇰', 'Sri Lanka',            '+94',   9),
  CountryCode('🇸🇩', 'Sudan',                '+249',  9),
  CountryCode('🇸🇪', 'Sweden',               '+46',   9),
  CountryCode('🇨🇭', 'Switzerland',          '+41',   9),
  CountryCode('🇸🇾', 'Syria',                '+963',  9),
  CountryCode('🇹🇼', 'Taiwan',               '+886',  9),
  CountryCode('🇹🇿', 'Tanzania',             '+255',  9),
  CountryCode('🇹🇭', 'Thailand',             '+66',   9),
  CountryCode('🇹🇳', 'Tunisia',              '+216',  8),
  CountryCode('🇹🇷', 'Turkey',               '+90',   10),
  CountryCode('🇺🇬', 'Uganda',               '+256',  9),
  CountryCode('🇺🇦', 'Ukraine',              '+380',  9),
  CountryCode('🇦🇪', 'UAE',                  '+971',  9),
  CountryCode('🇬🇧', 'United Kingdom',       '+44',   10),
  CountryCode('🇺🇸', 'United States',        '+1',    10),
  CountryCode('🇺🇾', 'Uruguay',              '+598',  8),
  CountryCode('🇺🇿', 'Uzbekistan',           '+998',  9),
  CountryCode('🇻🇳', 'Vietnam',              '+84',   9),
  CountryCode('🇾🇪', 'Yemen',                '+967',  9),
  CountryCode('🇿🇲', 'Zambia',               '+260',  9),
  CountryCode('🇿🇼', 'Zimbabwe',             '+263',  9),
];

class PhoneFieldWithCode extends StatefulWidget {
  const PhoneFieldWithCode({
    super.key,
    required this.ctrl,
    this.required = false,
    this.hint = 'Mobile number',
  });
  final TextEditingController ctrl;
  final bool required;
  final String hint;

  @override
  State<PhoneFieldWithCode> createState() => _PhoneFieldWithCodeState();
}

class _PhoneFieldWithCodeState extends State<PhoneFieldWithCode> {
  CountryCode _selected = _countries.first; // India is first

  void _openPicker() {
    final search = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final filtered = search.text.isEmpty
              ? _countries
              : _countries.where((c) =>
                  c.name.toLowerCase().contains(search.text.toLowerCase()) ||
                  c.code.contains(search.text)).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Select Country Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: (_) => setInner(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search country…',
                    prefixIcon: const Icon(Icons.search, size: 20, color: _onSurface3),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  final active = c.code == _selected.code && c.name == _selected.name;
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: Text(c.code, style: TextStyle(fontWeight: FontWeight.w800, color: active ? _brand600 : _onSurface2, fontSize: 14)),
                    selected: active,
                    selectedTileColor: _brand100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      setState(() => _selected = c);
                      Navigator.pop(ctx);
                    },
                  );
                },
              )),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    GestureDetector(
      onTap: _openPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_selected.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(_selected.code, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _onSurface1)),
          const SizedBox(width: 3),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _onSurface3),
        ]),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(child: TextFormField(
      controller: widget.ctrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_selected.digits),
      ],
      validator: widget.required
          ? (v) => (v == null || v.isEmpty) ? 'Enter mobile number' : null
          : null,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _onSurface1),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: _onSurface3, fontSize: 14, fontWeight: FontWeight.w500),
        filled: true, fillColor: _surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        isDense: true,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: _border)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: _border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: _brand600, width: 1.5)),
        errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFF2685E))),
      ),
    )),
  ]);
}
