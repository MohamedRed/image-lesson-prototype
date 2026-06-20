# Web UI Component Contracts (shadcn/ui)

All components are TypeScript React with Tailwind and shadcn/ui primitives.

## Routes
- /debates/[id] (live)
- /replays/[id]
- /watch/[id] (watch party)

## Components

### VideoPageLayout
Props: { left: ReactNode, main: ReactNode, right: ReactNode }
Behavior: desktop 3-column; mobile stacks.

### HLSPlayer
Props: { src: string, autoPlay?: boolean, lowLatency?: boolean, captions?: CaptionTrack[] }
Events: onPlay, onError, onQualityChange

### TimelineView
Props: { debaters: Debater[], selectedUid: string, eventsByUid: Record<uid, Event[]> }
Events: onSelectEvent(eventId)

### EventDetailsDrawer
Props: { event: Event, sources: Source[], fact: FactCheck }

### SharedMediaPanel
Props: { items: MediaItem[] }

### CommentSummaryPanel
Props: { clusters: ClusterSummary[], onLike(clusterId), onDislike(clusterId), onComment(clusterId, text) }

### ReactionBar
Props: { likes: number, dislikes: number, onReact(value: 1|0|-1) }

### EntitlementGate
Props: { hasAccess: boolean, onPurchase(productId) }

### WatchPartyLobby
Props: { partyId: string, participants: Participant[], onInvite(), onLeave() }

## State & Data
- Data fetching via React Query (TanStack) with Firestore SDK streams for live updates
- LiveKit JS data track events update client state (timeline, moderation)

## Accessibility
- All dialogs/sheets/tabs keyboard accessible; focus management via Radix
- Color contrast AA; prefers-reduced-motion respected

## Types
- Debater { uid, name, avatarUrl }
- Event { id, historicalDate, title, description, status }
- Source { title, url }
- FactCheck { status, details }
- MediaItem { id, type, url, thumbUrl }
- ClusterSummary { id, summary, likeCount, dislikeCount, commentCount }