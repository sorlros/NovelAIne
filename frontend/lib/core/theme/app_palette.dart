import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

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
  });

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
  ];

  @override
  bool operator ==(Object other) =>
      other is AppPalette && listEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAll(_values);
}

/// The screen themes a reader can pick. The name is what is stored on the device.
enum AppThemeId {
  simya('심야', '밤에 읽는 기본 화면', _simya),
  meok('먹', '완전한 검정, 가장 어두운 화면', _meok),
  noeul('노을', '붉은 기운이 도는 따뜻한 어둠', _noeul),
  wongoji('원고지', '종이와 주홍, 낮에 읽기 좋은 화면', _wongoji),
  saebyeok('새벽', '푸른 기운이 도는 밝은 화면', _saebyeok);

  final String label;
  final String description;
  final AppPalette palette;

  const AppThemeId(this.label, this.description, this.palette);
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

extension PaletteContext on BuildContext {
  /// The colours of the theme in use. A widget built outside the app's theme gets the default theme's.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppThemeId.simya.palette;
}
