import * as admin from "firebase-admin";

// Event Types
export interface Event {
  id?: string;
  promoterId: string;
  title: string;
  category: EventCategory;
  description: string;
  images: string[];
  rules: string[];
  priceTiers: PriceTier[];
  location: admin.firestore.GeoPoint;
  venueName: string;
  neighborhood?: string;
  startAt: admin.firestore.Timestamp;
  endAt: admin.firestore.Timestamp;
  recurrence?: RecurrenceRule;
  ageRestrictions?: AgeRestriction;
  indoor: boolean;
  tags: string[];
  seating: SeatingInfo;
  status: EventStatus;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  cancellationReason?: string;
  cancelledAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  cancelledBy?: string;
}

export enum EventCategory {
  MUSIC = "music",
  CULTURE = "culture",
  SPORTS = "sports",
  THEATER = "theater",
  CONFERENCE = "conference",
  FAMILY = "family",
  OTHER = "other"
}

export enum EventStatus {
  DRAFT = "draft",
  PUBLISHED = "published",
  SOLD_OUT = "sold_out",
  CANCELLED = "cancelled"
}

export interface PriceTier {
  name: string;
  priceMAD: number;
  currency: string;
  description?: string;
}

export interface SeatingInfo {
  hasSeatMap: boolean;
  generalAdmission: boolean;
  totalCapacity?: number;
}

export interface AgeRestriction {
  minimumAge?: number;
  requiresGuardian: boolean;
}

export interface RecurrenceRule {
  frequency: "daily" | "weekly" | "monthly";
  interval: number;
  daysOfWeek?: number[];
  endDate?: string;
}

// Session Types
export interface EventSession {
  id?: string;
  eventId: string;
  startAt: admin.firestore.Timestamp;
  endAt: admin.firestore.Timestamp;
  capacityByTier: { [tierName: string]: number };
  soldByTier?: { [tierName: string]: number };
  status: SessionStatus;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  cancellationReason?: string;
}

export enum SessionStatus {
  SCHEDULED = "scheduled",
  LIMITED = "limited",
  SOLD_OUT = "sold_out",
  CANCELLED = "cancelled"
}

// Group Types
export interface AttendanceGroup {
  id?: string;
  organizerId: string;
  eventId: string;
  sessionId?: string;
  name: string;
  status: GroupStatus;
  invitedUserIds: string[];
  participantUserIds: string[];
  chatId?: string;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

export enum GroupStatus {
  PLANNING = "planning",
  ORDERING = "ordering",
  CONFIRMED = "confirmed",
  ATTENDED = "attended",
  CANCELLED = "cancelled"
}

// Order Types
export interface TicketOrder {
  id?: string;
  groupId: string;
  eventId: string;
  sessionId?: string;
  promoterId: string;
  organizerId: string;
  lineItems: OrderLineItem[];
  totalAmount: number;
  currency: string;
  status: OrderStatus;
  paymentIntentId?: string;
  tickets: Ticket[];
  settlement?: OrderSettlement;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

export enum OrderStatus {
  PENDING = "pending",
  AWAITING_SPLIT = "awaiting_split",
  CONFIRMED = "confirmed",
  CANCELLED = "cancelled",
  REFUNDED = "refunded"
}

export interface OrderLineItem {
  tierName: string;
  quantity: number;
  unitPrice: number;
}

export interface Ticket {
  code: string;
  qrUrl?: string;
  seat?: string;
  tierName: string;
  holderUserId?: string;
}

export interface OrderSettlement {
  splits: SplitShare[];
  fees: Fee[];
  collectedAt?: admin.firestore.Timestamp;
}

export interface Fee {
  type: string;
  amount: number;
}

// Split Types
export interface SplitIntent {
  id?: string;
  orderId: string;
  shareType: ShareType;
  shares: SplitShare[];
  status: SplitStatus;
  expiresAt: admin.firestore.Timestamp;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  completedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

export enum ShareType {
  EVEN = "even",
  CUSTOM = "custom"
}

export enum SplitStatus {
  PENDING = "pending",
  PAID = "paid",
  EXPIRED = "expired"
}

export interface SplitShare {
  userId: string;
  amount: number;
  isPaid: boolean;
  paidAt?: admin.firestore.Timestamp;
  paymentIntentId?: string;
}

// Promoter Types
export interface EventPromoter {
  id?: string;
  name: string;
  contact: PromoterContact;
  verificationTier: VerificationTier;
  payoutAccount?: string;
  isActive: boolean;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

export interface PromoterContact {
  email: string;
  phone?: string;
  website?: string;
}

export enum VerificationTier {
  BASIC = "basic",
  VERIFIED = "verified",
  PREMIUM = "premium"
}

// Search Types
export interface SearchQuery {
  query: string;
  filters: EventFilters;
  userId?: string;
  limit?: number;
  offset?: number;
}

export interface EventFilters {
  categories?: EventCategory[];
  priceRange?: { min: number; max: number };
  dateRange?: { from: string; to: string };
  cityId?: string;
  neighborhood?: string;
  indoor?: boolean;
  tags?: string[];
  searchRadius?: number;
  location?: admin.firestore.GeoPoint;
}

export interface SearchResult {
  events: Event[];
  totalCount: number;
  facets?: SearchFacets;
  reasonCodes?: string[];
}

export interface SearchFacets {
  categories: { [key: string]: number };
  priceRanges: { [key: string]: number };
  neighborhoods: { [key: string]: number };
  tags: { [key: string]: number };
}

// Interaction Types
export interface EventInteraction {
  id?: string;
  userId: string;
  type: InteractionType;
  entityId: string;
  entityType: "event" | "group" | "order";
  timestamp: admin.firestore.Timestamp;
  context?: { [key: string]: any };
}

export enum InteractionType {
  VIEW = "view",
  SAVE = "save",
  RSVP = "rsvp",
  ORDER = "order",
  PAY = "pay",
  SHARE = "share",
  COMMENT = "comment"
}

// Notification Types
export interface EventNotification {
  id?: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data: { [key: string]: any };
  read: boolean;
  sentAt: admin.firestore.Timestamp;
  readAt?: admin.firestore.Timestamp;
}

export enum NotificationType {
  GROUP_INVITE = "group_invite",
  RSVP_UPDATE = "rsvp_update",
  ORDER_CONFIRMATION = "order_confirmation",
  SPLIT_REQUEST = "split_request",
  SPLIT_PAID = "split_paid",
  EVENT_REMINDER = "event_reminder",
  EVENT_UPDATE = "event_update",
  EVENT_CANCELLED = "event_cancelled"
}

// Review Types
export interface EventReview {
  id?: string;
  eventId?: string;
  promoterId?: string;
  fromUserId: string;
  rating: number;
  text: string;
  createdAt: admin.firestore.Timestamp;
  helpful?: number;
  verified?: boolean;
}

// Partner Request Types
export interface PartnerRequest {
  id?: string;
  organizerId: string;
  category: EventCategory;
  cityId: string;
  window: { from: string; to: string };
  message: string;
  status: PartnerRequestStatus;
  matchedUserIds?: string[];
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  expiresAt?: admin.firestore.Timestamp;
}

export enum PartnerRequestStatus {
  OPEN = "open",
  MATCHED = "matched",
  CLOSED = "closed"
}

// User Traits (for AI/personalization)
export interface UserTraits {
  userId: string;
  interests: string[];
  budgetBandMAD?: { min: number; max: number };
  preferredCategories: EventCategory[];
  preferredNeighborhoods?: string[];
  preferredTimeSlots?: { dayOfWeek: number; timeRange: string }[];
  pastEventIds: string[];
  friendUserIds?: string[];
  updatedAt: admin.firestore.Timestamp | admin.firestore.FieldValue;
}

// Consent Types
export interface ConsentGrant {
  id?: string;
  userId: string;
  scope: ConsentScope;
  granted: boolean;
  purpose: string;
  expiresAt?: admin.firestore.Timestamp;
  grantedAt: admin.firestore.Timestamp;
  revokedAt?: admin.firestore.Timestamp;
}

export enum ConsentScope {
  SOCIAL_SIGNALS = "social_signals",
  LOCATION_TRACKING = "location_tracking",
  MARKETING_EMAILS = "marketing_emails",
  PERSONALIZATION = "personalization",
  ANALYTICS = "analytics"
}

// Friends & Social Types
export interface EventsFriend {
  id: string;
  name: string;
  profileImageURL?: string;
  preferredCategories: string[];
  mutualFriendsCount: number;
  isOnline: boolean;
  lastSeen?: Date;
}

export interface FriendEventActivity {
  id: string;
  friendId: string;
  friendName: string;
  eventId: string;
  eventTitle: string;
  activityType: FriendActivityType;
  timestamp: Date;
  isVisible: boolean;
}

export enum FriendActivityType {
  SAVED = "saved",
  ATTENDING = "attending",
  INTERESTED = "interested",
  ORDERED = "ordered",
  REVIEWED = "reviewed"
}

export interface EventInvite {
  id: string;
  fromUserId: string;
  fromUserName: string;
  toUserId: string;
  eventId: string;
  eventTitle: string;
  message?: string;
  createdAt: Date;
  response?: InviteResponse;
  respondedAt?: Date;
}

export enum InviteResponse {
  ACCEPTED = "accepted",
  DECLINED = "declined",
  MAYBE = "maybe"
}

// Chat Types
export interface GroupChatMessage {
  id: string;
  chatId: string;
  userId: string;
  userName: string;
  userAvatarURL?: string;
  content: string;
  messageType: ChatMessageType;
  timestamp: Date;
  readBy: string[];
  isSystemMessage: boolean;
  replyToId?: string;
}

export enum ChatMessageType {
  TEXT = "text",
  IMAGE = "image",
  LOCATION = "location",
  EVENT_DETAILS = "event_details",
  RIDE_DETAILS = "ride_details",
  SYSTEM = "system"
}

// Ride Integration Types
export interface RideQuote {
  id: string;
  eventId: string;
  pickupLocation: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  dropoffLocation: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  departureTime: Date;
  estimatedDuration: number; // minutes
  estimatedFare: number; // MAD
  passengerCount: number;
  vehicleType: string;
  expiresAt: Date;
  deepLinkUrl: string;
}

export interface RideBookingRequest {
  id: string;
  quoteId: string;
  eventId: string;
  userId: string;
  groupId?: string;
  pickupLocation: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  dropoffLocation: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  departureTime: Date;
  passengerCount: number;
  estimatedFare: number;
  status: string; // "pending", "confirmed", "cancelled", "completed"
  shareRide: boolean;
  createdAt: Date;
  statusDetails?: any;
}

export interface RideBookingResult {
  bookingId: string;
  status: string;
  deepLinks: {
    uber?: string;
    careem?: string;
    inDrive?: string;
    liiveRide: string;
  };
  estimatedFare: number;
  departureTime: Date;
  message: string;
}

// Promoter Portal Types
export interface PromoterApplication {
  id: string;
  userId: string;
  businessName: string;
  contactName: string;
  email: string;
  phone: string;
  businessType: string;
  description: string;
  previousExperience?: string;
  socialMediaLinks: string[];
  businessRegistration?: string;
  status: "pending" | "approved" | "rejected";
  submittedAt: Date;
  reviewedAt?: Date;
  reviewedBy?: string;
  reviewNotes?: string;
}

export interface PromoterMetrics {
  totalEvents: number;
  publishedEvents: number;
  totalTicketsSold: number;
  totalRevenue: number;
  totalAttendees: number;
  averageAttendanceRate: number;
  topPerformingEvents: Array<{
    eventId: string;
    eventTitle: string;
    attendees: number;
    revenue: number;
  }>;
  recentActivity: Array<{
    timestamp: Date;
    activity: string;
    details: any;
  }>;
}

export interface EventDraft {
  title: string;
  category: string;
  description: string;
  images?: string[];
  rules?: string[];
  priceTiers: PriceTier[];
  location: {
    latitude: number;
    longitude: number;
  };
  venueName: string;
  neighborhood?: string;
  startAt: Date;
  endAt: Date;
  indoor: boolean;
  tags?: string[];
  seating?: SeatingConfiguration;
  cityId?: string;
}

// External Ticket Provider Types
export enum TicketProviderType {
  EVENTBRITE = "eventbrite",
  TICKETMASTER = "ticketmaster", 
  UNIVERSE = "universe",
  BILLETTO = "billetto",
  TITO = "tito",
  BROWN_PAPER_TICKETS = "brown_paper_tickets"
}

export interface ExternalTicketProvider {
  type: TicketProviderType;
  name: string;
  apiEndpoint: string;
  authType: "api_key" | "oauth" | "bearer_token";
  webhookSupport: boolean;
  features: {
    eventImport: boolean;
    ticketSync: boolean;
    orderSync: boolean;
    realTimeUpdates: boolean;
  };
}

export interface ExternalTicketIntegration {
  id: string;
  userId: string;
  provider: TicketProviderType;
  credentials: {
    apiKey?: string;
    accessToken?: string;
    refreshToken?: string;
    organizationId?: string;
    webhookSecret?: string;
  };
  status: "active" | "inactive" | "error";
  lastSync?: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface ExternalTicketSync {
  id: string;
  integrationId: string;
  provider: TicketProviderType;
  status: "running" | "completed" | "failed";
  startedAt: Date;
  completedAt?: Date;
  eventsProcessed: number;
  ordersProcessed?: number;
  errors: string[];
}

export interface ExternalTicketOrder {
  id: string;
  eventId: string;
  provider: TicketProviderType;
  externalOrderId: string;
  customerEmail: string;
  customerName: string;
  totalAmount: number;
  currency: string;
  status: string;
  ticketCount: number;
  purchaseDate: Date;
  syncedAt: Date;
}