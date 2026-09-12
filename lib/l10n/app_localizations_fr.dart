// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Last Launcher';

  @override
  String get appTagline => 'Le dernier lanceur dont vous aurez besoin';

  @override
  String get settings => 'Paramètres';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get sectionHome => 'Accueil';

  @override
  String get sectionAppDrawer => 'Tiroir d\'applications';

  @override
  String get sectionTasks => 'Tâches';

  @override
  String get sectionModules => 'Modules';

  @override
  String get sectionSupport => 'Soutien';

  @override
  String get sectionAbout => 'À propos';

  @override
  String get sectionSearch => 'Recherche';

  @override
  String get sectionWork => 'Profil professionnel';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get hideStatusBar => 'Plein écran';

  @override
  String get hideStatusBarSubtitle =>
      'Masquer la barre d\'état et la navigation';

  @override
  String get showHints => 'Afficher les astuces';

  @override
  String get showHintsSubtitle =>
      'Afficher les astuces d\'utilisation dans toute l\'appli';

  @override
  String get fontSizeHome => 'Font size';

  @override
  String get fontSizeHomeSubtitle => 'Adjust font size of home screen apps';

  @override
  String get fontSizeShell => 'Shell font size';

  @override
  String get fontSizeShellSubtitle => 'Adjust font size of drawer and modules';

  @override
  String get fontFamilyTitle => 'Font family';

  @override
  String get fontAkkuratRegular => 'Akkurat Regular';

  @override
  String get fontRobotoMonoMedium => 'Roboto Mono Medium';

  @override
  String get fontRobotoMonoLight => 'Roboto Mono Light';

  @override
  String get fontRobotoMonoThin => 'Roboto Mono Thin';

  @override
  String get fontFamilyMono => 'JetBrains Mono';

  @override
  String get fontFamilyRaleway => 'Raleway Thin';

  @override
  String get fontFamilyLaconic => 'Laconic';

  @override
  String get fontFamilyOutfit => 'Outfit';

  @override
  String get hidePinnedApps => 'Masquer les apps épinglées';

  @override
  String get hidePinnedAppsSubtitle =>
      'Masquer les applications épinglées de la liste';

  @override
  String get includeHiddenInSearch => 'Inclure les masquées dans la recherche';

  @override
  String get includeHiddenInSearchSubtitle =>
      'La recherche correspond aussi aux applications masquées';

  @override
  String get matchOriginalName => 'Correspondre au nom d\'origine';

  @override
  String get matchOriginalNameSubtitle =>
      'Trouver les applications renommées par leur nom d\'origine';

  @override
  String get hiddenApps => 'Applications masquées';

  @override
  String get hiddenAppsNone => 'Aucune';

  @override
  String hiddenAppsCount(int count) {
    return '$count masquées';
  }

  @override
  String get noHiddenApps => 'Aucune application masquée';

  @override
  String get leftOfHome => 'Module gauche';

  @override
  String get panelNone => 'Aucun';

  @override
  String get homeAlignmentTitle => 'Home text alignment';

  @override
  String get alignmentLeft => 'Left';

  @override
  String get alignmentCenter => 'Center';

  @override
  String get alignmentRight => 'Right';

  @override
  String get lockLayout => 'Verrouiller la disposition';

  @override
  String get lockLayoutSubtitle =>
      'Désactiver l\'épinglage et l\'appui long sur l\'écran d\'accueil';

  @override
  String get doubleTapToSleep => 'Double appui pour verrouiller';

  @override
  String get doubleTapToSleepSubtitle =>
      'Nécessite le service d\'accessibilité activé dans les paramètres système';

  @override
  String get doubleTapToSleepDialogTitle => 'Turn on accessibility service';

  @override
  String get doubleTapToSleepDialog =>
      'This uses the AccessibilityService API to lock the screen when you double-tap. It does nothing else. You will be redirected to system settings to turn it on.';

  @override
  String get doubleTapToSleepPrivacy =>
      'We do not collect, store, or share any personal or sensitive user data through the AccessibilityService API.';

  @override
  String get setAsDefault => 'Définir comme app d\'accueil par défaut';

  @override
  String get setAsDefaultSubtitle => 'Ouvrir le sélecteur système';

  @override
  String get searchOnlyMode => 'Recherche uniquement';

  @override
  String get searchOnlyModeSubtitle =>
      'Masquer les noms d\'apps, rechercher pour lancer';

  @override
  String get autoShowKeyboard => 'Afficher le clavier';

  @override
  String get autoShowKeyboardAppsSubtitle =>
      'Ouvrir le clavier quand le tiroir s\'ouvre';

  @override
  String get autoShowKeyboardTasksSubtitle =>
      'Ouvrir le clavier quand les tâches s\'ouvrent';

  @override
  String get autoLaunchOnMatch => 'Lancement auto à la correspondance';

  @override
  String get autoLaunchOnMatchSubtitle =>
      'Lancer quand une seule app correspond';

  @override
  String get quickLaunchHints => 'Indicateurs de lancement rapide';

  @override
  String get quickLaunchHintsSubtitle =>
      'Mettre en évidence les caractères uniques les plus courts pour lancer';

  @override
  String get extraChar => 'Extra character';

  @override
  String get extraCharSubtitle =>
      'Require an extra character before auto-launch';

  @override
  String get panelTasks => 'les tâches';

  @override
  String get removeOnComplete => 'Supprimer à l\'achèvement';

  @override
  String get removeOnCompleteSubtitle =>
      'Supprimer les tâches quand elles sont terminées';

  @override
  String get clearCompletedDaily => 'Effacer les terminées chaque jour';

  @override
  String get clearCompletedDailySubtitle =>
      'Supprimer les tâches terminées à la fin de la journée';

  @override
  String get donate => 'Faire un don';

  @override
  String get donateSubtitle => 'Soutenir le développement de Last Launcher';

  @override
  String get rateApp => 'Noter Last Launcher';

  @override
  String get rateAppSubtitle => 'Laissez un avis sur le Play Store';

  @override
  String get sendFeedback => 'Envoyer un retour';

  @override
  String get sendFeedbackSubtitle => 'Envoyer un e-mail au développeur';

  @override
  String get help => 'Aide';

  @override
  String get helpSubtitle => 'Voir la page du projet';

  @override
  String get version => 'Version';

  @override
  String get license => 'Licence';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get aboutSubtitle => 'Version et licences';

  @override
  String hintSwipeRightFor(String module) {
    return 'Glissez à droite pour $module';
  }

  @override
  String hintSwipeLeftFor(String module) {
    return 'Glissez à gauche pour $module';
  }

  @override
  String get hintLongPress => 'Appui long pour les paramètres';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get emptyTaskList => 'Tapez pour ajouter une tâche';

  @override
  String get returnToAddTask => 'Appuyez sur Entrée pour ajouter une tâche';

  @override
  String get actionRename => 'Renommer';

  @override
  String get actionUnpin => 'Désépingler';

  @override
  String get actionPin => 'Épingler';

  @override
  String get actionPinFull => 'Plein';

  @override
  String get actionHide => 'Masquer';

  @override
  String get actionUnhide => 'Afficher';

  @override
  String get actionRemove => 'Supprimer';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionAppInfo => 'Infos sur l\'application';

  @override
  String get actionEnable => 'Activer';

  @override
  String get actionCreateFolder => 'Create folder';

  @override
  String get actionAddToFolder => 'Add to folder';

  @override
  String get actionRemoveFromFolder => 'Remove from folder';

  @override
  String get actionDeleteFolder => 'Delete folder';

  @override
  String get renameDialogTitle => 'Renommer';

  @override
  String get renameFolderDialogTitle => 'Rename folder';

  @override
  String get renameDialogCancel => 'Annuler';

  @override
  String get renameDialogSave => 'Enregistrer';

  @override
  String get selectAppsTitle => 'Select apps';

  @override
  String get showWorkAppDot => 'Point du profil professionnel';

  @override
  String get showWorkAppDotSubtitle =>
      'Afficher un petit point devant les applications du profil professionnel';

  @override
  String get showWorkAppDotOnHome =>
      'Afficher le point sur l\'écran d\'accueil';

  @override
  String get showWorkAppDotOnHomeSubtitle =>
      'Afficher le point du profil professionnel sur les applications épinglées de l\'écran d\'accueil';

  @override
  String get hidePersonalWhenWorkActive =>
      'Ne pas afficher les apps personnelles';

  @override
  String get hidePersonalWhenWorkActiveSubtitle =>
      'Les apps personnelles réapparaissent lorsque le profil professionnel est suspendu';

  @override
  String get homeScreenFull => 'L\'écran d\'accueil est plein';
}
