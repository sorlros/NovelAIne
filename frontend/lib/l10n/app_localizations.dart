import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'노벨에인'**
  String get appTitle;

  /// No description provided for @startNewAdventure.
  ///
  /// In ko, this message translates to:
  /// **'새로운 이야기 시작'**
  String get startNewAdventure;

  /// No description provided for @quickStart.
  ///
  /// In ko, this message translates to:
  /// **'빠른 시작'**
  String get quickStart;

  /// No description provided for @reviewSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 확인'**
  String get reviewSettings;

  /// No description provided for @myLibrary.
  ///
  /// In ko, this message translates to:
  /// **'내 서재'**
  String get myLibrary;

  /// No description provided for @myCreations.
  ///
  /// In ko, this message translates to:
  /// **'내 생성물'**
  String get myCreations;

  /// No description provided for @login.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get password;

  /// No description provided for @signup.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get signup;

  /// No description provided for @username.
  ///
  /// In ko, this message translates to:
  /// **'사용자 이름'**
  String get username;

  /// No description provided for @createdStories.
  ///
  /// In ko, this message translates to:
  /// **'창작 스토리'**
  String get createdStories;

  /// No description provided for @reading.
  ///
  /// In ko, this message translates to:
  /// **'읽는 중'**
  String get reading;

  /// No description provided for @detailedSettings.
  ///
  /// In ko, this message translates to:
  /// **'상세 설정 모드'**
  String get detailedSettings;

  /// No description provided for @characterSetup.
  ///
  /// In ko, this message translates to:
  /// **'주인공 설정'**
  String get characterSetup;

  /// No description provided for @whoIsTheProtagonist.
  ///
  /// In ko, this message translates to:
  /// **'이야기를 이끌어갈 주인공은 누구인가요?'**
  String get whoIsTheProtagonist;

  /// No description provided for @characterImageUpload.
  ///
  /// In ko, this message translates to:
  /// **'캐릭터 이미지 업로드 (선택)'**
  String get characterImageUpload;

  /// No description provided for @tapToSelectFromGallery.
  ///
  /// In ko, this message translates to:
  /// **'탭하여 갤러리에서 선택'**
  String get tapToSelectFromGallery;

  /// No description provided for @change.
  ///
  /// In ko, this message translates to:
  /// **'변경'**
  String get change;

  /// No description provided for @characterNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get characterNameLabel;

  /// No description provided for @characterNameHint.
  ///
  /// In ko, this message translates to:
  /// **'캐릭터의 이름을 입력하세요'**
  String get characterNameHint;

  /// No description provided for @appearanceLabel.
  ///
  /// In ko, this message translates to:
  /// **'외모 특징 (선택)'**
  String get appearanceLabel;

  /// No description provided for @appearanceHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 은발의 장발, 붉은 눈, 낡은 로브 (한글/영문 모두 가능)'**
  String get appearanceHint;

  /// No description provided for @personalityTraitsLabel.
  ///
  /// In ko, this message translates to:
  /// **'성격 (최대 3개)'**
  String get personalityTraitsLabel;

  /// No description provided for @prevStep.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get prevStep;

  /// No description provided for @reviewAndStart.
  ///
  /// In ko, this message translates to:
  /// **'검토 및 시작'**
  String get reviewAndStart;

  /// No description provided for @worldTheme.
  ///
  /// In ko, this message translates to:
  /// **'세계관 및 컨셉'**
  String get worldTheme;

  /// No description provided for @worldThemeDesc.
  ///
  /// In ko, this message translates to:
  /// **'당신의 이야기가 펼쳐질 배경을 설정하세요.'**
  String get worldThemeDesc;

  /// No description provided for @genreLabel.
  ///
  /// In ko, this message translates to:
  /// **'장르 (Genre)'**
  String get genreLabel;

  /// No description provided for @toneLabel.
  ///
  /// In ko, this message translates to:
  /// **'분위기 (Tone)'**
  String get toneLabel;

  /// No description provided for @toneSelect.
  ///
  /// In ko, this message translates to:
  /// **'분위기 선택'**
  String get toneSelect;

  /// No description provided for @startAdventureAuto.
  ///
  /// In ko, this message translates to:
  /// **'모험 시작 (AI 자동 생성)'**
  String get startAdventureAuto;

  /// No description provided for @nextProtagonistSetup.
  ///
  /// In ko, this message translates to:
  /// **'다음: 주인공 설정'**
  String get nextProtagonistSetup;

  /// No description provided for @clickToGenerateIllustration.
  ///
  /// In ko, this message translates to:
  /// **'클릭하여 씬 일러스트 생성'**
  String get clickToGenerateIllustration;

  /// No description provided for @whatActionToTake.
  ///
  /// In ko, this message translates to:
  /// **'어떤 행동을 하시겠습니까?'**
  String get whatActionToTake;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
