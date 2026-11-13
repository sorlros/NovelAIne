import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// The look a theme draws its screens with, beside its colours: the shapes of cards and controls,
/// their outlines and shadows, the face of titles. Screens read it with `context.appStyle`.
enum StyleKind {
  /// Rounded filled cards over a dark or quiet ground; scene pictures lead.
  night,

  /// A sheet of paper: square corners, hairline rules instead of boxes, serif titles, ink buttons.
  paper,

  /// Flat blocks with thick ink outlines and hard offset shadows; choices are numbered.
  route,
}

@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  final StyleKind kind;

  /// Chips, inputs, buttons and small badges.
  final double radiusSmall;

  /// Cards, choices and panels.
  final double radius;

  /// Sheets and large hero cards.
  final double radiusLarge;

  const AppStyle._(this.kind, this.radiusSmall, this.radius, this.radiusLarge);

  static const night = AppStyle._(StyleKind.night, 10, 14, 20);
  static const paper = AppStyle._(StyleKind.paper, 3, 3, 4);
  static const route = AppStyle._(StyleKind.route, 6, 6, 8);

  bool get isNight => kind == StyleKind.night;
  bool get isPaper => kind == StyleKind.paper;
  bool get isRoute => kind == StyleKind.route;

  /// Outline width of cards and controls.
  double get borderWidth => isRoute ? 2 : 1;

  /// Colour of the outline of cards and controls.
  Color edge(AppPalette p) => isRoute ? p.text : p.line;

  /// The hard ink shadow of the route style, none in the others.
  List<BoxShadow> shadow(AppPalette p, {double offset = 4}) => isRoute
      ? [BoxShadow(color: p.text, offset: Offset(offset, offset))]
      : const [];

  /// A card, panel or list block.
  BoxDecoration card(AppPalette p, {bool raised = false}) => BoxDecoration(
    color: raised ? p.raised : p.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: edge(p), width: borderWidth),
    boxShadow: shadow(p),
  );

  /// A control the reader picks: a choice, a chip, a menu row. [selected] marks the picked one.
  BoxDecoration control(AppPalette p, {bool selected = false}) {
    switch (kind) {
      case StyleKind.night:
        return BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.15) : p.raised,
          borderRadius: BorderRadius.circular(radiusSmall + 2),
          border: Border.all(
            color: selected ? p.accent : Colors.transparent,
            width: 1.5,
          ),
        );
      case StyleKind.paper:
        return BoxDecoration(
          color: selected ? p.text : Colors.transparent,
          borderRadius: BorderRadius.circular(radiusSmall),
          border: Border.all(color: selected ? p.text : p.faint),
        );
      case StyleKind.route:
        return BoxDecoration(
          color: selected ? p.highlight : p.surface,
          borderRadius: BorderRadius.circular(radiusSmall),
          border: Border.all(color: p.text, width: 2),
          boxShadow: shadow(p, offset: selected ? 2 : 3),
        );
    }
  }

  /// Text and icons on a [control].
  Color onControl(AppPalette p, {bool selected = false}) {
    if (!selected) return p.text;
    switch (kind) {
      case StyleKind.night:
        return p.text;
      case StyleKind.paper:
        return p.ground;
      case StyleKind.route:
        return p.onHighlight;
    }
  }

  /// Fill of the screen's main action: the accent at night, ink on paper, the highlight on the route.
  Color primary(AppPalette p) => switch (kind) {
    StyleKind.night => p.accent,
    StyleKind.paper => p.text,
    StyleKind.route => p.highlight,
  };

  /// Text and icons on [primary].
  Color onPrimary(AppPalette p) => switch (kind) {
    StyleKind.night => p.onAccent,
    StyleKind.paper => p.ground,
    StyleKind.route => p.onHighlight,
  };

  /// Outline of the main action; only the route style draws one.
  BorderSide primaryEdge(AppPalette p) =>
      isRoute ? BorderSide(color: p.text, width: 2) : BorderSide.none;

  /// Titles: serif at night and on paper, heavy sans on the route.
  TextStyle title(TextStyle base) => isRoute
      ? base.copyWith(fontFamily: null, fontWeight: FontWeight.w900)
      : base;

  @override
  AppStyle copyWith() => this;

  @override
  AppStyle lerp(AppStyle? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension StyleContext on BuildContext {
  /// The look of the theme in use. A widget built outside the app's theme gets the night style.
  AppStyle get appStyle =>
      Theme.of(this).extension<AppStyle>() ?? AppStyle.night;
}
