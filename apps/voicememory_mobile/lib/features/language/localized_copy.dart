import '../tomorrow_return/check_in_result_copy.dart';
import 'language_model.dart';

/// Returns user-facing copy for [key] in [languageCode].
///
/// Falls back to English when the language or the specific key is missing, so
/// callers can always rely on getting a usable string. Internal pattern
/// categories stay stable; only the surrounding guidance/buttons/results are
/// adapted.
String localized(String key, String languageCode) {
  final lang = isSupportedLanguage(languageCode) ? languageCode : 'en';
  final table = _copy[lang];
  final value = table?[key];
  if (value != null) return value;
  return _copy['en']?[key] ?? key;
}

/// Localized title for a first-session pattern category. English returns null
/// so callers keep the richer English title from the engine; other languages
/// return a safe, simple title.
String? localizedCategoryTitle(String categoryId, String languageCode) {
  if (languageCode == 'en') return null;
  return localized('category.$categoryId', languageCode);
}

/// Plain-language result headline for a completed check-in. English keeps the
/// richer English copy from [CheckInResultCopy]; other languages use a safe,
/// simple localized headline.
String localizedResultHeadline(String? optionId, String languageCode) {
  if (languageCode == 'en') return CheckInResultCopy.resultHeadline(optionId);
  return localized(_resultHeadlineKey(optionId), languageCode);
}

String _resultHeadlineKey(String? optionId) {
  switch (optionId) {
    case 'showed_up_again':
      return 'showedUpAgain';
    case 'lighter':
      return 'feltLighter';
    case 'heavier':
      return 'feltHeavier';
    case 'not_today':
      return 'changedToday';
    case 'none_fit':
      return 'noneFit';
    default:
      return 'loopClosed';
  }
}

/// Localized next check-in question template for a result option. English uses
/// the existing English templates; other languages reuse the result next-check
/// translations so the wording stays consistent.
String localizedCheckInQuestion(String? optionId, String languageCode) {
  if (languageCode == 'en') {
    return CheckInResultCopy.tomorrowsBetterQuestion(optionId);
  }
  return localized('result.${_resultHintFor(optionId)}.nextCheck', languageCode);
}

String _resultHintFor(String? optionId) {
  switch (optionId) {
    case 'lighter':
      return 'lighter';
    case 'heavier':
      return 'heavier';
    case 'not_today':
    case 'none_fit':
      return 'changed';
    case 'showed_up_again':
    default:
      return 'same';
  }
}

/// Localized answer-option label for the due check-in card. English keeps the
/// option's own label; other languages use a localized version.
String localizedOptionLabel(
  String optionId,
  String fallback,
  String languageCode,
) {
  if (languageCode == 'en') return fallback;
  switch (optionId) {
    case 'showed_up_again':
      return localized('option.showedUp', languageCode);
    case 'lighter':
      return localized('option.lighter', languageCode);
    case 'heavier':
      return localized('option.heavier', languageCode);
    case 'not_today':
      return localized('option.notToday', languageCode);
    case 'none_fit':
      return localized('option.noneFit', languageCode);
    default:
      return fallback;
  }
}

/// Localized result takeaway strings for the four core result types
/// (`same`, `lighter`, `heavier`, `changed`).
const Map<String, Map<String, String>> _copy = {
  'en': {
    'trySaying': 'Try saying:',
    'makeThisMoreUseful': 'Make this more useful',
    'earlyRead': 'Early read',
    'usefulTakeaway': 'Useful takeaway',
    'whatChanged': 'What changed',
    'whyUseful': 'Why this is useful',
    'nextCheck': 'Next check',
    'useThisTomorrow': 'Use this tomorrow',
    'tomorrowCheckSet': 'Tomorrow\u2019s check is set.',
    'showedUpAgain': 'It showed up again.',
    'feltLighter': 'It felt lighter today.',
    'feltHeavier': 'It felt heavier today.',
    'changedToday': 'Today was different.',
    'noneFit': 'None of those fit today.',
    'recordOneMoment': 'Record one moment',
    'addOneSentence': 'Add one sentence',
    'useItAnyway': 'Use it anyway',
    'exampleLabel': 'Example',
    'inputQualityCoachTitle': 'Make this more useful',
    'inputQualityCoachBody':
        'Add one clear moment so ArchiveMe can find a better pattern.',
    'addSentenceHint': 'Add one sentence\u2026',
    'firstPatternEarlyReadHint':
        'This may get sharper after one more clear moment.',
    'addAnotherMoment': 'Add another moment',
    'reflectionLanguageTitle': 'Reflection language',
    'useDetectedLanguage': 'Use detected language',
    'languageLabelPrefix': 'Language',
    'anotherPerspective': 'Another perspective',
    'showAnotherPerspective': 'Show another perspective',
    'showAnother': 'Show another',
    'useThisCheck': 'Use this check',
    'aKinderAngle': 'A kinder angle',
    'whyThisHelps': 'Why this helps',
    'showAnotherAngle': 'Show another angle',
    'kinderCaution': 'Use what fits. Leave what does not.',
    'needHelp': 'Need help?',
    'needHelpNow': 'Need help now?',
    'quickHelpSubtitle':
        'Pick what you need. ArchiveMe will give one next step.',
    'quickHelpWhatToRecord': 'I do not know what to record',
    'quickHelpAnotherPerspective': 'I need another perspective',
    'quickHelpPractical': 'I want something practical',
    'quickHelpHardOnMyself': 'I am being hard on myself',
    'quickHelpWhatToCheck': 'I want to know what to check next',
    'backToOptions': 'Back to options',
    'startRecording': 'Start recording',
    'showPerspective': 'Show perspective',
    'example': 'Example',
    'result.same.headline': 'This was a repeat, not a one-off.',
    'result.same.meaning': 'The same pattern showed up again today.',
    'result.same.why': 'Repeats are useful because they show where to look next.',
    'result.same.nextCheck': 'What happened right before it showed up?',
    'result.same.example': 'It started before I said yes.',
    'result.lighter.headline': 'Something made this lighter.',
    'result.lighter.meaning': 'Today this pattern took less from you.',
    'result.lighter.why': 'That is useful because it points to what helped.',
    'result.lighter.nextCheck': 'What helped make it lighter?',
    'result.lighter.example': 'It felt lighter after I paused.',
    'result.heavier.headline': 'Something made this heavier.',
    'result.heavier.meaning': 'Today this pattern took more from you.',
    'result.heavier.why': 'That is useful because it shows what needs attention.',
    'result.heavier.nextCheck': 'What made it heavier?',
    'result.heavier.example': 'It got heavier after I carried it alone.',
    'result.changed.headline': 'Today was different.',
    'result.changed.meaning': 'This was not just the same pattern repeating.',
    'result.changed.why': 'That is useful because change shows what can move.',
    'result.changed.nextCheck': 'What was different today?',
    'result.changed.example': 'It changed when I waited before answering.',
    'result.concrete.headline': 'Make this more concrete.',
    'result.concrete.meaning': 'The next check should point to one moment.',
    'result.concrete.why': 'One clear moment is easier to compare tomorrow.',
    'result.concrete.example': 'It showed up when I opened the message.',
    'result.concreteNextCheck': 'What exact moment did this show up?',
    'result.weakNudge': 'Add one more clear moment to make this more useful.',
    'category.responsibility': 'Taking responsibility before asking for help',
    'category.worry': 'Worry coming back when things go quiet',
    'category.relationship': 'A relationship that stays on your mind',
    'category.selfDoubt': 'Trying to prove you are enough',
    'category.avoidance': 'Putting off what matters',
    'category.burnout': 'Carrying more than feels light',
    'category.lighter': 'Something felt lighter today',
    'category.fallback': 'A moment worth noticing',
    'loopClosed': 'You closed the loop.',
    'todayHappened': 'Today, what happened?',
    'yesterdayChose': 'Yesterday you chose to check:',
    'option.showedUp': 'It showed up again',
    'option.lighter': 'It felt lighter',
    'option.heavier': 'It felt heavier',
    'option.notToday': 'Not today',
    'option.noneFit': 'None of these fit',
    'showOriginal': 'Show original',
    'hideOriginal': 'Hide original',
    'originalLabel': 'Original',
  },
  'es': {
    'trySaying': 'Prueba a decir:',
    'makeThisMoreUseful': 'Haz esto más útil',
    'earlyRead': 'Lectura inicial',
    'usefulTakeaway': 'Conclusión útil',
    'whatChanged': 'Qué cambió',
    'whyUseful': 'Por qué es útil',
    'nextCheck': 'Próxima revisión',
    'useThisTomorrow': 'Usar esto mañana',
    'tomorrowCheckSet': 'La revisión de mañana está lista.',
    'showedUpAgain': 'Apareció otra vez.',
    'feltLighter': 'Hoy se sintió más ligero.',
    'feltHeavier': 'Hoy se sintió más pesado.',
    'changedToday': 'Hoy fue diferente.',
    'noneFit': 'Ninguno encaja hoy.',
    'recordOneMoment': 'Graba un momento',
    'addOneSentence': 'Agrega una frase',
    'useItAnyway': 'Usarlo de todos modos',
    'exampleLabel': 'Ejemplo',
    'inputQualityCoachTitle': 'Haz esto más útil',
    'inputQualityCoachBody':
        'Agrega un momento claro para encontrar un mejor patrón.',
    'addSentenceHint': 'Agrega una frase\u2026',
    'firstPatternEarlyReadHint':
        'Esto puede aclararse con un momento claro más.',
    'addAnotherMoment': 'Agrega otro momento',
    'reflectionLanguageTitle': 'Idioma de la reflexión',
    'useDetectedLanguage': 'Usar el idioma detectado',
    'languageLabelPrefix': 'Idioma',
    'anotherPerspective': 'Otra perspectiva',
    'showAnotherPerspective': 'Mostrar otra perspectiva',
    'showAnother': 'Mostrar otra',
    'useThisCheck': 'Usar esta revisión',
    'aKinderAngle': 'Una mirada más amable',
    'whyThisHelps': 'Por qué ayuda',
    'showAnotherAngle': 'Mostrar otra mirada',
    'kinderCaution': 'Usa lo que encaje. Deja lo que no.',
    'needHelp': '¿Necesitas ayuda?',
    'needHelpNow': '¿Necesitas ayuda ahora?',
    'quickHelpSubtitle':
        'Elige lo que necesitas. ArchiveMe te dará un paso siguiente.',
    'quickHelpWhatToRecord': 'No sé qué grabar',
    'quickHelpAnotherPerspective': 'Necesito otra perspectiva',
    'quickHelpPractical': 'Quiero algo práctico',
    'quickHelpHardOnMyself': 'Estoy siendo duro conmigo mismo',
    'quickHelpWhatToCheck': 'Quiero saber qué revisar después',
    'backToOptions': 'Volver a las opciones',
    'startRecording': 'Empezar a grabar',
    'showPerspective': 'Mostrar perspectiva',
    'example': 'Ejemplo',
    'result.same.headline': 'Esto se repitió, no fue algo aislado.',
    'result.same.meaning': 'El mismo patrón apareció otra vez hoy.',
    'result.same.why': 'Las repeticiones muestran dónde mirar después.',
    'result.same.nextCheck': '¿Qué pasó justo antes de que apareciera?',
    'result.same.example': 'Empezó antes de que dijera que sí.',
    'result.lighter.headline': 'Algo hizo esto más ligero.',
    'result.lighter.meaning': 'Hoy este patrón te quitó menos.',
    'result.lighter.why': 'Es útil porque señala qué ayudó.',
    'result.lighter.nextCheck': '¿Qué ayudó a hacerlo más ligero?',
    'result.lighter.example': 'Se sintió más ligero después de una pausa.',
    'result.heavier.headline': 'Algo hizo esto más pesado.',
    'result.heavier.meaning': 'Hoy este patrón te quitó más.',
    'result.heavier.why': 'Es útil porque muestra qué necesita atención.',
    'result.heavier.nextCheck': '¿Qué lo hizo más pesado?',
    'result.heavier.example': 'Se hizo más pesado cuando lo cargué solo.',
    'result.changed.headline': 'Hoy fue diferente.',
    'result.changed.meaning': 'No fue solo el mismo patrón repitiéndose.',
    'result.changed.why': 'Es útil porque el cambio muestra qué puede moverse.',
    'result.changed.nextCheck': '¿Qué fue diferente hoy?',
    'result.changed.example': 'Cambió cuando esperé antes de responder.',
    'result.concrete.headline': 'Hazlo más concreto.',
    'result.concrete.meaning': 'La próxima revisión debe señalar un momento.',
    'result.concrete.why': 'Un momento claro es más fácil de comparar mañana.',
    'result.concrete.example': 'Apareció cuando abrí el mensaje.',
    'result.concreteNextCheck': '¿En qué momento exacto apareció esto?',
    'result.weakNudge': 'Agrega un momento claro más para que sea más útil.',
    'category.responsibility': 'Asumir la responsabilidad antes de pedir ayuda',
    'category.worry': 'La preocupación que vuelve cuando todo se calma',
    'category.relationship': 'Una relación que sigue en tu mente',
    'category.selfDoubt': 'Tratar de demostrar que eres suficiente',
    'category.avoidance': 'Posponer lo que importa',
    'category.burnout': 'Cargar más de lo que se siente ligero',
    'category.lighter': 'Algo se sintió más ligero hoy',
    'category.fallback': 'Un momento que vale la pena notar',
    'loopClosed': 'Cerraste el ciclo.',
    'todayHappened': 'Hoy, ¿qué pasó?',
    'yesterdayChose': 'Ayer elegiste revisar:',
    'option.showedUp': 'Apareció otra vez',
    'option.lighter': 'Se sintió más ligero',
    'option.heavier': 'Se sintió más pesado',
    'option.notToday': 'Hoy no',
    'option.noneFit': 'Ninguno encaja',
    'showOriginal': 'Mostrar original',
    'hideOriginal': 'Ocultar original',
    'originalLabel': 'Original',
  },
  'fr': {
    'trySaying': 'Essaie de dire :',
    'makeThisMoreUseful': 'Rends ceci plus utile',
    'earlyRead': 'Première lecture',
    'usefulTakeaway': 'Point utile',
    'whatChanged': 'Ce qui a changé',
    'whyUseful': 'Pourquoi c\u2019est utile',
    'nextCheck': 'Prochaine vérification',
    'useThisTomorrow': 'Utiliser ceci demain',
    'tomorrowCheckSet': 'La vérification de demain est prête.',
    'showedUpAgain': 'C\u2019est revenu.',
    'feltLighter': 'Aujourd\u2019hui c\u2019était plus léger.',
    'feltHeavier': 'Aujourd\u2019hui c\u2019était plus lourd.',
    'changedToday': 'Aujourd\u2019hui c\u2019était différent.',
    'noneFit': 'Aucun ne convient aujourd\u2019hui.',
    'recordOneMoment': 'Enregistre un moment',
    'addOneSentence': 'Ajoute une phrase',
    'useItAnyway': 'L\u2019utiliser quand même',
    'exampleLabel': 'Exemple',
    'inputQualityCoachTitle': 'Rends ceci plus utile',
    'inputQualityCoachBody':
        'Ajoute un moment clair pour trouver un meilleur schéma.',
    'addSentenceHint': 'Ajoute une phrase\u2026',
    'firstPatternEarlyReadHint':
        'Cela peut s\u2019affiner avec un moment clair de plus.',
    'addAnotherMoment': 'Ajoute un autre moment',
    'reflectionLanguageTitle': 'Langue de la réflexion',
    'useDetectedLanguage': 'Utiliser la langue détectée',
    'languageLabelPrefix': 'Langue',
    'anotherPerspective': 'Une autre perspective',
    'showAnotherPerspective': 'Voir une autre perspective',
    'showAnother': 'Voir une autre',
    'useThisCheck': 'Utiliser cette vérification',
    'aKinderAngle': 'Un regard plus bienveillant',
    'whyThisHelps': 'Pourquoi cela aide',
    'showAnotherAngle': 'Voir un autre regard',
    'kinderCaution': 'Garde ce qui convient. Laisse le reste.',
    'needHelp': 'Besoin d\'aide ?',
    'needHelpNow': 'Besoin d\'aide maintenant ?',
    'quickHelpSubtitle':
        'Choisis ce dont tu as besoin. ArchiveMe propose une étape.',
    'quickHelpWhatToRecord': 'Je ne sais pas quoi enregistrer',
    'quickHelpAnotherPerspective': 'J\'ai besoin d\'une autre perspective',
    'quickHelpPractical': 'Je veux quelque chose de pratique',
    'quickHelpHardOnMyself': 'Je suis dur envers moi-même',
    'quickHelpWhatToCheck': 'Je veux savoir quoi vérifier ensuite',
    'backToOptions': 'Retour aux options',
    'startRecording': 'Commencer l\'enregistrement',
    'showPerspective': 'Voir la perspective',
    'example': 'Exemple',
    'result.same.headline': 'C\u2019était une répétition, pas un cas isolé.',
    'result.same.meaning': 'Le même schéma est revenu aujourd\u2019hui.',
    'result.same.why': 'Les répétitions montrent où regarder ensuite.',
    'result.same.nextCheck': 'Que s\u2019est-il passé juste avant ?',
    'result.same.example': 'Ça a commencé avant que je dise oui.',
    'result.lighter.headline': 'Quelque chose a rendu ceci plus léger.',
    'result.lighter.meaning': 'Aujourd\u2019hui ce schéma a pris moins de toi.',
    'result.lighter.why': 'C\u2019est utile car cela montre ce qui a aidé.',
    'result.lighter.nextCheck': 'Qu\u2019est-ce qui l\u2019a rendu plus léger ?',
    'result.lighter.example': 'C\u2019était plus léger après une pause.',
    'result.heavier.headline': 'Quelque chose a rendu ceci plus lourd.',
    'result.heavier.meaning': 'Aujourd\u2019hui ce schéma a pris plus de toi.',
    'result.heavier.why': 'C\u2019est utile car cela montre ce qui demande attention.',
    'result.heavier.nextCheck': 'Qu\u2019est-ce qui l\u2019a rendu plus lourd ?',
    'result.heavier.example': 'C\u2019est devenu plus lourd quand je l\u2019ai porté seul.',
    'result.changed.headline': 'Aujourd\u2019hui c\u2019était différent.',
    'result.changed.meaning': 'Ce n\u2019était pas juste le même schéma.',
    'result.changed.why': 'C\u2019est utile car le changement montre ce qui peut bouger.',
    'result.changed.nextCheck': 'Qu\u2019est-ce qui était différent aujourd\u2019hui ?',
    'result.changed.example': 'Ça a changé quand j\u2019ai attendu avant de répondre.',
    'result.concrete.headline': 'Rends ceci plus concret.',
    'result.concrete.meaning': 'La prochaine vérification doit viser un moment.',
    'result.concrete.why': 'Un moment clair est plus facile à comparer demain.',
    'result.concrete.example': 'C\u2019est arrivé quand j\u2019ai ouvert le message.',
    'result.concreteNextCheck': 'À quel moment précis est-ce arrivé ?',
    'result.weakNudge': 'Ajoute un moment clair de plus pour rendre ceci plus utile.',
    'category.responsibility': 'Prendre la responsabilité avant de demander de l\u2019aide',
    'category.worry': 'L\u2019inquiétude qui revient dans le calme',
    'category.relationship': 'Une relation qui reste dans ta tête',
    'category.selfDoubt': 'Essayer de prouver que tu suffis',
    'category.avoidance': 'Remettre à plus tard ce qui compte',
    'category.burnout': 'Porter plus que ce qui est léger',
    'category.lighter': 'Quelque chose était plus léger aujourd\u2019hui',
    'category.fallback': 'Un moment à remarquer',
    'loopClosed': 'Tu as bouclé la boucle.',
    'todayHappened': 'Aujourd\u2019hui, que s\u2019est-il passé ?',
    'yesterdayChose': 'Hier tu as choisi de vérifier :',
    'option.showedUp': 'C\u2019est revenu',
    'option.lighter': 'C\u2019était plus léger',
    'option.heavier': 'C\u2019était plus lourd',
    'option.notToday': 'Pas aujourd\u2019hui',
    'option.noneFit': 'Aucun ne convient',
    'showOriginal': 'Voir l\u2019original',
    'hideOriginal': 'Masquer l\u2019original',
    'originalLabel': 'Original',
  },
  'hi': {
    'trySaying': 'ऐसा कहकर देखें:',
    'makeThisMoreUseful': 'इसे और उपयोगी बनाएं',
    'earlyRead': 'शुरुआती समझ',
    'usefulTakeaway': 'उपयोगी बात',
    'whatChanged': 'क्या बदला',
    'whyUseful': 'यह क्यों उपयोगी है',
    'nextCheck': 'अगली जांच',
    'useThisTomorrow': 'इसे कल उपयोग करें',
    'tomorrowCheckSet': 'कल की जांच तय हो गई।',
    'showedUpAgain': 'यह फिर सामने आया।',
    'feltLighter': 'आज यह हल्का लगा।',
    'feltHeavier': 'आज यह भारी लगा।',
    'changedToday': 'आज कुछ अलग था।',
    'noneFit': 'आज इनमें से कोई सही नहीं बैठा।',
    'recordOneMoment': 'एक पल रिकॉर्ड करें',
    'addOneSentence': 'एक वाक्य जोड़ें',
    'useItAnyway': 'फिर भी उपयोग करें',
    'exampleLabel': 'उदाहरण',
    'inputQualityCoachTitle': 'इसे और उपयोगी बनाएं',
    'inputQualityCoachBody':
        'एक साफ़ पल जोड़ें ताकि बेहतर पैटर्न मिल सके।',
    'addSentenceHint': 'एक वाक्य जोड़ें\u2026',
    'firstPatternEarlyReadHint':
        'एक और साफ़ पल के बाद यह और स्पष्ट हो सकता है।',
    'addAnotherMoment': 'एक और पल जोड़ें',
    'reflectionLanguageTitle': 'विचार की भाषा',
    'useDetectedLanguage': 'पहचानी गई भाषा का उपयोग करें',
    'languageLabelPrefix': 'भाषा',
    'anotherPerspective': 'एक और नज़रिया',
    'showAnotherPerspective': 'एक और नज़रिया देखें',
    'showAnother': 'एक और देखें',
    'useThisCheck': 'यह जाँच इस्तेमाल करें',
    'aKinderAngle': 'एक नरम नज़रिया',
    'whyThisHelps': 'यह कैसे मदद करता है',
    'showAnotherAngle': 'एक और नज़रिया देखें',
    'kinderCaution': 'जो सही लगे रखें। जो नहीं, छोड़ दें।',
    'needHelp': 'मदद चाहिए?',
    'needHelpNow': 'अभी मदद चाहिए?',
    'quickHelpSubtitle': 'जो चाहिए चुनें। ArchiveMe एक अगला कदम देगा।',
    'quickHelpWhatToRecord': 'मुझे नहीं पता क्या रिकॉर्ड करूँ',
    'quickHelpAnotherPerspective': 'मुझे एक और नज़रिया चाहिए',
    'quickHelpPractical': 'मुझे कुछ व्यावहारिक चाहिए',
    'quickHelpHardOnMyself': 'मैं खुद पर सख्त हो रहा हूँ',
    'quickHelpWhatToCheck': 'मैं जानना चाहता हूँ आगे क्या जाँचूँ',
    'backToOptions': 'विकल्पों पर वापस',
    'startRecording': 'रिकॉर्ड करना शुरू करें',
    'showPerspective': 'नज़रिया दिखाएँ',
    'example': 'उदाहरण',
    'result.same.headline': 'यह दोहराव था, एक बार की बात नहीं।',
    'result.same.meaning': 'आज वही पैटर्न फिर सामने आया।',
    'result.same.why': 'दोहराव बताते हैं कि आगे कहां देखना है।',
    'result.same.nextCheck': 'इसके सामने आने से ठीक पहले क्या हुआ?',
    'result.same.example': 'हां कहने से पहले यह शुरू हुआ।',
    'result.lighter.headline': 'किसी चीज़ ने इसे हल्का बनाया।',
    'result.lighter.meaning': 'आज इस पैटर्न ने आपसे कम लिया।',
    'result.lighter.why': 'यह उपयोगी है क्योंकि यह बताता है कि किसने मदद की।',
    'result.lighter.nextCheck': 'इसे हल्का बनाने में किसने मदद की?',
    'result.lighter.example': 'रुककर सोचने के बाद यह हल्का लगा।',
    'result.heavier.headline': 'किसी चीज़ ने इसे भारी बनाया।',
    'result.heavier.meaning': 'आज इस पैटर्न ने आपसे अधिक लिया।',
    'result.heavier.why': 'यह उपयोगी है क्योंकि यह बताता है कि किस पर ध्यान दें।',
    'result.heavier.nextCheck': 'इसे भारी किसने बनाया?',
    'result.heavier.example': 'अकेले संभालने पर यह भारी हो गया।',
    'result.changed.headline': 'आज कुछ अलग था।',
    'result.changed.meaning': 'यह सिर्फ़ वही पैटर्न दोहराना नहीं था।',
    'result.changed.why': 'यह उपयोगी है क्योंकि बदलाव बताता है कि क्या बदल सकता है।',
    'result.changed.nextCheck': 'आज क्या अलग था?',
    'result.changed.example': 'जवाब देने से पहले रुकने पर यह बदल गया।',
    'result.concrete.headline': 'इसे और ठोस बनाएं।',
    'result.concrete.meaning': 'अगली जांच एक पल पर केंद्रित होनी चाहिए।',
    'result.concrete.why': 'एक साफ़ पल को कल तुलना करना आसान है।',
    'result.concrete.example': 'जब मैंने संदेश खोला तब यह सामने आया।',
    'result.concreteNextCheck': 'यह किस ठीक पल पर सामने आया?',
    'result.weakNudge': 'इसे और उपयोगी बनाने के लिए एक और साफ़ पल जोड़ें।',
    'category.responsibility': 'मदद मांगने से पहले ज़िम्मेदारी लेना',
    'category.worry': 'शांति में लौट आने वाली चिंता',
    'category.relationship': 'एक रिश्ता जो मन में बना रहता है',
    'category.selfDoubt': 'खुद को साबित करने की कोशिश',
    'category.avoidance': 'ज़रूरी काम को टालना',
    'category.burnout': 'हल्के से ज़्यादा बोझ उठाना',
    'category.lighter': 'आज कुछ हल्का लगा',
    'category.fallback': 'ध्यान देने लायक एक पल',
    'loopClosed': 'आपने लूप पूरा किया।',
    'todayHappened': 'आज क्या हुआ?',
    'yesterdayChose': 'कल आपने जांचने के लिए चुना:',
    'option.showedUp': 'यह फिर सामने आया',
    'option.lighter': 'यह हल्का लगा',
    'option.heavier': 'यह भारी लगा',
    'option.notToday': 'आज नहीं',
    'option.noneFit': 'इनमें से कोई नहीं',
    'showOriginal': 'मूल दिखाएं',
    'hideOriginal': 'मूल छिपाएं',
    'originalLabel': 'मूल',
  },
  'gu': {
    'trySaying': 'આમ કહીને જુઓ:',
    'makeThisMoreUseful': 'આને વધુ ઉપયોગી બનાવો',
    'earlyRead': 'શરૂઆતી સમજ',
    'usefulTakeaway': 'ઉપયોગી વાત',
    'whatChanged': 'શું બદલાયું',
    'whyUseful': 'આ શા માટે ઉપયોગી છે',
    'nextCheck': 'આગલી તપાસ',
    'useThisTomorrow': 'આને કાલે વાપરો',
    'tomorrowCheckSet': 'કાલની તપાસ નક્કી થઈ.',
    'showedUpAgain': 'આ ફરી દેખાયું.',
    'feltLighter': 'આજે આ હળવું લાગ્યું.',
    'feltHeavier': 'આજે આ ભારે લાગ્યું.',
    'changedToday': 'આજે કંઈક અલગ હતું.',
    'noneFit': 'આજે આમાંથી કોઈ બંધબેસતું નથી.',
    'recordOneMoment': 'એક ક્ષણ રેકોર્ડ કરો',
    'addOneSentence': 'એક વાક્ય ઉમેરો',
    'useItAnyway': 'તેમ છતાં વાપરો',
    'exampleLabel': 'ઉદાહરણ',
    'inputQualityCoachTitle': 'આને વધુ ઉપયોગી બનાવો',
    'inputQualityCoachBody':
        'એક સ્પષ્ટ ક્ષણ ઉમેરો જેથી વધુ સારી પેટર્ન મળે.',
    'addSentenceHint': 'એક વાક્ય ઉમેરો\u2026',
    'firstPatternEarlyReadHint':
        'એક વધુ સ્પષ્ટ ક્ષણ પછી આ વધુ સ્પષ્ટ થઈ શકે.',
    'addAnotherMoment': 'બીજી એક ક્ષણ ઉમેરો',
    'reflectionLanguageTitle': 'વિચારની ભાષા',
    'useDetectedLanguage': 'શોધાયેલી ભાષા વાપરો',
    'languageLabelPrefix': 'ભાષા',
    'anotherPerspective': 'બીજો દૃષ્ટિકોણ',
    'showAnotherPerspective': 'બીજો દૃષ્ટિકોણ બતાવો',
    'showAnother': 'બીજો બતાવો',
    'useThisCheck': 'આ ચેક વાપરો',
    'aKinderAngle': 'એક નરમ દૃષ્ટિકોણ',
    'whyThisHelps': 'આ કેવી રીતે મદદ કરે છે',
    'showAnotherAngle': 'બીજો દૃષ્ટિકોણ બતાવો',
    'kinderCaution': 'જે યોગ્ય લાગે તે રાખો. બાકીનું છોડી દો.',
    'needHelp': 'મદદ જોઈએ?',
    'needHelpNow': 'હમણાં મદદ જોઈએ?',
    'quickHelpSubtitle': 'જે જોઈએ તે પસંદ કરો. ArchiveMe એક આગળનું પગલું આપશે.',
    'quickHelpWhatToRecord': 'મને ખબર નથી શું રેકોર્ડ કરું',
    'quickHelpAnotherPerspective': 'મને બીજો દૃષ્ટિકોણ જોઈએ',
    'quickHelpPractical': 'મને કંઈક વ્યવહારુ જોઈએ',
    'quickHelpHardOnMyself': 'હું મારી જાત પર કઠોર છું',
    'quickHelpWhatToCheck': 'મારે જાણવું છે આગળ શું તપાસું',
    'backToOptions': 'વિકલ્પો પર પાછા',
    'startRecording': 'રેકોર્ડ કરવાનું શરૂ કરો',
    'showPerspective': 'દૃષ્ટિકોણ બતાવો',
    'example': 'ઉદાહરણ',
    'result.same.headline': 'આ પુનરાવર્તન હતું, એક વખતની વાત નહીં.',
    'result.same.meaning': 'આજે એ જ પેટર્ન ફરી દેખાઈ.',
    'result.same.why': 'પુનરાવર્તન બતાવે છે કે આગળ ક્યાં જોવું.',
    'result.same.nextCheck': 'આ દેખાય તે પહેલાં શું થયું?',
    'result.same.example': 'હા કહ્યા પહેલાં આ શરૂ થયું.',
    'result.lighter.headline': 'કોઈ વસ્તુએ આને હળવું બનાવ્યું.',
    'result.lighter.meaning': 'આજે આ પેટર્ને તમારી પાસેથી ઓછું લીધું.',
    'result.lighter.why': 'આ ઉપયોગી છે કેમ કે તે બતાવે છે કે શું મદદરૂપ થયું.',
    'result.lighter.nextCheck': 'આને હળવું બનાવવામાં શું મદદરૂપ થયું?',
    'result.lighter.example': 'થોભ્યા પછી આ હળવું લાગ્યું.',
    'result.heavier.headline': 'કોઈ વસ્તુએ આને ભારે બનાવ્યું.',
    'result.heavier.meaning': 'આજે આ પેટર્ને તમારી પાસેથી વધુ લીધું.',
    'result.heavier.why': 'આ ઉપયોગી છે કેમ કે તે બતાવે છે કે શેના પર ધ્યાન આપવું.',
    'result.heavier.nextCheck': 'આને ભારે શેણે બનાવ્યું?',
    'result.heavier.example': 'એકલા ઉપાડ્યું ત્યારે આ ભારે થયું.',
    'result.changed.headline': 'આજે કંઈક અલગ હતું.',
    'result.changed.meaning': 'આ ફક્ત એ જ પેટર્નનું પુનરાવર્તન નહોતું.',
    'result.changed.why': 'આ ઉપયોગી છે કેમ કે બદલાવ બતાવે છે કે શું બદલાઈ શકે.',
    'result.changed.nextCheck': 'આજે શું અલગ હતું?',
    'result.changed.example': 'જવાબ આપતા પહેલાં થોભ્યો ત્યારે આ બદલાયું.',
    'result.concrete.headline': 'આને વધુ સ્પષ્ટ બનાવો.',
    'result.concrete.meaning': 'આગલી તપાસ એક ક્ષણ પર કેન્દ્રિત હોવી જોઈએ.',
    'result.concrete.why': 'એક સ્પષ્ટ ક્ષણ કાલે સરખાવવી સહેલી છે.',
    'result.concrete.example': 'મેં સંદેશ ખોલ્યો ત્યારે આ દેખાયું.',
    'result.concreteNextCheck': 'આ કઈ ચોક્કસ ક્ષણે દેખાયું?',
    'result.weakNudge': 'આને વધુ ઉપયોગી બનાવવા એક વધુ સ્પષ્ટ ક્ષણ ઉમેરો.',
    'category.responsibility': 'મદદ માગતા પહેલાં જવાબદારી લેવી',
    'category.worry': 'શાંતિ આવે ત્યારે પાછી આવતી ચિંતા',
    'category.relationship': 'મનમાં રહેતો એક સંબંધ',
    'category.selfDoubt': 'તમે પૂરતા છો તે સાબિત કરવાનો પ્રયાસ',
    'category.avoidance': 'મહત્ત્વનું કામ ટાળવું',
    'category.burnout': 'હળવા કરતાં વધુ બોજ ઉપાડવો',
    'category.lighter': 'આજે કંઈક હળવું લાગ્યું',
    'category.fallback': 'ધ્યાન આપવા જેવી એક ક્ષણ',
    'loopClosed': 'તમે લૂપ પૂરો કર્યો.',
    'todayHappened': 'આજે શું થયું?',
    'yesterdayChose': 'ગઈકાલે તમે તપાસવાનું પસંદ કર્યું:',
    'option.showedUp': 'આ ફરી દેખાયું',
    'option.lighter': 'આ હળવું લાગ્યું',
    'option.heavier': 'આ ભારે લાગ્યું',
    'option.notToday': 'આજે નહીં',
    'option.noneFit': 'આમાંથી કોઈ નહીં',
    'showOriginal': 'મૂળ બતાવો',
    'hideOriginal': 'મૂળ છુપાવો',
    'originalLabel': 'મૂળ',
  },
};
