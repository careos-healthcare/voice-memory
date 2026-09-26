// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get accountAuthCodeBody =>
      'Introduce el código de inicio de sesión que acabamos de enviarte.';

  @override
  String get accountAuthCodeCta => 'Continuar';

  @override
  String get accountAuthCodeLabel => 'Código';

  @override
  String get accountAuthCodeSent => 'Código enviado — revisa tu correo.';

  @override
  String get accountAuthCodeTitle => 'Revisa tu correo';

  @override
  String get accountAuthContinueWithoutAccount => 'Continuar sin cuenta';

  @override
  String get accountAuthCreateBody =>
      'Thoughtprint es un diario de voz privado que convierte tus pensamientos hablados en una historia de vida unificada e inteligencia personal profunda. Crea una cuenta para restaurar el acceso más tarde.';

  @override
  String get accountAuthCreateCta => 'Crear cuenta';

  @override
  String get accountAuthCreateTitle => 'Crea tu cuenta de Thoughtprint';

  @override
  String get accountAuthEmailLabel => 'Correo electrónico';

  @override
  String get accountAuthInvalidCode => 'Introduce el código de tu correo.';

  @override
  String get accountAuthInvalidEmail =>
      'Introduce una dirección de correo válida.';

  @override
  String get accountAuthPrivacyLine =>
      'Tu archivo permanece privado. No incluimos tus grabaciones en analíticas.';

  @override
  String get accountAuthResendCode => 'Reenviar código';

  @override
  String get accountAuthSendCodeFailed => 'No se pudo enviar el código.';

  @override
  String get accountAuthSignInCta => 'Iniciar sesión';

  @override
  String get accountAuthSignInFailed =>
      'Error al iniciar sesión. Comprueba el código e inténtalo de nuevo.';

  @override
  String get accountAuthSignInTitle => 'Inicia sesión en Thoughtprint';

  @override
  String get accountAuthSignOut => 'Cerrar sesión';

  @override
  String get accountAuthSignOutKeepsArchive =>
      'Al cerrar sesión, tus grabaciones permanecen en este dispositivo.';

  @override
  String get accountAuthTimingNote =>
      'Thoughtprint es un diario de voz privado que convierte tus pensamientos hablados en una historia de vida unificada e inteligencia personal profunda. Puedes usarlo localmente sin cuenta.';

  @override
  String get accountScreenLabel => 'Pantalla de cuenta';

  @override
  String get appTitle => 'Thoughtprint';

  @override
  String get archiveAddMoment => 'Añadir un momento';

  @override
  String archiveCurrentObservation(String statement) {
    return 'Tu observación actual más clara es: $statement';
  }

  @override
  String archiveEvidenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count momentos guardados disponibles para comparar.',
      one: '1 momento guardado disponible para comparar.',
    );
    return '$_temp0';
  }

  @override
  String get archiveEvidenceTitle => 'Evidencia';

  @override
  String get archiveNeedsComparison =>
      'Añade otro momento para que Thoughtprint pueda comparar lo que cambió.';

  @override
  String get archiveNeedsSupportedMoments =>
      'Thoughtprint necesita al menos dos momentos compatibles antes de explicar un patrón.';

  @override
  String get archiveNextMomentGuidance =>
      'Graba o escribe un momento específico. Una segunda observación compatible hace visible el cambio.';

  @override
  String get archiveNextStepsTitle => 'Próximos pasos';

  @override
  String get archiveScreenLabel => 'Pantalla de archivo';

  @override
  String get archiveTitle => 'Archivo';

  @override
  String get archiveWhatChangedTitle => '¿Qué cambió?';

  @override
  String get archiveWhyTitle => '¿Por qué?';

  @override
  String get authTriggerArchiveChangedReturnCta => 'Proteger archivo';

  @override
  String get authTriggerArchiveChangedReturnLead =>
      'Inicia sesión para proteger tu archivo después de que pueda haber cambiado.';

  @override
  String get authTriggerArchiveChangedReturnTitle =>
      'Mira en qué cree tu archivo ahora';

  @override
  String get authTriggerCrossDeviceCta => 'Inicia sesión para continuar';

  @override
  String get authTriggerCrossDeviceLead =>
      'Inicia sesión para retomar tu archivo donde lo dejaste.';

  @override
  String get authTriggerCrossDeviceTitle => 'Continuar en otro dispositivo';

  @override
  String get authTriggerExportCta => 'Inicia sesión para exportar';

  @override
  String get authTriggerExportLead =>
      'Inicia sesión antes de exportar tu archivo.';

  @override
  String get authTriggerExportTitle => 'Exportar con una cuenta protegida';

  @override
  String get authTriggerFirstWorkingBeliefCta => 'Proteger esta creencia';

  @override
  String get authTriggerFirstWorkingBeliefLead =>
      'Inicia sesión para proteger la creencia que está formando tu archivo.';

  @override
  String get authTriggerFirstWorkingBeliefTitle =>
      'Tu archivo tiene una creencia en formación';

  @override
  String get authTriggerKeepTrackingProCta => 'Inicia sesión para continuar';

  @override
  String get authTriggerKeepTrackingProLead =>
      'Inicia sesión antes de actualizar para que tu archivo siga respaldado.';

  @override
  String get authTriggerKeepTrackingProTitle => 'Sigue registrando con Pro';

  @override
  String get authTriggerProPaywallCta => 'Continuar con correo';

  @override
  String get authTriggerProPaywallLead =>
      'La compra necesita una cuenta para proteger tu archivo.';

  @override
  String get authTriggerProPaywallTitle => 'Inicia sesión para Pro';

  @override
  String get authTriggerProtectArchiveCta => 'Proteger con correo';

  @override
  String get authTriggerProtectArchiveLead =>
      'Inicia sesión con correo para cifrar una copia de seguridad de lo que construiste en este dispositivo.';

  @override
  String get authTriggerProtectArchiveTitle => 'Proteger este archivo';

  @override
  String get authTriggerSyncArchiveCta => 'Inicia sesión para sincronizar';

  @override
  String get authTriggerSyncArchiveLead =>
      'El inicio de sesión con correo habilita la sincronización cifrada en este dispositivo.';

  @override
  String get authTriggerSyncArchiveTitle => 'Respaldar tu archivo';

  @override
  String get changesScreenLabel => 'Pantalla de cambios';

  @override
  String coachingConfidence(int percentage) {
    return '$percentage% de confianza';
  }

  @override
  String coachingConfidenceSemantics(int percentage) {
    return 'Confianza $percentage por ciento';
  }

  @override
  String get coachingInsightHint =>
      'Reflexión generada por IA basada en evidencia reciente del diario.';

  @override
  String coachingInsightSemantics(
    String category,
    int percentage,
    String content,
  ) {
    return '$category. Confianza $percentage por ciento. $content';
  }

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get dataPortabilityTrustFooter =>
      'Exportado desde tu dispositivo. Tu propia voz — no terapia ni diagnóstico.';

  @override
  String get exportJsonCta => 'Exportar JSON';

  @override
  String get exportPortabilityBusy => 'Preparando exportación…';

  @override
  String get exportPortabilityCta => 'Descargar archivo completo (ZIP)';

  @override
  String get exportPortabilityFailed =>
      'Error al exportar. Inténtalo de nuevo.';

  @override
  String get exportPortabilitySuccess =>
      'Exportación lista — comparte o guarda el archivo ZIP.';

  @override
  String get exportScreenLead =>
      'Descarga una copia portable de tu archivo para respaldo o migración.';

  @override
  String get exportScreenTitle => 'Exportar';

  @override
  String get memoryGraphActionBarHint =>
      'Desliza horizontalmente para explorar más acciones del gráfico.';

  @override
  String get memoryGraphActionBarLabel => 'Acciones del gráfico de memoria';

  @override
  String get memoryGraphActionButtonHint =>
      'Toca dos veces para activar esta acción del gráfico.';

  @override
  String get memoryGraphClosePreview => 'Cerrar vista previa';

  @override
  String get memoryGraphCloseRewind => 'Cerrar retroceso';

  @override
  String memoryGraphClusters(int count) {
    return 'Clusters $count';
  }

  @override
  String get memoryGraphDocuments => 'Documentos';

  @override
  String get memoryGraphLifeDashboard => 'Panel de vida';

  @override
  String get memoryGraphLifeSimulator => 'Simulador de vida';

  @override
  String memoryGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodos',
      one: '1 nodo',
    );
    return '$_temp0';
  }

  @override
  String get memoryGraphPreview => 'Vista previa del gráfico';

  @override
  String get memoryGraphReturnToPresent => 'Volver al presente';

  @override
  String get memoryGraphSampleBadge => 'Mente de ejemplo · ilustrativo';

  @override
  String get memoryGraphSmallSteps => 'Pequeños pasos';

  @override
  String get memoryGraphTimeMachine => 'Máquina del tiempo';

  @override
  String get memoryGraphWeekly => 'Semanal';

  @override
  String get memoryGraphWidgets => 'Widgets';

  @override
  String get meshNoPeers => 'No hay dispositivos emparejados cerca.';

  @override
  String get meshPairDevice => 'Emparejar un dispositivo';

  @override
  String get meshPrivacyDescription =>
      'El descubrimiento cercano solo anuncia un identificador rotativo. Los metadatos del archivo se intercambian tras el emparejamiento cifrado.';

  @override
  String get meshReadOnlyBranch => 'Rama compartida de solo lectura';

  @override
  String get meshShareCluster => 'Compartir este cluster';

  @override
  String get meshStatusComplete => 'Sincronización local completa';

  @override
  String get meshStatusConnected => 'Conectado de forma segura';

  @override
  String get meshStatusSearching => 'Buscando cerca';

  @override
  String get meshStatusTitle => 'Sincronización cifrada cercana';

  @override
  String get meshSyncNow => 'Sincronizar cerca';

  @override
  String get navigationAccount => 'Cuenta';

  @override
  String get navigationArchive => 'Archivo';

  @override
  String get navigationChanges => 'Cambios';

  @override
  String get navigationRecord => 'Grabar';

  @override
  String get primaryNavigationLabel => 'Navegación principal';

  @override
  String get recapCopied => 'Resumen copiado.';

  @override
  String get recordScreenLabel => 'Pantalla de grabación';

  @override
  String get recordingCopyRecap => 'Copiar resumen';

  @override
  String get recordingEnoughForNow => 'Suficiente por ahora';

  @override
  String recordingInProgressSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return 'Grabación en curso, $_temp0';
  }

  @override
  String get recordingPlainLanguageHint =>
      'Dilo con claridad. Thoughtprint busca patrones, no juicios.';

  @override
  String get recordingProcessingStatus => 'Procesando';

  @override
  String get recordingPromptNudgeBody =>
      'Thoughtprint usa lo que grabas para mostrar cada día cosas más claras que merecen la pena comprobar.';

  @override
  String get recordingPromptNudgeTitle =>
      'Mejora tus indicaciones diarias del archivo';

  @override
  String get recordingReadyStatus => 'Listo para grabar';

  @override
  String get recordingSavedBackgroundTranscription =>
      'Grabación guardada. La transcripción terminará en segundo plano.';

  @override
  String get recordingSavedStatus => 'Guardado';

  @override
  String get recordingStatus => 'Grabando';

  @override
  String get recordingStopAndSaveHint =>
      'Toca Detener y guardar cuando hayas terminado.';

  @override
  String get recordingUnlockPro => 'Desbloquear Pro';

  @override
  String get savedForNextCheckIn => 'Guardado para tu próximo registro.';

  @override
  String get savedForNextMonthCheck =>
      'Guardado para el registro del próximo mes.';

  @override
  String get savedForTomorrowCheck =>
      'Guardado para la comprobación de mañana.';

  @override
  String get textJournalPanelLead =>
      'No hace falta micrófono — unas frases bastan para tu archivo.';

  @override
  String get textJournalPanelTitle => 'Escribe un momento';

  @override
  String get textJournalSaveCta => 'Guardar pensamiento';

  @override
  String get tomorrowCheckSet => 'La comprobación de mañana está programada.';

  @override
  String get watchQuickRecordCta => 'Empezar a grabar';

  @override
  String get watchQuickRecordTitle => 'Grabación rápida';

  @override
  String get widgetQuickCaptureAction => 'Grabar';

  @override
  String get widgetQuickCaptureBody =>
      'Captura un momento desde la pantalla de inicio.';

  @override
  String get accountTitle => 'Cuenta de Thoughtprint';

  @override
  String get syncStatus => 'Estado de sincronización';

  @override
  String get syncNotAvailableTestFlight =>
      'La sincronización no está disponible en esta versión de TestFlight.';

  @override
  String get syncOnDeviceOnly => 'En este dispositivo';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get accountPrivacyNote =>
      'Tus grabaciones permanecen en este dispositivo a menos que inicies sesión para sincronizar.';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get settings => 'Ajustes';

  @override
  String get accountSessionLoading => 'Cargando…';

  @override
  String get accountNotSignedIn => 'Sin sesión iniciada';

  @override
  String get accountSignedIn => 'Sesión iniciada';

  @override
  String get accountSignedInForSync => 'Sesión iniciada para sincronizar';

  @override
  String get accountLastSyncedToday => 'Última sincronización hoy';

  @override
  String get recordTitle => '¿Qué tienes en mente?';

  @override
  String get recordSubtitle => 'Di una cosa pequeña de hoy.';

  @override
  String get recordOneMomentCta => 'Grabar un momento';

  @override
  String get recordMomentCta => 'Grabar momento';

  @override
  String get stopRecordingCta => 'Detener grabación';

  @override
  String get recordAnotherCta => 'Grabar otro';

  @override
  String get recordNextMomentCta => 'Grabar el siguiente momento';

  @override
  String get startRecording => 'Empezar a grabar';

  @override
  String get trySayingOneOfThese => 'Prueba decir una de estas';

  @override
  String get recordHelpSheetTitle => 'Elige un indicio';

  @override
  String get recordHelpSheetHelper => 'Elige uno y graba una frase.';

  @override
  String get reflectionSavedTitle => 'Reflexión guardada';

  @override
  String get postSaveRecordAnother => 'Grabar otro momento';

  @override
  String get viewPatternsCta => 'Ver patrones';

  @override
  String get back => 'Atrás';

  @override
  String get firstSavePostSaveTitle => 'Guardado.';

  @override
  String get firstSavePostSaveBody => 'Vuelve cuando esto aparezca de nuevo.';

  @override
  String get finishRecordingFirst => 'Termina o cancela la grabación primero.';

  @override
  String get paywallHeadline => 'Viste la primera repetición útil.';

  @override
  String get paywallSubhead =>
      'Gratis muestra la primera prueba útil. Pro conserva el historial más largo.';

  @override
  String get paywallPrimaryCta => 'Conservar el historial más largo';

  @override
  String get paywallSecondaryCta => 'Ahora no';

  @override
  String get paywallContinue => 'Conservar el historial más largo';

  @override
  String get paywallDifferentiation =>
      'Thoughtprint no intenta responder mejor que ChatGPT. Intenta recordar de otra manera.';

  @override
  String get paywallTrust =>
      'Tus guardados siguen siendo gratis. Gestiona o cancela cuando quieras en el App Store.';

  @override
  String get paywallBackupLine =>
      'Estás acumulando evidencia con el tiempo. Pro conserva el historial de pruebas más largo cuando los momentos regresan, cambian o se desvanecen.';

  @override
  String get paywallPrimaryValueBlock =>
      'Pro conserva un archivo privado más largo: más momentos, más continuidad, más evidencia con el tiempo.';

  @override
  String get paywallBackToPatterns => 'Volver a Patrones';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get paywallAnchorPositioningLine =>
      'Mantén creciendo tu línea de tiempo verificada.';

  @override
  String get paywallProofConnectedLine =>
      'Pro conserva un archivo privado más largo: más momentos, más continuidad, más evidencia con el tiempo.';

  @override
  String get paywallSecondaryReassurance =>
      'Tú mantienes el control. Puedes eliminar entradas y corregir lo que guardaste.';

  @override
  String get paywallBenefitBullet1 =>
      'Historial de evidencia más largo en este dispositivo';

  @override
  String get paywallBenefitBullet2 =>
      'Más momentos archivados durante semanas y meses';

  @override
  String get paywallBenefitBullet3 =>
      'Continuidad cuando los patrones regresan o cambian';

  @override
  String get paywallSetupUnavailableBody =>
      'Los planes no están disponibles en este momento.';

  @override
  String get paywallUnavailablePlansLoading => 'Cargando planes…';

  @override
  String get valueMomentProTitle =>
      'Conserva el historial de pruebas más largo';

  @override
  String get valueMomentProCta => 'Ver Pro';

  @override
  String get valueMomentProDismiss => 'Ahora no';

  @override
  String get valueMomentThreadReturnBody =>
      'Este hilo ha regresado antes. Pro conserva el historial de evidencia para que Thoughtprint pueda mostrar si se fortalece, se suaviza o cambia.';

  @override
  String get valueMomentBeliefBody =>
      'Una frase similar a una creencia apareció de nuevo. Pro conserva la línea de tiempo de lo que cambió en tu archivo.';

  @override
  String get valueMomentWeeklyBody =>
      'Tu revisión semanal encontró algo para comparar. Pro conserva las revisiones semanales del archivo para que Thoughtprint pueda seguir lo que cambió con el tiempo.';

  @override
  String get valueMomentProofCounterBody =>
      'Tu archivo tiene grabaciones conectadas. Pro conserva todo el historial de evidencia a medida que crece el rastro.';

  @override
  String get valueMomentFallbackBody =>
      'Tu primera repetición es gratis. Pro conserva el historial de evidencia para que Thoughtprint pueda mostrar si los patrones se fortalecen, se suavizan o cambian con el tiempo.';

  @override
  String get subscriptionPaywallNoOfferings =>
      'No hay planes de suscripción disponibles.';

  @override
  String get purchaseSuccess => 'Pro está activo.';

  @override
  String get restorePurchasesError => 'No se pudieron restaurar las compras.';

  @override
  String get patternsTabLabel => 'Archivo';

  @override
  String get patternsEmptyPageTitle => 'Graba algunos momentos reales';

  @override
  String get patternsEarlyStateBody =>
      'Graba algunos momentos reales. Thoughtprint buscará lo que se repite entre ellos.';

  @override
  String get patternsEmptyCta => 'Grabar momento';

  @override
  String get patternsHeroHeading => 'LO QUE SIGUE REPITIÉNDOSE EN TU VIDA';

  @override
  String get patternsShiftingHeading => 'LO QUE PUEDE ESTAR CAMBIANDO';

  @override
  String get patternsEvolutionHeading => 'CAMBIANDO CON EL TIEMPO';

  @override
  String get patternsSectionCurrent => 'Patrones que siguen repitiéndose';

  @override
  String get patternsSectionEmerging => 'Se está formando un patrón';

  @override
  String get patternsSectionChanging => 'Esto parece estar cambiando';

  @override
  String get patternsFirstEntrySavedTitle => 'Primer momento guardado';

  @override
  String get patternsFirstEntrySavedBody =>
      'Graba un momento más claro y Thoughtprint podrá comparar lo que se repite.';

  @override
  String get patternsFirstEntrySavedCta => 'Grabar otro momento';

  @override
  String get patternsFirstEntryViewSavedCta => 'Ver entrada guardada';

  @override
  String get patternsHowItWorksTitle => 'Cómo funciona';

  @override
  String get patternsPrivacyReassurance =>
      'Privado en tu dispositivo. Nada se comparte sin que tú lo elijas.';

  @override
  String get allPatternsTitle => 'Todos los patrones';

  @override
  String get allPatternsLead =>
      'Patrones y temas que Thoughtprint sigue notando en tus reflexiones.';

  @override
  String get patternsCheckInWaitingTitle => 'Registro pendiente';

  @override
  String get patternsCheckInWaitingBody =>
      'Thoughtprint tiene una pregunta de tu último momento.';

  @override
  String get patternsCheckInWaitingCta => 'Responder ahora';

  @override
  String get patternsLoopClosedTitle => 'Bucle cerrado';

  @override
  String get patternsRecordAnotherMomentCta => 'Grabar otro momento';

  @override
  String get patternsResultUseCheckCta => 'Usar esta comprobación';

  @override
  String get patternsSignalsWaitingTitle => 'Señales esperando claridad';

  @override
  String get patternsWatchingSignalTitle =>
      'Thoughtprint está observando esta señal';

  @override
  String get patternsWatchingSignalBody =>
      'Graba un momento más para comprobar si se repite.';

  @override
  String get archiveDiscoverPatternsLink => 'Ver todos los patrones';

  @override
  String get archiveTimelineLink => 'Línea de tiempo';

  @override
  String get archiveSearchLink => 'Buscar en el archivo';

  @override
  String get activePatternCurrentTitle => 'Patrón actual';

  @override
  String get activePatternRecordTodayCta => 'Grabar hoy';

  @override
  String get seeWhatChanged => 'Ver qué cambió';

  @override
  String get patternsComeBackTitle => '¿Por qué volver mañana?';

  @override
  String get patternsComeBackBody =>
      'Thoughtprint compara lo que guardas con el tiempo.';

  @override
  String get patternsComeBackRecordCta => 'Grabar la reflexión de hoy';

  @override
  String get v1Copy0000 => 'When it repeats, record it.';

  @override
  String get v1Copy0001 =>
      'Record one real entry. Thoughtprint compares it later.';

  @override
  String get v1Copy0002 => 'Not a diary. Not homework. One sentence is enough.';

  @override
  String get v1Copy0003 =>
      'When something shows up again, your archive builds an evidence trail.';

  @override
  String get v1Copy0004 =>
      'Over time, it can show what started it, what changed, and what helped.';

  @override
  String get v1Copy0005 => 'Type instead';

  @override
  String get v1Copy0006 => 'Record entry';

  @override
  String get v1Copy0007 => 'How Thoughtprint works';

  @override
  String get v1Copy0009 => 'What returned';

  @override
  String get v1Copy0010 => 'What softened';

  @override
  String get v1Copy0011 => 'What changed';

  @override
  String get v1Copy0013 =>
      'If it returns, changes, fades, or disappears, record that entry too. ';

  @override
  String get v1Copy0014 => 'You do not need to keep working on this now.';

  @override
  String get v1Copy0015 => 'Done for today';

  @override
  String get v1Copy0016 => 'This may be a repeat:';

  @override
  String get v1Copy0017 => 'Thoughtprint can now start comparing this pattern.';

  @override
  String get v1Copy0018 => 'This looks like it came back.';

  @override
  String get v1Copy0019 => 'You mentioned something similar before.';

  @override
  String get v1Copy0020 =>
      'This may be the same pattern as an earlier recorded entry.';

  @override
  String get v1Copy0021 =>
      'This looks like it came back, but Thoughtprint needs more entries to be sure.';

  @override
  String get v1Copy0024 => 'Why this matters';

  @override
  String get v1Copy0025 => 'Pro keeps the longer trail.';

  @override
  String get v1Copy0026 => 'Your archive has started.';

  @override
  String get v1Copy0027 => 'This is the first piece of evidence.';

  @override
  String get v1Copy0028 =>
      'If it returns, changes, fades, or disappears, record that entry too.';

  @override
  String get v1Copy0029 =>
      'Come back when this shows up again. Just one private record so far.';

  @override
  String get v1Copy0030 =>
      'Sample Archive below shows how comparison works — demo entries only, ';

  @override
  String get v1Copy0031 => 'no private entries.';

  @override
  String get v1Copy0032 =>
      'A second entry lets Thoughtprint compare your own words — cautiously, ';

  @override
  String get v1Copy0033 => 'not as a conclusion.';

  @override
  String get v1Copy0034 => 'Record if it happens again';

  @override
  String get v1Copy0035 => 'View archive';

  @override
  String get v1Copy0036 => 'Record a few real entries';

  @override
  String get v1Copy0037 =>
      'Thoughtprint will look for what repeats across them.';

  @override
  String get v1Copy0038 => 'What keeps repeating';

  @override
  String get v1Copy0039 => 'Next to watch';

  @override
  String get v1Copy0040 => 'What may have helped';

  @override
  String get v1Copy0041 => 'Patterns are still forming';

  @override
  String get v1Copy0042 =>
      'Thoughtprint needs clearer real entries before it can compare what repeats.';

  @override
  String get v1Copy0043 => 'Preview — not a conclusion yet';

  @override
  String get v1Copy0044 => 'Not enough evidence yet';

  @override
  String get v1Copy0045 => 'Your own words across recordings';

  @override
  String get v1Copy0046 =>
      'Whether the same pattern gets lighter, stronger, or disappears';

  @override
  String get v1Copy0047 => '1 recorded entry';

  @override
  String get v1Copy0048 =>
      'A second entry shows whether the same pattern returns.';

  @override
  String get v1Copy0049 => 'Thoughtprint is starting to compare your entries.';

  @override
  String get v1Copy0050 =>
      'If the same words or situations keep returning, this is where your ';

  @override
  String get v1Copy0051 => 'archive will show the pattern.';

  @override
  String get v1Copy0052 => 'You now have more than one entry to compare.';

  @override
  String get v1Copy0053 => 'Record once more to strengthen the signal.';

  @override
  String get v1Copy0054 => 'Thoughtprint has two entries to compare.';

  @override
  String get v1Copy0055 =>
      'No clear repeat yet. One more entry will make the pattern easier to see.';

  @override
  String get v1Copy0056 =>
      'These two entries may be related. Thoughtprint is keeping the evidence ';

  @override
  String get v1Copy0057 => 'separate until there is more to compare.';

  @override
  String get v1Copy0058 => 'Add one more entry to make the pattern clearer.';

  @override
  String get v1Copy0059 =>
      'Thoughtprint is starting to see a possible pattern.';

  @override
  String get v1Copy0060 =>
      'Still forming — a draft pattern, not a final answer';

  @override
  String get v1Copy0061 =>
      'This is only what your recorded words suggest so far. ';

  @override
  String get v1Copy0062 =>
      'Thoughtprint will keep comparing as you add entries.';

  @override
  String get v1Copy0063 =>
      'Thoughtprint is using your recorded words, not guessing.';

  @override
  String get v1Copy0064 => 'Evidence from your archive';

  @override
  String get v1Copy0065 =>
      'Thoughtprint can compare this more clearly with one more distinct entry.';

  @override
  String get v1Copy0066 => 'Add one more entry to make this clearer.';

  @override
  String get v1Copy0067 => 'Your archive noticed something.';

  @override
  String get v1Copy0068 => 'Something shifted in your recorded words.';

  @override
  String get v1Copy0069 => 'A repeated pattern is starting to stand out.';

  @override
  String get v1Copy0070 => 'What this may be pointing to';

  @override
  String get v1Copy0071 => 'This showed up in a new context.';

  @override
  String get v1Copy0072 =>
      'The same feeling appeared again, but with different words.';

  @override
  String get v1Copy0073 =>
      'This is appearing in more than one entry, so Thoughtprint can compare ';

  @override
  String get v1Copy0074 => 'it more clearly.';

  @override
  String get v1Copy0075 =>
      'Your archive is beginning to notice similar pressure across your ';

  @override
  String get v1Copy0076 => 'recorded entries.';

  @override
  String get v1Copy0077 =>
      'Your archive is starting to notice pressure around work.';

  @override
  String get v1Copy0078 =>
      'Your archive is starting to connect pressure with agreeing too quickly.';

  @override
  String get v1Copy0079 =>
      'Your archive is starting to connect pressure with not falling behind.';

  @override
  String get v1Copy0080 => 'View evidence';

  @override
  String get v1Copy0081 => 'Evidence behind this possible pattern';

  @override
  String get v1Copy0082 =>
      'This is only what your recorded words suggest so far.';

  @override
  String get v1Copy0083 =>
      'Your archive needs more entries before it can show an evidence trail.';

  @override
  String get v1Copy0084 => 'Still uncertain';

  @override
  String get v1Copy0085 =>
      'More distinct recorded entries would make this easier to compare.';

  @override
  String get v1Copy0086 => 'Add one more entry';

  @override
  String get v1Copy0087 =>
      'Add one more distinct entry to make this possible pattern clearer.';

  @override
  String get v1Copy0088 => 'Add another entry when this shows up again.';

  @override
  String get v1Copy0089 =>
      'A possible pattern in your archive may have changed.';

  @override
  String get v1Copy0090 =>
      'Earlier, your archive was mostly seeing pressure around one entry. ';

  @override
  String get v1Copy0091 =>
      'Now it is seeing that pressure across more than one context.';

  @override
  String get v1Copy0092 => 'Pattern history';

  @override
  String get v1Copy0093 => 'This possible pattern has not clearly changed yet.';

  @override
  String get v1Copy0094 => 'Earlier read';

  @override
  String get v1Copy0095 => 'Evidence that changed it';

  @override
  String get v1Copy0096 =>
      'Your archive was mostly seeing pressure around one entry.';

  @override
  String get v1Copy0097 =>
      'Your archive appears to see that pressure across more than one context.';

  @override
  String get v1Copy0098 =>
      'A newer entry may have widened what your archive can compare.';

  @override
  String get v1Copy0099 => 'Your archive review';

  @override
  String get v1Copy0100 => 'What your recorded words are starting to show.';

  @override
  String get v1Copy0101 => 'This is a draft pattern, not a final answer.';

  @override
  String get v1Copy0102 =>
      'Your archive needs more entries before it can create a review.';

  @override
  String get v1Copy0103 => 'What to add next';

  @override
  String get v1Copy0104 => 'Add one more entry when this shows up again.';

  @override
  String get v1Copy0105 =>
      'Add one more distinct entry to make this review clearer.';

  @override
  String get v1Copy0106 => 'View review';

  @override
  String get v1Copy0107 =>
      'Pressure at work keeps showing up in your recent entries.';

  @override
  String get v1Copy0108 =>
      'Similar pressure keeps returning in your recent entries.';

  @override
  String get v1Copy0109 => 'Saying yes when part of you meant no.';

  @override
  String get v1Copy0110 =>
      'Trying not to fall behind may be doing more of the driving.';

  @override
  String get v1Copy0111 =>
      'Your latest entries may be widening what your archive can compare.';

  @override
  String get v1Copy0112 => 'One more will confirm whether this repeats.';

  @override
  String get v1Copy0113 =>
      'Thoughtprint needs one more entry before it can compare clearly.';

  @override
  String get v1Copy0114 =>
      'Your archive is starting a cautious possible pattern. ';

  @override
  String get v1Copy0115 => 'Add one more entry to strengthen the evidence.';

  @override
  String get v1Copy0116 => 'You added one piece today.';

  @override
  String get v1Copy0117 => 'Thoughtprint has one entry to compare later.';

  @override
  String get v1Copy0118 => 'Record that entry only if it happens again.';

  @override
  String get v1Copy0119 => 'I recorded one entry for my archive.';

  @override
  String get v1Copy0120 => 'Share safely';

  @override
  String get v1Copy0121 =>
      'Share Thoughtprint without exposing private entries.';

  @override
  String get v1Copy0122 =>
      'My archive is starting to show what keeps coming back.';

  @override
  String get v1Copy0123 =>
      'Thoughtprint is helping me notice what repeats — with evidence, not guesses.';

  @override
  String get v1Copy0124 =>
      'I recorded entries. My archive started showing the pattern.';

  @override
  String get v1Copy0125 => 'No private entries shared.';

  @override
  String get v1Copy0126 =>
      'Thoughtprint — your private evidence-based life archive.';

  @override
  String get v1Copy0127 => 'Pattern your archive is watching';

  @override
  String get v1Copy0128 =>
      'A second entry can show whether the same pattern returns.';

  @override
  String get v1Copy0129 => 'Add one more entry.';

  @override
  String get v1Copy0130 =>
      'Your archive has one piece. Come back when this shows up again.';

  @override
  String get v1Copy0131 => 'One more entry can make the pattern clearer.';

  @override
  String get v1Copy0132 => 'Thoughtprint has two entries to compare. ';

  @override
  String get v1Copy0133 =>
      'A third can help it form a cautious first possible pattern.';

  @override
  String get v1Copy0134 =>
      'Your archive is starting to see a possible pattern.';

  @override
  String get v1Copy0135 =>
      'Add one more entry to test whether the evidence holds.';

  @override
  String get v1Copy0136 =>
      'Review what changed, then add another entry when it shows up again.';

  @override
  String get v1Copy0137 => 'Your archive review is ready.';

  @override
  String get v1Copy0138 =>
      'See what your recorded words are starting to show this week.';

  @override
  String get v1Copy0139 =>
      'Your archive needs another recorded entry before it can compare.';

  @override
  String get v1Copy0140 => 'Add the entry that makes this clearer.';

  @override
  String get v1Copy0141 => 'Test this possible pattern with one more entry.';

  @override
  String get v1Copy0142 =>
      'Your archive is starting to see a possible pattern. ';

  @override
  String get v1Copy0143 =>
      'Another example can show whether the evidence holds.';

  @override
  String get v1Copy0144 => 'Add the entry that would change the evidence.';

  @override
  String get v1Copy0145 => 'Your archive noticed something. ';

  @override
  String get v1Copy0146 =>
      'Record the next entry when this shows up in a new context.';

  @override
  String get v1Copy0147 => 'Help your archive review the week.';

  @override
  String get v1Copy0148 =>
      'Record the next entry that confirms, weakens, or changes ';

  @override
  String get v1Copy0149 => 'this week\\u2019s strongest thread.';

  @override
  String get v1Copy0150 => 'Add a entry that clarifies your correction.';

  @override
  String get v1Copy0151 => 'You marked an archive insight as not quite right. ';

  @override
  String get v1Copy0152 =>
      'Record the next example that shows what Thoughtprint missed.';

  @override
  String get v1Copy0153 => 'Help Thoughtprint retest this possible pattern.';

  @override
  String get v1Copy0154 => 'Your note says this insight missed something. ';

  @override
  String get v1Copy0155 =>
      'Add the next entry that supports, weakens, or changes the evidence.';

  @override
  String get v1Copy0156 => 'Help your review learn from your correction.';

  @override
  String get v1Copy0157 =>
      'Record the next entry that shows whether your correction ';

  @override
  String get v1Copy0158 => 'holds across more than one example.';

  @override
  String get v1Copy0159 =>
      'One more distinct recorded entry would help Thoughtprint compare this more ';

  @override
  String get v1Copy0160 => 'Partly fits';

  @override
  String get v1Copy0161 => 'Why am I seeing this?';

  @override
  String get v1Copy0162 => 'You can hide this if it does not feel useful.';

  @override
  String get v1Copy0163 =>
      'Your archive is still testing this possible pattern.';

  @override
  String get v1Copy0164 => 'This may not be quite right yet.';

  @override
  String get v1Copy0165 =>
      'The evidence needs another entry before this is useful.';

  @override
  String get v1Copy0166 => 'Recorded as useful feedback.';

  @override
  String get v1Copy0167 => 'Tell Thoughtprint what it missed';

  @override
  String get v1Copy0168 => 'Add a private note\\u2026';

  @override
  String get v1Copy0169 => 'You marked this as not quite right.';

  @override
  String get v1Copy0170 => 'Your note:';

  @override
  String get v1Copy0171 => 'Insight quality';

  @override
  String get v1Copy0172 =>
      'Control what Thoughtprint learns from your feedback. This stays on this device.';

  @override
  String get v1Copy0173 => 'Manage feedback';

  @override
  String get v1Copy0174 => 'Feedback summary';

  @override
  String get v1Copy0175 => 'Hidden insights';

  @override
  String get v1Copy0176 => 'Correction notes';

  @override
  String get v1Copy0177 => 'Insights marked Partly fits';

  @override
  String get v1Copy0178 => 'No local feedback yet';

  @override
  String get v1Copy0179 =>
      'When you respond to archive insights, your feedback will appear here.';

  @override
  String get v1Copy0180 => 'Your feedback stays on this device.';

  @override
  String get v1Copy0181 => 'Correction notes are not shared.';

  @override
  String get v1Copy0182 => 'Share safely never includes your private notes.';

  @override
  String get v1Copy0183 => 'Edit note';

  @override
  String get v1Copy0184 => 'Clear feedback';

  @override
  String get v1Copy0185 => 'Delete note';

  @override
  String get v1Copy0186 => 'More cautious copy is active.';

  @override
  String get v1Copy0187 => 'Thoughtprint is still testing this insight.';

  @override
  String get v1Copy0188 => 'Archive Home';

  @override
  String get v1Copy0189 => 'Archive Home (three entries)';

  @override
  String get v1Copy0190 => 'Archive Home (four entries)';

  @override
  String get v1Copy0191 => 'Archive Home (weekly review stage)';

  @override
  String get v1Copy0192 => 'Weekly archive review';

  @override
  String get v1Copy0193 => 'Evidence trail';

  @override
  String get v1Copy0194 => 'Pattern update';

  @override
  String get v1Copy0195 => 'Archive health';

  @override
  String get v1Copy0196 => 'Based on usable recorded entries on this device.';

  @override
  String get v1Copy0197 => 'Usable entries';

  @override
  String get v1Copy0198 => 'Evidence quality';

  @override
  String get v1Copy0199 => 'What needs more evidence';

  @override
  String get v1Copy0200 => 'Evidence is still thin.';

  @override
  String get v1Copy0201 => 'Your archive is starting to compare.';

  @override
  String get v1Copy0202 =>
      'Your archive has enough to form a cautious first possible pattern.';

  @override
  String get v1Copy0203 => 'Possible patterns are not conclusions.';

  @override
  String get v1Copy0204 =>
      'Your archive has enough evidence to update a possible pattern.';

  @override
  String get v1Copy0205 => 'Your archive is getting clearer.';

  @override
  String get v1Copy0206 => 'Your archive has enough to create a review.';

  @override
  String get v1Copy0207 =>
      'Evidence is stronger when entries appear across more than one context.';

  @override
  String get v1Copy0208 => 'Your archive has enough to review.';

  @override
  String get v1Copy0209 =>
      'recorded entries were too short or unclear to count';

  @override
  String get v1Copy0210 => 'Some recorded entries look very similar.';

  @override
  String get v1Copy0211 => 'Some recorded entries look nearly the same.';

  @override
  String get v1Copy0212 => 'Some insights were marked not quite right.';

  @override
  String get v1Copy0213 => 'Correction notes are active on this device.';

  @override
  String get v1Copy0214 => 'Local feedback suggests staying cautious.';

  @override
  String get v1Copy0215 => 'Record one more ordinary entry.';

  @override
  String get v1Copy0216 =>
      'Add one more entry from a different part of your day.';

  @override
  String get v1Copy0217 =>
      'Add a entry that tests the first cautious possible pattern.';

  @override
  String get v1Copy0218 =>
      'Add a entry that might change what the archive notices.';

  @override
  String get v1Copy0219 =>
      'Add a entry from a different context to strengthen the review.';

  @override
  String get v1Copy0220 => 'Add a entry with different words or context.';

  @override
  String get v1Copy0221 => 'Add one more distinct recorded entry.';

  @override
  String get v1Copy0222 => 'Improve your archive';

  @override
  String get v1Copy0223 => 'Small steps that make your archive more useful.';

  @override
  String get v1Copy0224 => 'What would help next';

  @override
  String get v1Copy0225 =>
      'Add one more entry before Thoughtprint compares anything.';

  @override
  String get v1Copy0226 =>
      'Add a third entry to help form a cautious first possible pattern.';

  @override
  String get v1Copy0227 => 'Add a entry from a different context.';

  @override
  String get v1Copy0228 =>
      'Add text to recorded entries that were too unclear.';

  @override
  String get v1Copy0229 => 'Where did this show up?';

  @override
  String get v1Copy0230 =>
      'Tags stay on this device and help your archive compare entries.';

  @override
  String get v1Copy0231 => 'No context tag';

  @override
  String get v1Copy0233 => 'Edit context';

  @override
  String get v1Copy0234 => 'Edit context tag';

  @override
  String get v1Copy0235 => 'Clear tag';

  @override
  String get v1Copy0236 => 'Tagged entries so far share one context.';

  @override
  String get v1Copy0237 => 'Tagged entries may span more than one context.';

  @override
  String get v1Copy0238 => 'Where this shows up';

  @override
  String get v1Copy0239 => 'Based on optional tags recorded on this device.';

  @override
  String get v1Copy0240 => 'Your archive has one tagged entry.';

  @override
  String get v1Copy0241 => 'Add another tagged entry to compare contexts.';

  @override
  String get v1Copy0243 =>
      'Add a entry from a different context to see whether it travels.';

  @override
  String get v1Copy0244 => 'This is showing up across more than one context.';

  @override
  String get v1Copy0245 => 'The context evidence is still thin.';

  @override
  String get v1Copy0246 => 'Tagged entries by context';

  @override
  String get v1Copy0247 => 'This is mostly showing up at work.';

  @override
  String get v1Copy0248 => 'This is mostly showing up at home.';

  @override
  String get v1Copy0250 => 'This has shown up in more than one context.';

  @override
  String get v1Copy0252 => 'Evidence map';

  @override
  String get v1Copy0253 =>
      'Where your recorded entries are showing up on this device.';

  @override
  String get v1Copy0254 =>
      'Your archive needs a recorded entry before it can map evidence.';

  @override
  String get v1Copy0255 => 'Your evidence map has one tagged entry.';

  @override
  String get v1Copy0256 => 'Add another entry to compare contexts.';

  @override
  String get v1Copy0258 => 'Your evidence spans more than one context.';

  @override
  String get v1Copy0259 =>
      'Add context tags to make your evidence map clearer.';

  @override
  String get v1Copy0260 =>
      'Unclear recordings are excluded from evidence quality.';

  @override
  String get v1Copy0261 => 'Strongest context';

  @override
  String get v1Copy0262 => 'Thin contexts';

  @override
  String get v1Copy0263 => 'Untagged entries';

  @override
  String get v1Copy0264 => '1 entry does not have a context tag yet.';

  @override
  String get v1Copy0270 => 'Untagged evidence';

  @override
  String get v1Copy0271 => 'Recorded entries counted in your evidence map.';

  @override
  String get v1Copy0272 =>
      'No recorded entries are counted in this context right now.';

  @override
  String get v1Copy0273 => 'Open entry';

  @override
  String get v1Copy0274 => 'Needs attention';

  @override
  String get v1Copy0275 => 'Same context';

  @override
  String get v1Copy0276 => 'Review and history';

  @override
  String get v1Copy0277 => 'Next best actions';

  @override
  String get v1Copy0278 => 'Tag untagged entries';

  @override
  String get v1Copy0279 => 'Review corrections';

  @override
  String get v1Copy0280 => 'View evidence map';

  @override
  String get v1Copy0281 => 'View weekly review';

  @override
  String get v1Copy0282 => 'This is your private archive workspace.';

  @override
  String get v1Copy0283 =>
      'Thoughtprint uses your recorded entries to show evidence, patterns, and what to add next.';

  @override
  String get v1Copy0284 =>
      'These shortcuts point to evidence that may need a tag, correction, or another entry.';

  @override
  String get v1Copy0285 =>
      'This section shows where your archive has enough evidence, and where it is still thin.';

  @override
  String get v1Copy0286 =>
      'When you have enough recorded entries, Thoughtprint can show how a possible pattern may have changed.';

  @override
  String get v1Copy0287 => 'Why this section?';

  @override
  String get v1Copy0288 => 'These entries may be related';

  @override
  String get v1Copy0289 =>
      'Thoughtprint noticed similar wording across two recorded entries. ';

  @override
  String get v1Copy0290 => 'This is not an established pattern yet.';

  @override
  String get v1Copy0291 => 'Possible pattern';

  @override
  String get v1Copy0292 =>
      'These entries may repeat a similar theme. Review the evidence ';

  @override
  String get v1Copy0293 => 'before treating it as settled.';

  @override
  String get v1Copy0294 => 'What may have changed';

  @override
  String get v1Copy0295 =>
      'Your earlier and recent entries describe this differently. ';

  @override
  String get v1Copy0296 => 'This does not prove improvement or causation.';

  @override
  String get v1Copy0297 => 'Not for me';

  @override
  String get v1Copy0298 => 'Your words';

  @override
  String get v1Copy0299 => 'Thoughtprint suggestion';

  @override
  String get v1Copy0300 => 'Review status';

  @override
  String get v1Copy0301 => 'Possible patterns Thoughtprint is watching';

  @override
  String get v1Copy0302 => 'Thoughtprint does not have enough evidence yet.';

  @override
  String get v1Copy0303 =>
      'Thoughtprint may need more entries before this feels settled.';

  @override
  String get v1Copy0304 => 'How often it shows up';

  @override
  String get v1Copy0305 => 'Entries that may not fit';

  @override
  String get v1Copy0306 => 'Missing evidence';

  @override
  String get v1Copy0307 => 'What would strengthen this possible pattern';

  @override
  String get v1Copy0308 => 'Show me why';

  @override
  String get v1Copy0309 => 'What may be missing';

  @override
  String get v1Copy0310 => 'Why does Thoughtprint suggest this?';

  @override
  String get v1Copy0311 => 'Why the archive moved';

  @override
  String get v1Copy0312 =>
      'Your archive updated its view of a possible pattern.';

  @override
  String get v1Copy0313 => 'Evidence shifted';

  @override
  String get v1Copy0314 =>
      'Your archive added new evidence to an existing possible pattern.';

  @override
  String get v1Copy0315 => 'A entry may not fit the earlier read.';

  @override
  String get v1Copy0316 =>
      'A possible pattern may have weakened as new evidence arrived.';

  @override
  String get v1Copy0317 =>
      'A possible pattern may have strengthened as new evidence arrived.';

  @override
  String get v1Copy0318 =>
      'No major change yet. This reflection still gives the archive another comparison point.';

  @override
  String get v1Copy0319 => 'Evidence ledger';

  @override
  String get v1Copy0320 =>
      'Possible patterns, changes, and evidence from your archive.';

  @override
  String get v1Copy0321 => 'Search entries, patterns, and evidence…';

  @override
  String get v1Copy0322 => 'No indexed evidence yet';

  @override
  String get v1Copy0323 =>
      'Record a entry and let Thoughtprint index citable facts — they will appear here.';

  @override
  String get v1Copy0324 => 'All time';

  @override
  String get v1Copy0325 => '7 days';

  @override
  String get v1Copy0326 => '30 days';

  @override
  String get v1Copy0327 => '90 days';

  @override
  String get v1Copy0328 => 'Nothing matches your search or date filter.';

  @override
  String get v1Copy0329 => '1 Citable Fact';

  @override
  String get v1Copy0331 => '1 Entry';

  @override
  String get v1Copy0336 => 'No cited ledger entries yet · Tap to inspect';

  @override
  String get v1Copy0337 =>
      'Not enough linked recordings yet. Record another entry with a little more detail.';

  @override
  String get v1Copy0338 => 'How close does this feel to your entries?';

  @override
  String get v1Copy0339 => 'Support & feedback';

  @override
  String get v1Copy0340 => 'Get help or share what is not working.';

  @override
  String get v1Copy0341 => 'Need help?';

  @override
  String get v1Copy0342 => 'For support, use the Thoughtprint support page.';

  @override
  String get v1Copy0343 => 'Report a problem';

  @override
  String get v1Copy0344 =>
      'Tell us what happened, what you expected, and whether it involved ';

  @override
  String get v1Copy0345 =>
      'Record, Archive, Sample Archive, Export, or Settings.';

  @override
  String get v1Copy0346 => 'Privacy reminder';

  @override
  String get v1Copy0347 =>
      'Do not send private entries unless you choose to include them.';

  @override
  String get v1Copy0348 =>
      'Share-safe summary does not include raw private entries.';

  @override
  String get v1Copy0349 => 'Useful testing paths';

  @override
  String get v1Copy0351 =>
      'Use Sample Archive to explore the product without adding private entries.';

  @override
  String get v1Copy0352 => 'Open support page';

  @override
  String get v1Copy0353 => 'Copy support checklist';

  @override
  String get v1Copy0354 => 'Open Help & reviewer guide';

  @override
  String get v1Copy0355 => 'Open Sample Archive';

  @override
  String get v1Copy0356 => 'Thoughtprint support checklist';

  @override
  String get v1Copy0357 => 'Support checklist copied';

  @override
  String get v1Copy0358 => 'Record a private entry';

  @override
  String get v1Copy0359 => 'See what repeats over time';

  @override
  String get v1Copy0360 => 'Review evidence, not guesses';

  @override
  String get v1Copy0361 => 'Explore your private archive';

  @override
  String get v1Copy0362 => 'Export only when you choose';

  @override
  String get v1Copy0363 => 'Try Sample Archive with example data';

  @override
  String get v1Copy0364 =>
      'Thoughtprint can be tested without microphone access by using Type instead.';

  @override
  String get v1Copy0365 =>
      'Sample Archive uses example data only and does not write to the real journal.';

  @override
  String get v1Copy0366 =>
      'RevenueCat purchases are unavailable until banking setup is complete; the free archive flow remains usable.';

  @override
  String get v1Copy0367 => 'Privacy & data controls are available in Settings.';

  @override
  String get v1Copy0368 => 'Suggested review path';

  @override
  String get v1Copy0369 =>
      'Open Sample Archive for example data that never writes to your journal.';

  @override
  String get v1Copy0370 =>
      'Follow Good demo paths inside Sample Archive for screenshots or demos.';

  @override
  String get v1Copy0371 => 'Support and feedback are available from Settings.';

  @override
  String get v1Copy0372 => 'Privacy for reviewers';

  @override
  String get v1Copy0373 =>
      'Your archive stays on this device. Share-safe summary and export paths never include raw private entries unless you explicitly choose to share them.';

  @override
  String get v1Copy0374 => 'Demo path checklist';

  @override
  String get v1Copy0375 => 'Follow Good demo paths inside Sample Archive';

  @override
  String get v1Copy0376 => 'Open Evidence Map';

  @override
  String get v1Copy0377 => 'Open Work context';

  @override
  String get v1Copy0378 => 'Copy demo summary';

  @override
  String get v1Copy0379 => 'Open Support & feedback for help or issues';

  @override
  String get v1Copy0380 => 'Support URL';

  @override
  String get v1Copy0385 =>
      'Your recordings and reflections are personal. Thoughtprint is private by ';

  @override
  String get v1Copy0386 =>
      'default. Audio and transcript text are sent only when you turn on ';

  @override
  String get v1Copy0387 => 'remote processing for a new entry.';

  @override
  String get v1Copy0388 => 'What can leave this phone';

  @override
  String get v1Copy0389 =>
      'Writing out a recording, or reading it against what you said before, ';

  @override
  String get v1Copy0390 =>
      'only happens off this phone if you turn on remote processing. Sync is ';

  @override
  String get v1Copy0391 =>
      'a different choice: if you sign in and back up, an encrypted copy can ';

  @override
  String get v1Copy0392 =>
      'leave this phone, and the server cannot read it. While remote ';

  @override
  String get v1Copy0393 =>
      'processing is off, those new words are not sent for a transcript or a ';

  @override
  String get v1Copy0397 => 'What stays on your device';

  @override
  String get v1Copy0398 =>
      'Your archive entries, recorded details, action items, surfacing choices, ';

  @override
  String get v1Copy0399 =>
      'memory controls, packs, pins, and collections are stored locally by default. ';

  @override
  String get v1Copy0400 =>
      'Archive metadata and prefs stay on this device as well.';

  @override
  String get v1Copy0401 => 'Cloud transcription and analysis';

  @override
  String get v1Copy0402 =>
      'When remote processing is on, Thoughtprint sends recorded audio for ';

  @override
  String get v1Copy0403 =>
      'transcription and transcript text for reflection. When it is off, ';

  @override
  String get v1Copy0404 =>
      'new entries are recorded on this device only. Anything already recorded ';

  @override
  String get v1Copy0405 => 'stays exactly as it is.';

  @override
  String get v1Copy0406 => 'Optional encrypted backup';

  @override
  String get v1Copy0407 =>
      'If you sign in and enable sync, backup data is encrypted before it is ';

  @override
  String get v1Copy0408 =>
      'uploaded, using a key held on this device. The server stores that ';

  @override
  String get v1Copy0409 => 'backup as ciphertext. Sync is optional.';

  @override
  String get v1Copy0410 => 'What Thoughtprint does not do';

  @override
  String get v1Copy0411 =>
      'Thoughtprint does not sell your reflections. Thoughtprint does not include ';

  @override
  String get v1Copy0412 =>
      'recording text in analytics. Thoughtprint does not turn every entry into ';

  @override
  String get v1Copy0413 =>
      'personal memory by default. Thoughtprint is not therapy, medical advice, ';

  @override
  String get v1Copy0414 => 'or emergency support.';

  @override
  String get v1Copy0415 => 'Ways to mark an entry';

  @override
  String get v1Copy0416 =>
      'You can mark entries as Hypothetical, Not about me, Sensitive, ';

  @override
  String get v1Copy0417 =>
      'Do not surface, Preserve original, Keep separate, or Treat as new.';

  @override
  String get v1Copy0418 => 'Processing providers';

  @override
  String get v1Copy0419 =>
      'Remote processing is off until you turn it on, and these companies ';

  @override
  String get v1Copy0420 =>
      'receive nothing before then. If you turn it on: OpenAI receives a ';

  @override
  String get v1Copy0421 =>
      'along with structured details of the earlier entries it is compared ';

  @override
  String get v1Copy0422 =>
      'against — to draft a reflection. Google receives streamed audio during ';

  @override
  String get v1Copy0423 =>
      'a live conversation, where that feature is available. Encrypted backup ';

  @override
  String get v1Copy0424 =>
      'is separate: sync uploads ciphertext, so the server holds backup data ';

  @override
  String get v1Copy0425 => 'it cannot read.';

  @override
  String get v1Copy0426 => 'Full privacy policy online';

  @override
  String get v1Copy0427 => 'Remote processing';

  @override
  String get v1Copy0428 => 'Send new entries for transcription and reflection';

  @override
  String get v1Copy0429 =>
      'On — a new moment\'s audio and transcript may be sent to transcribe ';

  @override
  String get v1Copy0430 =>
      'and compare it against what you\'ve said before. Turn this off any ';

  @override
  String get v1Copy0431 =>
      'time; anything already recorded stays exactly as it is.';

  @override
  String get v1Copy0432 =>
      'Off — new entries are recorded on this device only. Nothing is sent ';

  @override
  String get v1Copy0433 =>
      'for transcription or reflection until you turn this on.';

  @override
  String get v1Copy0434 => 'Last turned on ';

  @override
  String get v1Copy0435 =>
      'Withdrawing here only changes what happens next — entries already ';

  @override
  String get v1Copy0436 => 'analyzed keep their existing reflection.';

  @override
  String get v1Copy0437 => 'Terms of use';

  @override
  String get v1Copy0438 => 'Last updated: June 2026';

  @override
  String get v1Copy0439 => 'By using Thoughtprint you agree to these terms. ';

  @override
  String get v1Copy0440 =>
      'Thoughtprint helps you notice what keeps repeating in your own words.';

  @override
  String get v1Copy0441 => 'What Thoughtprint is';

  @override
  String get v1Copy0442 =>
      'Thoughtprint is a private archive for your own voice reflections. ';

  @override
  String get v1Copy0443 =>
      'It is not therapy, medical advice, coaching, or emergency support.';

  @override
  String get v1Copy0444 => 'Your content';

  @override
  String get v1Copy0445 =>
      'You keep ownership of what you record. You are responsible for what ';

  @override
  String get v1Copy0446 =>
      'you choose to speak, export, or share outside the app.';

  @override
  String get v1Copy0447 => 'Acceptable use';

  @override
  String get v1Copy0448 =>
      'Do not use Thoughtprint to store illegal content or to harass others. ';

  @override
  String get v1Copy0449 =>
      'Do not attempt to reverse-engineer or abuse app services.';

  @override
  String get v1Copy0450 =>
      'Optional Pro features may be offered by subscription. Free limits may ';

  @override
  String get v1Copy0451 =>
      'change with notice in the app or on the pricing page.';

  @override
  String get v1Copy0452 => 'Limitation of liability';

  @override
  String get v1Copy0453 =>
      'Thoughtprint is a software tool, not a crisis service. Summaries and ';

  @override
  String get v1Copy0454 =>
      'patterns are based on your own words and are not medical or therapeutic ';

  @override
  String get v1Copy0455 =>
      'Require Face ID, Touch ID, or a PIN before opening your archive on this device.';

  @override
  String get v1Copy0456 => 'Export my archive';

  @override
  String get v1Copy0457 =>
      'Download a plain-text copy of your recorded entries.';

  @override
  String get v1Copy0458 =>
      'Permanently remove local entries, drafts, and recordings on this device.';

  @override
  String get v1Copy0459 => 'Cloud and transcription';

  @override
  String get v1Copy0460 => 'What stays on this device';

  @override
  String get v1Copy0461 =>
      'New entries stay on this device until you turn on remote processing.';

  @override
  String get v1Copy0462 =>
      'When remote processing is on, recorded audio is sent for transcription ';

  @override
  String get v1Copy0463 => 'and transcript text is sent for reflection.';

  @override
  String get v1Copy0464 =>
      'When remote processing is off, nothing is sent for new entries — you ';

  @override
  String get v1Copy0465 =>
      'can still record, play back, and type what you said.';

  @override
  String get v1Copy0466 =>
      '    Thoughtprint does not treat your words as instructions. Your words are private content to analyse, not commands to follow.';

  @override
  String get v1Copy0467 => 'Your archive';

  @override
  String get v1Copy0468 => 'Delete entry';

  @override
  String get v1Copy0469 => 'Correct entry';

  @override
  String get v1Copy0470 => 'Export archive';

  @override
  String get v1Copy0471 => 'Review before sharing.';

  @override
  String get v1Copy0472 => 'Nothing to export yet';

  @override
  String get v1Copy0473 =>
      'Record a entry on this device first. Your export will appear here when ';

  @override
  String get v1Copy0474 => 'your archive has something to include.';

  @override
  String get v1Copy0475 =>
      'This is a private summary from Thoughtprint on this device. Tap Share ';

  @override
  String get v1Copy0476 => 'export only when you are ready.';

  @override
  String get v1Copy0477 => 'Thoughtprint private archive export';

  @override
  String get v1Copy0478 => 'Export date';

  @override
  String get v1Copy0479 => 'Recorded entries';

  @override
  String get v1Copy0480 => 'Usable evidence entries';

  @override
  String get v1Copy0481 => 'Current possible pattern';

  @override
  String get v1Copy0482 => 'Evidence map summary';

  @override
  String get v1Copy0483 => 'Weekly review summary';

  @override
  String get v1Copy0484 => 'Recent recorded entries';

  @override
  String get v1Copy0485 => 'This export was created on this device.';

  @override
  String get v1Copy0486 => 'Share export';

  @override
  String get v1Copy0487 => 'Sharing…';

  @override
  String get v1Copy0488 => 'Thoughtprint archive export';

  @override
  String get v1Copy0489 => 'Recorded locally — preview not available yet.';

  @override
  String get v1Copy0491 => 'Subscription & billing';

  @override
  String get v1Copy0492 => 'Current plan';

  @override
  String get v1Copy0493 => 'Thoughtprint Pro';

  @override
  String get v1Copy0494 =>
      'Full historical comparisons, weekly archive reviews, and the complete evidence trail across your archive.';

  @override
  String get v1Copy0495 =>
      'Record entries and keep the evidence trail on your recent entries. Upgrade for Tier 2 historical analysis.';

  @override
  String get v1Copy0496 => 'Pro pricing';

  @override
  String get v1Copy0498 => 'Manage subscription';

  @override
  String get v1Copy0499 =>
      'Update payment, switch plans, or cancel anytime in your App Store or Google Play subscription settings — no email required.';

  @override
  String get v1Copy0500 => 'Open subscription settings';

  @override
  String get v1Copy0501 => 'Cancel anytime';

  @override
  String get v1Copy0502 =>
      'Cancellation takes effect at the end of your current billing period. You keep Pro access until then, and your recorded entries stay on this device.';

  @override
  String get v1Copy0503 => 'How to cancel';

  @override
  String get v1Copy0504 => 'Open Settings on your iPhone';

  @override
  String get v1Copy0505 => 'Tap your Apple ID → Subscriptions';

  @override
  String get v1Copy0506 => 'Select Thoughtprint Pro → Cancel Subscription';

  @override
  String get v1Copy0507 => 'Open Google Play Store';

  @override
  String get v1Copy0508 =>
      'Tap Profile → Payments & subscriptions → Subscriptions';

  @override
  String get v1Copy0509 => 'Select Thoughtprint Pro → Cancel subscription';

  @override
  String get v1Copy0511 =>
      'Already subscribed on this Apple ID or Google account? Restore to re-link Pro on this device.';

  @override
  String get v1Copy0512 => 'Upgrade to Pro';

  @override
  String get v1Copy0513 => 'See Pro plans';

  @override
  String get v1Copy0514 =>
      'Purchases are not configured on this build. You can keep using Thoughtprint on the free tier.';

  @override
  String get v1Copy0515 => 'Trust & transparency';

  @override
  String get v1Copy0516 => 'The Evidence Guarantee';

  @override
  String get v1Copy0517 =>
      'Your trust mechanism and citation trails are never paywalled.';

  @override
  String get v1Copy0518 => 'Management & support';

  @override
  String get v1Copy0519 => 'Cancel subscription';

  @override
  String get v1Copy0520 =>
      'Manage or cancel your plan anytime with zero dark patterns.';

  @override
  String get v1Copy0521 => 'Human billing support';

  @override
  String get v1Copy0522 =>
      'Guaranteed human response path for any billing disputes.';

  @override
  String get v1Copy0523 => 'support@thoughtprint.xyz';

  @override
  String get v1Copy0524 => 'Thoughtprint Pro Active';

  @override
  String get v1Copy0525 => 'Free Tier (Evidence Capped)';

  @override
  String get v1Copy0526 => 'https://apps.apple.com/account/subscriptions';

  @override
  String get v1Copy0527 =>
      'https://play.google.com/store/account/subscriptions';

  @override
  String get v1Copy0528 => 'Testing Thoughtprint?';

  @override
  String get v1Copy0529 => 'Send feedback';

  @override
  String get v1Copy0530 => 'Tester guidance is not available in this build.';

  @override
  String get v1Copy0531 => 'hello@thoughtprint.xyz';

  @override
  String get v1Copy0532 => 'Thoughtprint TestFlight feedback';

  @override
  String get v1Copy0533 =>
      'Could not open email. Please send feedback to hello@thoughtprint.xyz.';

  @override
  String get v1Copy0535 => 'Your entry is recorded on this device.';

  @override
  String get v1Copy0536 => 'Record one real entry.';

  @override
  String get v1Copy0537 => 'Ten seconds is enough.';

  @override
  String get v1Copy0538 => 'See an example';

  @override
  String get v1Copy0539 => 'Use seeExampleLink';

  @override
  String get v1Copy0540 => 'Before you record';

  @override
  String get v1Copy0542 => 'Or start with: a pressure entry';

  @override
  String get v1Copy0543 =>
      'Not chat history — patterns only appear when your own words repeat.';

  @override
  String get v1Copy0545 => 'Start your archive';

  @override
  String get v1Copy0546 => 'Notice what repeats';

  @override
  String get v1Copy0547 => 'Watch what changes';

  @override
  String get v1Copy0548 => 'Thoughtprint is starting to notice';

  @override
  String get v1Copy0549 => 'Each entry helps Thoughtprint remember the pattern';

  @override
  String get v1Copy0550 => 'starting to notice';

  @override
  String get v1Copy0551 => 'I kept checking even after I was done.';

  @override
  String get v1Copy0552 => 'I avoided replying again.';

  @override
  String get v1Copy0553 => 'I felt pressure before starting.';

  @override
  String get v1Copy0554 => '1 of 3 · Ten seconds is enough.';

  @override
  String get v1Copy0555 =>
      'Free shows the first useful repeat. Pro keeps the longer trail.';

  @override
  String get v1Copy0556 => 'possible pattern';

  @override
  String get v1Copy0557 => 'Record the entry. See what returns.';

  @override
  String get v1Copy0558 =>
      'Record a voice or typed entry in your own words. Over time, Thoughtprint ';

  @override
  String get v1Copy0559 =>
      'may show what repeats — with the entries behind it.';

  @override
  String get v1Copy0560 => 'First entry recorded';

  @override
  String get v1Copy0561 =>
      'Come back when this shows up again. Thoughtprint has one entry to compare later.';

  @override
  String get v1Copy0562 => 'https://thoughtprint.xyz/privacy';

  @override
  String get v1Copy0563 => 'https://thoughtprint.xyz/contact';

  @override
  String get v1Copy0564 =>
      'Thoughtprint could not open your private archive on this device. ';

  @override
  String get v1Copy0565 =>
      'Try restarting the app. If this keeps happening, reinstall from the App Store.';

  @override
  String get v1Copy0566 =>
      'Catch the loop where doing more never feels like enough.';

  @override
  String get v1Copy0567 =>
      'Record short entries. Thoughtprint helps you test whether pressure, productivity, and enoughness keep repeating.';

  @override
  String get v1Copy0568 =>
      'Thoughtprint helps you catch the proving loop earlier next time.';

  @override
  String get v1Copy0569 => 'Record one entry. Test whether the loop repeats.';

  @override
  String get v1Copy0570 =>
      'Not a chat history. An evidence trail of what repeats.';

  @override
  String get v1Copy0571 => 'See what changed across days and weeks.';

  @override
  String get v1Copy0572 => 'Find the entries that mattered.';

  @override
  String get v1Copy0573 => 'Every pattern makes the pattern clearer.';

  @override
  String get v1Copy0574 => 'Based on entries across days and weeks.';

  @override
  String get v1Copy0575 => 'See how this has changed over time.';

  @override
  String get v1Copy0576 =>
      'Record a few real entries. Thoughtprint will look for what repeats across them.';

  @override
  String get v1Copy0577 => 'Record one entry';

  @override
  String get v1Copy0579 => 'Catch your first proving loop';

  @override
  String get v1Copy0580 =>
      'Record a entry where you kept doing more because stopping made you feel behind, guilty, or not enough.';

  @override
  String get v1Copy0581 => 'Start with this:';

  @override
  String get v1Copy0582 =>
      'When did you feel pressure to do more to feel okay?';

  @override
  String get v1Copy0583 => 'Record this entry';

  @override
  String get v1Copy0584 => 'Want a reminder to test this?';

  @override
  String get v1Copy0585 =>
      'Thoughtprint can remind you to record the next evidence entry.';

  @override
  String get v1Copy0586 => 'Remind me tomorrow';

  @override
  String get v1Copy0588 => 'Was this read useful?';

  @override
  String get v1Copy0589 => 'Not quite';

  @override
  String get v1Copy0590 => 'Did this feel specific to what you recorded?';

  @override
  String get v1Copy0591 => 'Yes, specific';

  @override
  String get v1Copy0592 => 'Too generic';

  @override
  String get v1Copy0593 => 'Wrong angle';

  @override
  String get v1Copy0594 =>
      'Do not treat this as true yet. Use the next entry to test it.';

  @override
  String get v1Copy0595 =>
      'Try one more entry with what happened, what you did, and what felt heavy.';

  @override
  String get v1Copy0596 => 'This may be the loop to watch';

  @override
  String get v1Copy0597 => 'Thoughtprint found a possible decision loop';

  @override
  String get v1Copy0598 => 'This could be the pattern starting to show';

  @override
  String get v1Copy0599 =>
      'Pick the read that feels closest. Thoughtprint sharpens from what you choose.';

  @override
  String get v1Copy0600 => 'Possible loop';

  @override
  String get v1Copy0601 => 'Evidence used';

  @override
  String get v1Copy0602 => 'What would confirm it';

  @override
  String get v1Copy0603 => 'What would prove it wrong';

  @override
  String get v1Copy0604 => 'Next evidence prompt';

  @override
  String get v1Copy0605 => 'What pattern do you want to catch?';

  @override
  String get v1Copy0606 => 'Reminder not available in this build.';

  @override
  String get v1Copy0607 => 'Record next evidence';

  @override
  String get v1Copy0608 =>
      'Thoughtprint is watching whether this signal repeats.';

  @override
  String get v1Copy0610 => 'Continue the signal journey';

  @override
  String get v1Copy0612 => 'View journey';

  @override
  String get v1Copy0613 => 'Evidence recorded for today';

  @override
  String get v1Copy0614 => 'View what changed';

  @override
  String get v1Copy0615 =>
      'Each entry helps Thoughtprint remember the pattern.';

  @override
  String get v1Copy0616 => 'How Thoughtprint builds evidence';

  @override
  String get v1Copy0617 => 'Day 1: “I said yes before checking what I needed.”';

  @override
  String get v1Copy0618 => 'Day 3: “It showed up again before a work message.”';

  @override
  String get v1Copy0619 => 'Day 7: “It felt lighter after I paused.”';

  @override
  String get v1Copy0620 =>
      'Thoughtprint watches what repeats — from your own words.';

  @override
  String get v1Copy0621 => 'What your archive will show';

  @override
  String get v1Copy0622 =>
      'Over time, Thoughtprint can show what returned, what changed, and what helped.';

  @override
  String get v1Copy0623 => 'Thoughtprint remembers what keeps returning.';

  @override
  String get v1Copy0624 => 'Record next entry';

  @override
  String get v1Copy0630 => 'WHEN PATTERNS CONFLICT';

  @override
  String get v1Copy0631 => 'WHAT MAY HAPPEN NEXT';

  @override
  String get v1Copy0632 => 'SOMETHING WORTH NOTICING';

  @override
  String get v1Copy0633 =>
      'Record one more clear entry and Thoughtprint can compare what repeats.';

  @override
  String get v1Copy0634 => 'View recorded entry';

  @override
  String get v1Copy0635 => 'Examples of patterns you may notice later';

  @override
  String get v1Copy0636 => 'A entry that keeps showing up';

  @override
  String get v1Copy0637 => 'What felt lighter today';

  @override
  String get v1Copy0638 => 'What changed after you paused';

  @override
  String get v1Copy0639 => 'Record one clear entry';

  @override
  String get v1Copy0640 => 'Thoughtprint connects entries that keep showing up';

  @override
  String get v1Copy0641 => 'You see what is strengthening, fading, or changing';

  @override
  String get v1Copy0649 => 'Quiet patterns';

  @override
  String get v1Copy0650 => 'What is changing';

  @override
  String get v1Copy0651 =>
      'Stories about patterns that may be strengthening, fading, or shifting — ';

  @override
  String get v1Copy0652 => 'not conclusions.';

  @override
  String get v1Copy0653 => 'You can correct or hide this.';

  @override
  String get v1Copy0654 =>
      'When you have enough reflections, you will see stories here — not charts.';

  @override
  String get v1Copy0655 => 'Based on your reflections';

  @override
  String get v1Copy0656 => 'Why you may be seeing this';

  @override
  String get v1Copy0657 => 'Why it matters';

  @override
  String get v1Copy0658 => 'In your own words';

  @override
  String get v1Copy0659 => 'Entries you mentioned';

  @override
  String get v1Copy0660 => 'What this may mean';

  @override
  String get v1Copy0661 => 'Entries from your reflections';

  @override
  String get v1Copy0662 => 'What this may mean for you';

  @override
  String get v1Copy0663 => 'Based on your recent reflections';

  @override
  String get v1Copy0664 => 'Add a reflection';

  @override
  String get v1Copy0665 => 'Each new entry helps surface what keeps repeating.';

  @override
  String get v1Copy0669 => 'Try saying:';

  @override
  String get v1Copy0670 => 'Show more prompt ideas';

  @override
  String get v1Copy0673 => 'Keep adding reflections to sharpen your patterns.';

  @override
  String get v1Copy0674 => 'Something repeating';

  @override
  String get v1Copy0675 => 'What has been looping in your head today?';

  @override
  String get v1Copy0676 => 'What felt heavy or unresolved this week?';

  @override
  String get v1Copy0677 => 'What entry showed up again today?';

  @override
  String get v1Copy0678 => 'What would feel like a relief if it changed?';

  @override
  String get v1Copy0679 => 'What decision are you avoiding?';

  @override
  String get v1Copy0680 => 'What did you react strongly to recently?';

  @override
  String get v1Copy0681 => 'What are you worried might happen?';

  @override
  String get v1Copy0682 => 'What keeps repeating in this situation?';

  @override
  String get v1Copy0683 => 'Reflection recorded';

  @override
  String get v1Copy0684 => 'A pattern may be forming';

  @override
  String get v1Copy0685 => 'How clear it feels';

  @override
  String get v1Copy0686 => 'First signal recorded';

  @override
  String get v1Copy0687 =>
      'Record once more tomorrow to make the pattern clearer.';

  @override
  String get v1Copy0689 => 'Thoughtprint noticed possible signals';

  @override
  String get v1Copy0690 =>
      'Pick the one that feels closest. Thoughtprint gets sharper from what you choose.';

  @override
  String get v1Copy0691 => 'This feels true';

  @override
  String get v1Copy0692 => 'Not me';

  @override
  String get v1Copy0693 => 'Go deeper';

  @override
  String get v1Copy0694 => 'What this might mean';

  @override
  String get v1Copy0695 => 'What would contradict it';

  @override
  String get v1Copy0696 => 'A better question to record next';

  @override
  String get v1Copy0697 => 'Show another angle';

  @override
  String get v1Copy0698 => 'Another way to read this';

  @override
  String get v1Copy0699 =>
      'Thoughtprint can look at the same entry from a different angle.';

  @override
  String get v1Copy0700 => 'Recorded as evidence.';

  @override
  String get v1Copy0701 => 'From your entry';

  @override
  String get v1Copy0702 => 'Why Thoughtprint suggested this';

  @override
  String get v1Copy0703 => 'Evidence Thoughtprint used';

  @override
  String get v1Copy0704 => 'Thoughtprint needs one clearer entry';

  @override
  String get v1Copy0705 =>
      'Say what happened, what you did, and what felt heavy. Thoughtprint works best with one concrete entry.';

  @override
  String get v1Copy0706 => 'Which read feels closer?';

  @override
  String get v1Copy0707 => 'A feels closer';

  @override
  String get v1Copy0708 => 'B feels closer';

  @override
  String get v1Copy0709 => 'Thoughtprint will use that as evidence.';

  @override
  String get v1Copy0710 => 'Record this next';

  @override
  String get v1Copy0711 => 'Use this prompt';

  @override
  String get v1Copy0712 => 'Choose another prompt';

  @override
  String get v1Copy0713 => 'Next prompt recorded';

  @override
  String get v1Copy0715 => 'Thoughtprint has a possible read';

  @override
  String get v1Copy0716 =>
      'This may not be final, but these entries seem connected.';

  @override
  String get v1Copy0717 => 'The pattern might be';

  @override
  String get v1Copy0718 => 'Evidence so far';

  @override
  String get v1Copy0719 => 'What to watch next';

  @override
  String get v1Copy0720 => 'This feels right';

  @override
  String get v1Copy0722 => 'What would make this clearer';

  @override
  String get v1Copy0724 => 'Record one more entry to test whether it repeats.';

  @override
  String get v1Copy0725 => 'No recorded signal yet';

  @override
  String get v1Copy0726 =>
      'Record a entry and choose the read that feels closest.';

  @override
  String get v1Copy0727 => 'Signal detail';

  @override
  String get v1Copy0728 => 'What Thoughtprint thinks this may be';

  @override
  String get v1Copy0729 => 'Your feedback';

  @override
  String get v1Copy0730 => 'Another angle';

  @override
  String get v1Copy0731 => 'View evidence trail';

  @override
  String get v1Copy0732 => 'Mark not me';

  @override
  String get v1Copy0733 => 'View signal detail';

  @override
  String get v1Copy0734 => 'Needs more evidence';

  @override
  String get v1Copy0735 =>
      'Thoughtprint needs at least two entries before this trail is useful.';

  @override
  String get v1Copy0736 => 'Supporting entries';

  @override
  String get v1Copy0737 => 'Possible contradictions';

  @override
  String get v1Copy0738 => 'Thoughtprint is watching';

  @override
  String get v1Copy0739 =>
      'Record a entry and Thoughtprint will start watching for repeats.';

  @override
  String get v1Copy0740 => 'Record evidence';

  @override
  String get v1Copy0741 => 'Possible read';

  @override
  String get v1Copy0742 => 'What you corrected';

  @override
  String get v1Copy0743 => 'Rejected reads';

  @override
  String get v1Copy0744 => 'Selected alternative';

  @override
  String get v1Copy0745 =>
      'Thoughtprint will avoid showing this first unless stronger evidence appears.';

  @override
  String get v1Copy0746 => 'Thoughtprint will use this as feedback.';

  @override
  String get v1Copy0747 => 'Your archive right now';

  @override
  String get v1Copy0748 =>
      'Thoughtprint is watching for what repeats, changes, or fades.';

  @override
  String get v1Copy0749 => 'Record one more entry to sharpen the signal.';

  @override
  String get v1Copy0750 => 'Signal being watched';

  @override
  String get v1Copy0751 => 'Evidence entries';

  @override
  String get v1Copy0752 => 'Signal journey';

  @override
  String get v1Copy0755 =>
      'Record one more entry to test whether this repeats.';

  @override
  String get v1Copy0756 =>
      'Thoughtprint has enough entries to watch this signal.';

  @override
  String get v1Copy0757 => 'Working signal';

  @override
  String get v1Copy0758 => 'Getting clearer';

  @override
  String get v1Copy0759 => 'Confirmed enough to watch';

  @override
  String get v1Copy0760 => 'Evidence mixed';

  @override
  String get v1Copy0761 => 'No active signal journey yet';

  @override
  String get v1Copy0762 =>
      'Record a entry and choose a read that feels closest.';

  @override
  String get v1Copy0763 => 'What would challenge it';

  @override
  String get v1Copy0764 => 'Archive this signal';

  @override
  String get v1Copy0765 => 'This signal is getting clear';

  @override
  String get v1Copy0766 =>
      'Thoughtprint has seen this across 3 entries. It may be worth watching.';

  @override
  String get v1Copy0767 => 'What repeated';

  @override
  String get v1Copy0769 =>
      'No strong contradictions yet — the read held across entries.';

  @override
  String get v1Copy0770 =>
      'Some entries did not fit this read — Thoughtprint is keeping both sides.';

  @override
  String get v1Copy0771 =>
      'Notice whether the same theme shows up in your next entry.';

  @override
  String get v1Copy0772 => 'Keep watching';

  @override
  String get v1Copy0773 => 'View pattern';

  @override
  String get v1Copy0774 => 'Active signal journey';

  @override
  String get v1Copy0775 => 'Thoughtprint reviewed this signal';

  @override
  String get v1Copy0776 => 'What could show this is wrong';

  @override
  String get v1Copy0777 => 'Correct this';

  @override
  String get v1Copy0778 => 'View full review';

  @override
  String get v1Copy0779 => 'Confirm pattern';

  @override
  String get v1Copy0780 => 'Correct the read';

  @override
  String get v1Copy0781 => 'No signal review yet';

  @override
  String get v1Copy0782 =>
      'Collect 3 entries in a signal journey and Thoughtprint will review what is becoming clearer.';

  @override
  String get v1Copy0783 =>
      'Thoughtprint needs more evidence before it can review this signal.';

  @override
  String get v1Copy0784 =>
      'Recorded. Thoughtprint will use this correction when it reads future entries.';

  @override
  String get v1Copy0785 => 'Recorded as a pattern to watch.';

  @override
  String get v1Copy0786 => 'Thoughtprint will keep watching this signal.';

  @override
  String get v1Copy0787 => 'Pick a closer read';

  @override
  String get v1Copy0788 => 'Ready to review';

  @override
  String get v1Copy0789 => 'Confirmed pattern';

  @override
  String get v1Copy0790 => 'Corrected read';

  @override
  String get v1Copy0791 => 'Still watching';

  @override
  String get v1Copy0793 =>
      'No strong contradictions yet — the read may still hold.';

  @override
  String get v1Copy0794 =>
      'Some entries may not fit this read — worth watching both sides.';

  @override
  String get v1Copy0795 =>
      'A entry that clearly goes the other way would test this read.';

  @override
  String get v1Copy0796 => 'Record one more entry on the same theme.';

  @override
  String get v1Copy0797 => 'Thoughtprint found a possible repeat';

  @override
  String get v1Copy0798 => 'This looks close to something you recorded before.';

  @override
  String get v1Copy0799 => 'You may be doing more to avoid feeling behind.';

  @override
  String get v1Copy0800 =>
      'This time, the pressure showed up around saying yes too quickly.';

  @override
  String get v1Copy0801 =>
      'Before saying yes, see whether this entry fits the archive.';

  @override
  String get v1Copy0803 => 'That gives Thoughtprint better evidence to watch.';

  @override
  String get v1Copy0804 => 'What Thoughtprint is watching next';

  @override
  String get v1Copy0805 => 'Not the same';

  @override
  String get v1Copy0806 =>
      'Thoughtprint needs one more entry to compare this properly.';

  @override
  String get v1Copy0807 =>
      'Early take — it gets clearer as you add more reflections.';

  @override
  String get v1Copy0808 => 'A pattern that may be forming';

  @override
  String get v1Copy0809 =>
      'Keep recording — patterns get clearer with more entries.';

  @override
  String get v1Copy0810 => 'Entries you mentioned:';

  @override
  String get v1Copy0811 => 'Show entries';

  @override
  String get v1Copy0812 => 'Hide entries';

  @override
  String get v1Copy0818 => 'Recorded privately on this device.';

  @override
  String get v1Copy0819 => 'Add one more entry tomorrow to make this clearer.';

  @override
  String get v1Copy0820 => 'Export data';

  @override
  String get v1Copy0822 => 'At a glance';

  @override
  String get v1Copy0823 => 'Patterns noticed';

  @override
  String get v1Copy0824 => 'Strongest pattern';

  @override
  String get v1Copy0825 => 'Reflections counted';

  @override
  String get v1Copy0826 => 'Days with reflections';

  @override
  String get v1Copy0827 => 'Record your patterns with email sign-in.';

  @override
  String get v1Copy0828 => 'Record my patterns';

  @override
  String get v1Copy0829 => 'Export reflections';

  @override
  String get v1Copy0830 => 'App version';

  @override
  String get v1Copy0832 =>
      'Pro keeps a longer private archive — more entries, more continuity, more evidence over time.';

  @override
  String get v1Copy0834 => 'More archived entries over weeks and months';

  @override
  String get v1Copy0837 =>
      'Your entries stay free. Manage or cancel anytime in the App Store.';

  @override
  String get v1Copy0838 =>
      'You are building evidence over time. Pro keeps the longer archive trail as entries return, change, or fade.';

  @override
  String get v1Copy0841 =>
      'Longer archive trail, what returned or changed, and evidence over time ';

  @override
  String get v1Copy0842 => 'are available on this device.';

  @override
  String get v1Copy0845 => 'Your pattern memory is growing.';

  @override
  String get v1Copy0846 =>
      'During the focused beta, every entry you record stays on this device. ';

  @override
  String get v1Copy0847 =>
      'There is no entry cap, no upgrade, and no purchase flow.';

  @override
  String get v1Copy0848 =>
      'Saving to your archive, plus search, export, correction, and deletion, ';

  @override
  String get v1Copy0849 =>
      'are fully available in the beta without a subscription.';

  @override
  String get v1Copy0850 => 'Free keeps your first 7 key entries.';

  @override
  String get v1Copy0851 =>
      'Pro keeps the longer archive trail across weeks and months.';

  @override
  String get v1Copy0852 => 'See deeper history';

  @override
  String get v1Copy0853 =>
      'This may be changing — this pattern appears more often';

  @override
  String get v1Copy0854 =>
      'This may be changing — this pattern appears less often';

  @override
  String get v1Copy0855 => 'Your archive noticed a possible new pattern';

  @override
  String get v1Copy0856 => 'This may be changing — this pattern is shifting';

  @override
  String get v1Copy0857 => 'A few more entries help';

  @override
  String get v1Copy0858 => 'Search your entries';

  @override
  String get v1Copy0859 =>
      'Find recorded entries after you record a few real ones.';

  @override
  String get v1Copy0860 => 'Need an idea?';

  @override
  String get v1Copy0861 => 'THOUGHTPRINT NOTICED';

  @override
  String get v1Copy0862 => 'Today Thoughtprint noticed';

  @override
  String get v1Copy0863 => 'Use archiveMeNoticedHeading';

  @override
  String get v1Copy0864 => 'Use archiveMeNoticedTitle';

  @override
  String get v1Copy0865 =>
      'Your reflection will appear in Patterns when finished.';

  @override
  String get v1Copy0866 => 'Something worth noticing';

  @override
  String get v1Copy0867 => 'Come back tomorrow';

  @override
  String get v1Copy0868 => 'COME BACK TOMORROW';

  @override
  String get v1Copy0869 => 'What Thoughtprint will pattern next';

  @override
  String get v1Copy0870 => 'Today it noticed…';

  @override
  String get v1Copy0871 => 'Next time, watch for…';

  @override
  String get v1Copy0872 => 'What to watch for next time';

  @override
  String get v1Copy0873 => 'One more reflection makes this clearer.';

  @override
  String get v1Copy0874 =>
      'One reflection is a entry. A few reflections start to show what repeats.';

  @override
  String get v1Copy0875 =>
      'Tomorrow, add one more reflection and Thoughtprint can compare it with today.';

  @override
  String get v1Copy0876 =>
      'Thoughtprint can see whether the same pattern shows up again.';

  @override
  String get v1Copy0877 => 'Record again tomorrow to see what repeats.';

  @override
  String get v1Copy0878 => 'If this shows up again, it may be a pattern.';

  @override
  String get v1Copy0879 => 'same worry';

  @override
  String get v1Copy0880 => 'same person';

  @override
  String get v1Copy0881 => 'same time of day';

  @override
  String get v1Copy0882 => 'Tomorrow, notice whether this shows up again.';

  @override
  String get v1Copy0884 => 'Thoughtprint compares what you record over time.';

  @override
  String get v1Copy0886 => 'Record another reflection';

  @override
  String get v1Copy0887 =>
      'Want Thoughtprint to look at this pattern again tomorrow?';

  @override
  String get v1Copy0888 =>
      'Record a simple reminder for tomorrow. When you come back, Thoughtprint ';

  @override
  String get v1Copy0889 => 'can compare what repeats.';

  @override
  String get v1Copy0890 => 'Come back tomorrow to see what changed.';

  @override
  String get v1Copy0891 =>
      'Notice what shows up again in your next reflection.';

  @override
  String get v1Copy0892 => 'You came back';

  @override
  String get v1Copy0893 => 'Yesterday you were watching for:';

  @override
  String get v1Copy0894 => 'This gives Thoughtprint better evidence.';

  @override
  String get v1Copy0895 => 'You kept the loop going.';

  @override
  String get v1Copy0896 => 'Thoughtprint can now compare today with yesterday.';

  @override
  String get v1Copy0897 => 'Watch for this tomorrow';

  @override
  String get v1Copy0898 => 'Use this tomorrow';

  @override
  String get v1Copy0899 => 'Choose another';

  @override
  String get v1Copy0900 =>
      'Recorded for tomorrow. Thoughtprint will ask if it shows up again.';

  @override
  String get v1Copy0901 => 'Today, watch for this';

  @override
  String get v1Copy0902 => 'When you record, notice';

  @override
  String get v1Copy0903 => 'Record what happened';

  @override
  String get v1Copy0904 => 'Skip this';

  @override
  String get v1Copy0905 => 'It showed up again.';

  @override
  String get v1Copy0906 => 'It did not show up today.';

  @override
  String get v1Copy0907 => 'It changed shape.';

  @override
  String get v1Copy0908 => 'It felt lighter today.';

  @override
  String get v1Copy0909 => 'It felt heavier today.';

  @override
  String get v1Copy0910 => 'Something changed today.';

  @override
  String get v1Copy0911 => 'Thoughtprint needs one more entry.';

  @override
  String get v1Copy0912 => 'can compare it with what you were watching for.';

  @override
  String get v1Copy0913 => 'Compared with yesterday';

  @override
  String get v1Copy0914 => 'What you were watching for yesterday';

  @override
  String get v1Copy0915 => 'What showed up today';

  @override
  String get v1Copy0916 => 'A short reflection from today.';

  @override
  String get v1Copy0917 => 'That pattern showed up again.';

  @override
  String get v1Copy0918 => 'The pattern changed shape.';

  @override
  String get v1Copy0919 => 'It sounded lighter today.';

  @override
  String get v1Copy0920 => 'That pattern was not there today.';

  @override
  String get v1Copy0921 => 'One more entry will make this clearer.';

  @override
  String get v1Copy0922 => 'before comparing it properly.';

  @override
  String get v1Copy0923 => 'showed up again';

  @override
  String get v1Copy0924 => 'changed shape';

  @override
  String get v1Copy0925 => 'lighter today';

  @override
  String get v1Copy0926 => 'not there today';

  @override
  String get v1Copy0927 => 'need another entry';

  @override
  String get v1Copy0928 => 'You came back today.';

  @override
  String get v1Copy0929 =>
      'One return gives Thoughtprint a starting point to compare.';

  @override
  String get v1Copy0934 => 'That gives Thoughtprint more to compare.';

  @override
  String get v1Copy0935 => 'This pattern is still here.';

  @override
  String get v1Copy0936 => 'This pattern may be getting stronger.';

  @override
  String get v1Copy0937 => 'This pattern eased a little.';

  @override
  String get v1Copy0938 => 'This pattern changed shape.';

  @override
  String get v1Copy0939 => 'Still taking shape.';

  @override
  String get v1Copy0940 =>
      'Today was too short to say much yet. One more entry will sharpen the comparison.';

  @override
  String get v1Copy0941 => 'got stronger';

  @override
  String get v1Copy0942 => 'same pressure';

  @override
  String get v1Copy0943 => 'watch tomorrow';

  @override
  String get v1Copy0945 => 'Your return loop';

  @override
  String get v1Copy0946 => 'What Thoughtprint noticed today';

  @override
  String get v1Copy0947 => 'Why come back tomorrow';

  @override
  String get v1Copy0948 => 'Continue this pattern';

  @override
  String get v1Copy0949 => 'Pause this';

  @override
  String get v1Copy0951 => 'Last checked';

  @override
  String get v1Copy0952 => 'Next time, watch for';

  @override
  String get v1Copy0954 =>
      'Thoughtprint is tracking this pattern across your entries.';

  @override
  String get v1Copy0955 => 'FIRST PATTERN';

  @override
  String get v1Copy0956 => 'A pattern may be starting.';

  @override
  String get v1Copy0957 => 'Something may be worth watching.';

  @override
  String get v1Copy0958 => 'This could be a few things.';

  @override
  String get v1Copy0959 => 'Choose what feels closer';

  @override
  String get v1Copy0960 => 'Tomorrow, look at this pattern';

  @override
  String get v1Copy0961 =>
      'A good pattern is specific enough to answer tomorrow.';

  @override
  String get v1Copy0962 => 'Make it sharper';

  @override
  String get v1Copy0963 =>
      'Choose the question you would actually want answered tomorrow.';

  @override
  String get v1Copy0964 =>
      'Choose the question you would actually care to answer tomorrow.';

  @override
  String get v1Copy0965 => 'Most direct';

  @override
  String get v1Copy0966 => 'Go one step deeper';

  @override
  String get v1Copy0967 =>
      'If today felt obvious, this is the more useful question to sit with.';

  @override
  String get v1Copy0968 => 'Next useful pattern';

  @override
  String get v1Copy0969 => 'Choose a different pattern';

  @override
  String get v1Copy0970 => 'Tomorrow\\u2019s check is set.';

  @override
  String get v1Copy0971 => 'Pick a pattern for tomorrow';

  @override
  String get v1Copy0972 => 'What happens right before it shows up?';

  @override
  String get v1Copy0973 => 'What helped make it lighter?';

  @override
  String get v1Copy0974 => 'What made it heavier?';

  @override
  String get v1Copy0975 => 'Use this pattern';

  @override
  String get v1Copy0976 => 'Useful takeaway';

  @override
  String get v1Copy0977 => 'Next pattern';

  @override
  String get v1Copy0978 => 'Make this more useful';

  @override
  String get v1Copy0979 => 'What would make this more useful?';

  @override
  String get v1Copy0980 => 'More specific';

  @override
  String get v1Copy0981 => 'More accurate';

  @override
  String get v1Copy0982 => 'More next step';

  @override
  String get v1Copy0983 => 'Easier to understand';

  @override
  String get v1Copy0984 =>
      'Add one clear entry so Thoughtprint can find a better pattern.';

  @override
  String get v1Copy0985 => 'Add one sentence';

  @override
  String get v1Copy0986 => 'Use it anyway';

  @override
  String get v1Copy0987 => 'Add one sentence\\u2026';

  @override
  String get v1Copy0988 => 'Early read';

  @override
  String get v1Copy0989 => 'This may get sharper after one more clear entry.';

  @override
  String get v1Copy0990 => 'Add another entry';

  @override
  String get v1Copy0991 => 'Add one more clear entry to make this more useful.';

  @override
  String get v1Copy0992 => 'What exact entry did this show up?';

  @override
  String get v1Copy0993 => 'Not quite?';

  @override
  String get v1Copy0994 =>
      'Got it — Thoughtprint will use this pattern for tomorrow.';

  @override
  String get v1Copy0995 => 'Which feels closer?';

  @override
  String get v1Copy0996 => 'Something else';

  @override
  String get v1Copy0997 =>
      'Tomorrow Thoughtprint will ask this exact question.';

  @override
  String get v1Copy0998 => 'Your pattern from yesterday';

  @override
  String get v1Copy0999 => 'You only need to answer what happened today.';

  @override
  String get v1Copy1000 => 'Yesterday you chose this pattern:';

  @override
  String get v1Copy1001 => 'Today, what happened?';

  @override
  String get v1Copy1002 =>
      'Now add one entry so Thoughtprint can compare today with yesterday.';

  @override
  String get v1Copy1003 => 'Short is fine. One sentence is enough.';

  @override
  String get v1Copy1004 => 'Need examples?';

  @override
  String get v1Copy1005 => 'Now record one short entry.';

  @override
  String get v1Copy1006 => 'One sentence is enough.';

  @override
  String get v1Copy1007 => 'Record one sentence';

  @override
  String get v1Copy1008 => 'Want a reminder tomorrow?';

  @override
  String get v1Copy1009 =>
      'We can remind you when tomorrow\\u2019s check is ready.';

  @override
  String get v1Copy1010 => 'Remind me';

  @override
  String get v1Copy1011 => 'Reminder set for tomorrow.';

  @override
  String get v1Copy1012 => 'No problem. Your pattern is still recorded.';

  @override
  String get v1Copy1013 => 'Pattern reminders';

  @override
  String get v1Copy1014 =>
      'Get a reminder when tomorrow\\u2019s check is ready.';

  @override
  String get v1Copy1015 =>
      'You will get a reminder when tomorrow\\u2019s check is ready.';

  @override
  String get v1Copy1016 =>
      'Turn on notifications to get your pattern reminder.';

  @override
  String get v1Copy1017 => 'Permission needed';

  @override
  String get v1Copy1018 => 'Pick the closest answer. You can keep it short.';

  @override
  String get v1Copy1019 => 'It showed up';

  @override
  String get v1Copy1020 => 'It did not show up';

  @override
  String get v1Copy1021 => 'Other answers';

  @override
  String get v1Copy1022 => 'What this means';

  @override
  String get v1Copy1023 => 'You closed the loop.';

  @override
  String get v1Copy1024 => 'What was wrong?';

  @override
  String get v1Copy1025 => 'Pattern waiting';

  @override
  String get v1Copy1026 => 'Thoughtprint has a question from your last entry.';

  @override
  String get v1Copy1029 =>
      'Yesterday you chose a pattern. Today you answered it.';

  @override
  String get v1Copy1030 => 'Does this feel worth checking tomorrow?';

  @override
  String get v1Copy1031 => 'Was this useful?';

  @override
  String get v1Copy1032 => 'What got in the way?';

  @override
  String get v1Copy1033 => 'No clear pattern yet';

  @override
  String get v1Copy1034 =>
      'Keep recording short reflections. Patterns become clearer after a few entries.';

  @override
  String get v1Copy1035 => 'When it comes back, we show you the words.';

  @override
  String get v1Copy1036 =>
      'Thoughtprint is a private voice archive of what you actually said. ';

  @override
  String get v1Copy1037 =>
      'When a phrase repeats, those entries sit next to each other — ';

  @override
  String get v1Copy1038 => 'your wording, not a verdict. ';

  @override
  String get v1Copy1039 =>
      'It does not diagnose, treat, or promise transformation.';

  @override
  String get v1Copy1040 => 'How Thoughtprint earns trust';

  @override
  String get v1Copy1041 => 'Your words are cited as evidence';

  @override
  String get v1Copy1042 =>
      'Patterns and changes link back to the entries you recorded. You can ';

  @override
  String get v1Copy1043 =>
      'inspect source evidence before you rely on any read.';

  @override
  String get v1Copy1046 => 'You control all access';

  @override
  String get v1Copy1047 =>
      'Caregiver and observer grants require your explicit consent. Revoke ';

  @override
  String get v1Copy1048 =>
      'access any time — nothing is shared without your say.';

  @override
  String get v1Copy1049 => 'Start my archive';

  @override
  String get v1Copy1050 => 'A few of your notes use similar words.';

  @override
  String get v1Copy1051 =>
      'Want to be reminded to look at this entry in a week?';
}
