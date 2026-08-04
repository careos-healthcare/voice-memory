export const WEB_STRIPE_FUNNEL_EVENTS = {
  landingPageView: "Landing Page View",
  checkoutInitiated: "Checkout Initiated",
  subscriptionCompleted: "Subscription Completed",
} as const;

export type WebStripeFunnelEvent =
  (typeof WEB_STRIPE_FUNNEL_EVENTS)[keyof typeof WEB_STRIPE_FUNNEL_EVENTS];
