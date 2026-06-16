"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { ArchiveCard } from "@/components/archive/ArchiveCard";
import { ContinuityStrip } from "@/components/archive/ContinuityStrip";
import { WhyMoreEvidenceMatters } from "@/components/archive/WhyMoreEvidenceMatters";
import { BlindSpotExperimentFollowUpStack } from "@/components/blind-spots/BlindSpotExperimentFollowUpStack";
import { InsightOutcomePromptStack } from "@/components/insights/InsightOutcomePromptStack";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { TheoryNotificationCard } from "@/components/theories/TheoryNotificationCard";
import { notifyTheoryNotificationsChanged } from "@/components/theories/TheoryUpdatesNav";
import { SiteHeader } from "@/components/SiteHeader";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import {
  recordNotificationDismissed,
  recordNotificationOpened,
  recordNotificationsSeen,
} from "@/lib/theories/theory-notification-lifecycle";
import {
  markAllTheoryNotificationsRead,
  markTheoryNotificationRead,
  readTheoryNotifications,
} from "@/lib/theories/theory-notification-storage";
import { UPDATES_PAGE_TITLE } from "@/lib/product/archive-product-copy";
import type { TheoryNotification } from "@/types/theory-notification";

export default function UpdatesPage() {
  const router = useRouter();
  const [items, setItems] = useState<TheoryNotification[]>([]);

  const refresh = useCallback(() => {
    setItems(readTheoryNotifications());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    const unreadItems = readTheoryNotifications().filter((n) => !n.readAt);
    if (unreadItems.length > 0) {
      recordNotificationsSeen(unreadItems);
    }
  }, [items]);

  const unread = items.filter((n) => !n.readAt);
  const read = items.filter((n) => n.readAt);

  const handleOpen = (id: string, route: string) => {
    const notification = items.find((n) => n.id === id);
    if (notification) {
      recordNotificationOpened(notification);
    }
    markTheoryNotificationRead(id);
    notifyTheoryNotificationsChanged();
    refresh();
    router.push(route);
  };

  const handleMarkAllRead = () => {
    for (const notification of items.filter((n) => !n.readAt)) {
      recordNotificationDismissed(notification);
    }
    markAllTheoryNotificationsRead();
    notifyTheoryNotificationsChanged();
    refresh();
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
          <ArchivePageBlueprint
            surface="changes"
            identity={{
              eyebrow: "Changes",
              title: UPDATES_PAGE_TITLE,
              lead:
                "Meaningful shifts in your archive beliefs — not reminders, streaks, or nudges to record.",
            }}
            currentArchiveState={<ContinuityStrip surface="updates" />}
            whatChanged={<WhyMoreEvidenceMatters className={ARCHIVE_SPACE.md} />}
            mainContent={
              <>
                <BlindSpotExperimentFollowUpStack className={ARCHIVE_SPACE.lg} />
                <InsightOutcomePromptStack className={ARCHIVE_SPACE.md} />

                {items.length === 0 ? (
                  <ArchiveCard variant="SUPPORTING">
                    <p className={ARCHIVE_TYPO.body}>
                      No archive changes yet. After your next visit to Discover, meaningful
                      belief shifts may appear here.
                    </p>
                  </ArchiveCard>
                ) : (
                  <div className={ARCHIVE_SPACE.mainStack}>
                    {unread.length > 0 ? (
                      <ArchiveCard variant="PRIMARY" title="Unread changes">
                        <div className="space-y-4">
                          {unread.map((n) => (
                            <TheoryNotificationCard
                              key={n.id}
                              notification={n}
                              onOpen={handleOpen}
                            />
                          ))}
                        </div>
                      </ArchiveCard>
                    ) : null}
                    {read.length > 0 ? (
                      <ArchiveCard variant="SECONDARY" title="Earlier changes">
                        <div className="space-y-4">
                          {read.map((n) => (
                            <TheoryNotificationCard
                              key={n.id}
                              notification={n}
                              onOpen={handleOpen}
                            />
                          ))}
                        </div>
                      </ArchiveCard>
                    ) : null}
                  </div>
                )}
              </>
            }
            actionArea={
              unread.length > 0 ? (
                <ArchiveActionArea
                  primary={{
                    label: "Mark all read",
                    onClick: handleMarkAllRead,
                    testId: "changes-mark-all-read",
                  }}
                  secondary={{
                    label: "Open Discover",
                    href: "/discover",
                  }}
                />
              ) : (
                <ArchiveActionArea
                  primary={{
                    label: "Open Discover",
                    href: "/discover",
                    testId: "changes-open-discover",
                  }}
                />
              )
            }
          />
        </PrimaryMain>
      </div>
    </div>
  );
}
