# Navigation architecture

ArchiveMe has one `StatefulShellRoute.indexedStack` with four primary
destinations, in this fixed order:

1. Record (`/record`)
2. Archive (`/archive-belief`)
3. Changes (`/belief-changes`)
4. Account (`/account`)

`PrimaryDestination` is the source of truth for branch identity, order, labels,
icons, semantics, and routes. Changing branch order requires updating that type
and the navigation behavior tests.

## Primary and secondary navigation

Primary destinations use `context.go` or `StatefulNavigationShell.goBranch`.
They must not be pushed, shown in a bottom sheet, or constructed by
`MainShell`. The indexed stack preserves each inactive branch's state, while
reselecting the active destination returns that branch to its initial location.

Memory Graph (`/life-os/graph`) is a secondary exploration route. Archive opens
it with `context.push`; it is not a shell branch and does not display primary
navigation underneath. Settings and detail screens are secondary pushed routes
too. A new secondary route should be declared once in the root router and
opened with `push`—adding it does not justify another primary tab.

## Back and deep links

Back pops root-level secondary screens and nested branch pages first. At an
Archive, Changes, or Account root, back selects Record. At the Record root, the
platform may exit or background the app. A directly opened Memory Graph falls
back to Archive, and directly opened Settings falls back to Account.

Stable deep links select their matching branch. Record prompt/autostart and
Memory Graph view/node query parameters remain supported.

## Recording safety

Record reports permission requests, active recording, and processing through a
small injected activity controller. `MainShell` blocks cross-tab and back
navigation during those states and explains that recording must first finish or
be cancelled. Safe completion, cancellation, errors, and disposal release the
lock.

Graph conversation is not exposed through the focused V1 primary shell because
live voice is disabled for that build. Its underlying implementation remains
available for a future graph-local entry point.
