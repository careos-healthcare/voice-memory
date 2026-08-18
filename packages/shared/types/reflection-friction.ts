export interface ReflectionFrictionWarning {
  id: string;
  message: string;
}

export interface ReflectionFrictionMetrics {
  resurfacingSeen: number;
  recorderOpenedFromReturn: number;
  recorderAbandoned: number;
  reflectionSaved: number;
  avgSecondsToRecordAfterCallback: number | null;
  repeatDismissals: number;
  surfacesBeforeRecording: number;
  openedWithoutReflection: number;
}

export interface ReflectionFrictionReport {
  metrics: ReflectionFrictionMetrics;
  warnings: ReflectionFrictionWarning[];
}
