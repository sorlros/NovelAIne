import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app_style.dart';

/// The colours of one screen theme. Screens read them with `context.palette` and name no colour
/// themselves, so a theme the reader picks reaches every screen.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;

  /// Page background.
  final Color ground;

  /// Cards, sheets, bars and dialogs.
  final Color surface;

  /// Controls on a surface: choices, chips, inputs.
  final Color raised;

  /// Borders and dividers.
  final Color line;

  /// Body text, titles and main icons.
  final Color text;

  /// Secondary text and icons.
  final Color muted;

  /// Hints, disabled controls and decorative icons.
  final Color faint;

  final Color accent;

  /// Text and icons on an accent fill.
  final Color onAccent;

  final Color danger;
  final Color success;
  final Color warning;

  final Color? _highlight;
  final Color? _onHighlight;

  /// A second, louder fill for what the reader acts on (the route theme's yellow); the accent elsewhere.
  Color get highlight => _highlight ?? accent;

  /// Text and icons on [highlight].
  Color get onHighlight => _onHighlight ?? onAccent;

  const AppPalette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.raised,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.warning,
    Color? highlight,
    Color? onHighlight,
  }) : _highlight = highlight,
       _onHighlight = onHighlight;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? ground,
    Color? surface,
    Color? raised,
    Color? line,
    Color? text,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? success,
    Color? warning,
    Color? highlight,
    Color? onHighlight,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      line: line ?? this.line,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      highlight: highlight ?? this.highlight,
      onHighlight: onHighlight ?? this.onHighlight,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      ground: mix(ground, other.ground),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      line: mix(line, other.line),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      danger: mix(danger, other.danger),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      highlight: mix(highlight, other.highlight),
      onHighlight: mix(onHighlight, other.onHighlight),
    );
  }

  List<Object> get _values => [
    brightness,
    ground,
    surface,
    raised,
    line,
    text,
    muted,
    faint,
    accent,
    onAccent,
    danger,
    success,
    warning,
    highlight,
    onHighlight,
  ];

  @override
  bool operator ==(Object other) =>
      other is AppPalette && listEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAll(_values);
}

/// The screen themes a reader can pick: colours and a look. The name is what is stored on the device.
enum AppThemeId {
  simya('심야', '밤에 읽는 기본 화면', _simya, AppStyle.night),
  meok('먹', '완전한 검정, 가장 어두운 화면', _meok, AppStyle.night),
  noeul('노을', '붉은 기운이 도는 따뜻한 어둠', _noeul, AppStyle.night),
  saebyeok('새벽', '푸른 기운이 도는 밝은 화면', _saebyeok, AppStyle.night),
  wongoji('원고지', '종이에 명조, 낮에 읽기 좋은 화면', _wongoji, AppStyle.paper),
  galimgil('갈림길', '굵은 선과 번호, 지나온 길이 보이는 화면', _galimgil, AppStyle.route);

  final String label;
  final String description;
  final AppPalette palette;
  final AppStyle style;

  const AppThemeId(this.label, this.description, this.palette, this.style);
}

const _simya = AppPalette(
  brightness: Brightness.dark,
  ground: Color(0xFF0F1217),
  surface: Color(0xFF181C23),
  raised: Color(0xFF20262F),
  line: Color(0xFF2C333E),
  text: Color(0xFFECE9E2),
  muted: Color(0xFFA39E94),
  faint: Color(0xFF7C7A75),
  accent: Color(0xFFE9B45B),
  onAccent: Color(0xFF1A1408),
  danger: Color(0xFFF7768E),
  success: Color(0xFF9ECE6A),
  warning: Color(0xFFFFD166),
);

const _meok = AppPalette(
  brightness: Brightness.dark,
  ground: Color(0xFF000000),
  surface: Color(0xFF111111),
  raised: Color(0xFF1C1C1C),
  line: Color(0xFF2A2A2A),
  text: Color(0xFFF2F2F2),
  muted: Color(0xFFA0A0A0),
  faint: Color(0xFF7A7A7A),
  accent: Color(0xFFFFFFFF),
  onAccent: Color(0xFF000000),
  danger: Color(0xFFF7768E),
  success: Color(0xFF9ECE6A),
  warning: Color(0xFFFFD166),
);

const _noeul = AppPalette(
  brightness: Brightness.dark,
  ground: Color(0xFF1B1216),
  surface: Color(0xFF261A20),
  raised: Color(0xFF32232B),
  line: Color(0xFF45323B),
  text: Color(0xFFF1E7E4),
  muted: Color(0xFFB5A3A3),
  faint: Color(0xFF8C7B7D),
  accent: Color(0xFFF08A6C),
  onAccent: Color(0xFF2A0F08),
  danger: Color(0xFFF7768E),
  success: Color(0xFF9ECE6A),
  warning: Color(0xFFFFD166),
);

const _wongoji = AppPalette(
  brightness: Brightness.light,
  ground: Color(0xFFF6F4EE),
  surface: Color(0xFFFFFEFA),
  raised: Color(0xFFECE8DD),
  line: Color(0xFFD9D4C7),
  text: Color(0xFF1F1D1A),
  muted: Color(0xFF6B665E),
  faint: Color(0xFF857F74),
  accent: Color(0xFFB5301C),
  onAccent: Color(0xFFFFFFFF),
  danger: Color(0xFFB3261E),
  success: Color(0xFF256B29),
  warning: Color(0xFF8A5A00),
);

const _saebyeok = AppPalette(
  brightness: Brightness.light,
  ground: Color(0xFFEEF1F5),
  surface: Color(0xFFFFFFFF),
  raised: Color(0xFFE1E6ED),
  line: Color(0xFFCBD2DC),
  text: Color(0xFF17202B),
  muted: Color(0xFF566170),
  faint: Color(0xFF717B88),
  accent: Color(0xFF2F5BD0),
  onAccent: Color(0xFFFFFFFF),
  danger: Color(0xFFB3261E),
  success: Color(0xFF256B29),
  warning: Color(0xFF8A5A00),
);

const _galimgil = AppPalette(
  brightness: Brightness.light,
  ground: Color(0xFFE9EAF2),
  surface: Color(0xFFFFFFFF),
  raised: Color(0xFFF3F4F8),
  line: Color(0xFFB9BCCB),
  text: Color(0xFF0F1020),
  muted: Color(0xFF555872),
  faint: Color(0xFF6E7189),
  accent: Color(0xFF2536C9),
  onAccent: Color(0xFFFFFFFF),
  danger: Color(0xFFB3261E),
  success: Color(0xFF256B29),
  warning: Color(0xFF8A5A00),
  highlight: Color(0xFFFFD43B),
  onHighlight: Color(0xFF0F1020),
);

extension PaletteContext on BuildContext {
  /// The colours of the theme in use. A widget built outside the app's theme gets the default theme's.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppThemeId.simya.palette;
}
