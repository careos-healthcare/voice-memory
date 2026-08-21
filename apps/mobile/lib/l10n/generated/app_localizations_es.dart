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
      'ArchiveMe es un diario de voz privado que convierte tus pensamientos hablados en una historia de vida unificada e inteligencia personal profunda. Crea una cuenta para restaurar el acceso más tarde.';

  @override
  String get accountAuthCreateCta => 'Crear cuenta';

  @override
  String get accountAuthCreateTitle => 'Crea tu cuenta de ArchiveMe';

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
  String get accountAuthSignInTitle => 'Inicia sesión en ArchiveMe';

  @override
  String get accountAuthSignOut => 'Cerrar sesión';

  @override
  String get accountAuthSignOutKeepsArchive =>
      'Al cerrar sesión, tus grabaciones permanecen en este dispositivo.';

  @override
  String get accountAuthTimingNote =>
      'ArchiveMe es un diario de voz privado que convierte tus pensamientos hablados en una historia de vida unificada e inteligencia personal profunda. Puedes usarlo localmente sin cuenta.';

  @override
  String get accountScreenLabel => 'Pantalla de cuenta';

  @override
  String get appTitle => 'ArchiveMe';

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
      'Añade otro momento para que ArchiveMe pueda comparar lo que cambió.';

  @override
  String get archiveNeedsSupportedMoments =>
      'ArchiveMe necesita al menos dos momentos compatibles antes de explicar un patrón.';

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
      'Dilo con claridad. ArchiveMe busca patrones, no juicios.';

  @override
  String get recordingProcessingStatus => 'Procesando';

  @override
  String get recordingPromptNudgeBody =>
      'ArchiveMe usa lo que grabas para mostrar cada día cosas más claras que merecen la pena comprobar.';

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
  String get accountTitle => 'Cuenta de ArchiveMe';

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
      'ArchiveMe no intenta responder mejor que ChatGPT. Intenta recordar de otra manera.';

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
      'Este hilo ha regresado antes. Pro conserva el historial de evidencia para que ArchiveMe pueda mostrar si se fortalece, se suaviza o cambia.';

  @override
  String get valueMomentBeliefBody =>
      'Una frase similar a una creencia apareció de nuevo. Pro conserva la línea de tiempo de lo que cambió en tu archivo.';

  @override
  String get valueMomentWeeklyBody =>
      'Tu revisión semanal encontró algo para comparar. Pro conserva las revisiones semanales del archivo para que ArchiveMe pueda seguir lo que cambió con el tiempo.';

  @override
  String get valueMomentProofCounterBody =>
      'Tu archivo tiene grabaciones conectadas. Pro conserva todo el historial de evidencia a medida que crece el rastro.';

  @override
  String get valueMomentFallbackBody =>
      'Tu primera repetición es gratis. Pro conserva el historial de evidencia para que ArchiveMe pueda mostrar si los patrones se fortalecen, se suavizan o cambian con el tiempo.';

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
      'Graba algunos momentos reales. ArchiveMe buscará lo que se repite entre ellos.';

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
      'Graba un momento más claro y ArchiveMe podrá comparar lo que se repite.';

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
      'Patrones y temas que ArchiveMe sigue notando en tus reflexiones.';

  @override
  String get patternsCheckInWaitingTitle => 'Registro pendiente';

  @override
  String get patternsCheckInWaitingBody =>
      'ArchiveMe tiene una pregunta de tu último momento.';

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
      'ArchiveMe está observando esta señal';

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
      'ArchiveMe compara lo que guardas con el tiempo.';

  @override
  String get patternsComeBackRecordCta => 'Grabar la reflexión de hoy';
}
