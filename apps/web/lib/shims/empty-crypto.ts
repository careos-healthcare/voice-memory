/** Client-build stub — internal dashboards are dev-only; marketing pages do not use crypto. */
export function createHash() {
  return {
    update: () => ({
      digest: () => "",
    }),
  };
}
