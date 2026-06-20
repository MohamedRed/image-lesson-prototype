import * as admin from 'firebase-admin';

// Activities Models - TypeScript interfaces for backend

// Provider/Venue Models
export interface ActivityProvider {
  id: string;
  ownerId?: string; // User who owns this provider account
  name: string;
  type: 'venue' | 'company' | 'individual';
  contact: {
    email?: string;
    phone?: string;
    website?: string;
  };
  geo: {
    lat: number;
    lng: number;
    city: string;
    neighborhood?: string;
    address: string;
  };
  amenities: string[];
  rating?: number;
  reviewCount?: number;
  verificationTier: 'unverified' | 'basic' | 'verified' | 'premium';
  payoutAccount?: {
    stripeAccountId: string;
    onboardingComplete: boolean;
  };
  isActive: boolean;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

// Provider application for self-serve onboarding
export interface ProviderApplication {
  applicantUserId: string;
  businessName: string;
  businessType: 'venue' | 'company' | 'individual';
  contactInfo: {
    email: string;
    phone?: string;
    website?: string;
  };
  location: {
    lat: number;
    lng: number;
    city: string;
    neighborhood?: string;
    address: string;
  };
  description?: string;
  categories?: string[];
  businessLicense?: string;
  taxId?: string;
  status: 'pending' | 'approved' | 'rejected';
  providerId?: string; // Set when approved
  verificationTier: 'unverified' | 'basic' | 'verified' | 'premium';
  submittedAt: admin.firestore.Timestamp;
  reviewedAt?: admin.firestore.Timestamp;
  reviewedBy?: string;
  rejectionReason?: string;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

// Activity/Offering Models
export interface Activity {
  id: string;
  providerId: string;
  title: string;
  category: ActivityCategory;
  description: string;
  images: string[];
  rules?: string[];
  minParticipants: number;
  maxParticipants: number;
  pricePerUnit: number; // MAD
  unit: 'person' | 'team' | 'slot' | 'hour';
  durationMinutes: number;
  location: {
    lat: number;
    lng: number;
    address: string;
    neighborhood?: string;
  };
  tags: string[];
  ageRestrictions?: {
    minAge?: number;
    maxAge?: number;
  };
  skillLevel?: 'beginner' | 'intermediate' | 'advanced' | 'any';
  equipmentNeeded?: string[];
  isActive: boolean;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export type ActivityCategory = 
  | 'sport' 
  | 'game' 
  | 'workshop' 
  | 'culture' 
  | 'outdoor' 
  | 'fitness' 
  | 'food' 
  | 'education' 
  | 'other';

// Session/Availability Models
export interface ActivitySession {
  id: string;
  activityId: string;
  startAt: admin.firestore.Timestamp;
  endAt: admin.firestore.Timestamp;
  capacity: number;
  bookedCount: number;
  priceOverride?: number;
  bookingWindow: {
    opensAt: admin.firestore.Timestamp;
    closesAt: admin.firestore.Timestamp;
  };
  status: 'open' | 'limited' | 'full' | 'closed' | 'cancelled';
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

// Group Models
export interface Group {
  id: string;
  organizerId: string;
  name: string;
  activityId?: string;
  sessionId?: string;
  cityId: string;
  status: GroupStatus;
  preferences: {
    timeBands?: string[]; // e.g., ['morning', 'afternoon', 'evening']
    budgetBand?: {
      min: number;
      max: number;
    };
    skillLevel?: string;
    categories?: ActivityCategory[];
  };
  invitedUserIds: string[];
  participantUserIds: string[];
  partnerRequestId?: string;
  chatThreadId?: string;
  metadata?: {
    [key: string]: any;
  };
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export type GroupStatus = 
  | 'planning' 
  | 'booking' 
  | 'confirmed' 
  | 'completed' 
  | 'cancelled';

// Partner Request Models
export interface PartnerRequest {
  id: string;
  organizerId: string;
  activityCategory: ActivityCategory;
  cityId: string;
  neighborhood?: string;
  skillLevel?: string;
  message: string;
  desiredWindow: {
    from: admin.firestore.Timestamp;
    to: admin.firestore.Timestamp;
  };
  preferredDays?: string[]; // ['monday', 'tuesday', etc.]
  frequency: 'one_off' | 'recurring';
  status: 'open' | 'matched' | 'closed';
  interestedUserIds?: string[];
  matchedGroupId?: string;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

// Booking Models
export interface Booking {
  id: string;
  groupId: string;
  activityId: string;
  sessionId: string;
  providerId: string;
  organizerId: string;
  participants: BookingParticipant[];
  totalAmount: number;
  currency: string;
  status: BookingStatus;
  paymentIntentId?: string;
  settlement?: {
    splits: SplitShare[];
    fees: PaymentFee[];
    collectedAt?: admin.firestore.Timestamp;
  };
  cancellation?: {
    reason: string;
    cancelledBy: string;
    cancelledAt: admin.firestore.Timestamp;
    refundAmount?: number;
  };
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export type BookingStatus = 
  | 'pending' 
  | 'awaiting_split' 
  | 'confirmed' 
  | 'cancelled' 
  | 'completed'
  | 'refunded';

export interface BookingParticipant {
  userId: string;
  userName: string;
  role: 'organizer' | 'participant';
  status: 'invited' | 'accepted' | 'declined' | 'paid';
}

// Split Payment Models
export interface SplitIntent {
  id: string;
  bookingId: string;
  shareType: 'even' | 'custom';
  shares: SplitShare[];
  status: SplitStatus;
  expiresAt: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

export type SplitStatus = 
  | 'pending' 
  | 'partial' 
  | 'paid' 
  | 'expired' 
  | 'cancelled';

export interface SplitShare {
  userId: string;
  userName: string;
  amount: number;
  status: 'pending' | 'paid' | 'failed';
  paymentIntentId?: string;
  paidAt?: admin.firestore.Timestamp;
}

export interface PaymentFee {
  type: 'stripe' | 'platform';
  amount: number;
  description: string;
}

// Review Models
export interface Review {
  id: string;
  bookingId: string;
  fromUserId: string;
  fromUserName: string;
  toProviderId: string;
  rating: number; // 1-5
  text?: string;
  tags?: string[]; // e.g., ['clean', 'friendly', 'on-time']
  createdAt: admin.firestore.Timestamp;
}

// Analytics/Interaction Models
export interface Interaction {
  id: string;
  userId: string;
  type: InteractionType;
  entityId: string;
  entityType: 'activity' | 'group' | 'booking' | 'partnerRequest';
  timestamp: admin.firestore.Timestamp;
  context?: {
    [key: string]: any;
  };
}

export type InteractionType = 
  | 'view' 
  | 'save' 
  | 'invite' 
  | 'accept' 
  | 'decline' 
  | 'book' 
  | 'pay' 
  | 'review'
  | 'search'
  | 'ai_query';

// Consent and Cross-App Models
export interface ConsentGrant {
  id: string;
  userId: string;
  scope: string; // e.g., 'activities:health_profile_read'
  status: 'granted' | 'revoked';
  createdAt: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
}

export interface UserTraits {
  userId: string;
  traits: {
    favoriteSports?: string[];
    preferredDays?: string[];
    budgetBand?: {
      min: number;
      max: number;
    };
    avgPace?: number; // minutes per km
    health?: {
      vo2Max?: number;
      weeklyActiveMins?: number;
    };
    skillLevels?: {
      [category: string]: string;
    };
  };
  updatedAt: admin.firestore.Timestamp;
  provenance: {
    app: string;
    scope: string;
    consentId: string;
  };
}

// Request/Response Types for APIs
export interface ActivitySearchRequest {
  query?: string;
  filters: ActivityFilters;
  geo?: {
    lat: number;
    lng: number;
    radiusKm?: number;
  };
  timeWindow?: {
    from: Date;
    to: Date;
  };
  limit?: number;
  offset?: number;
}

export interface ActivityFilters {
  categories?: ActivityCategory[];
  priceRange?: {
    min: number;
    max: number;
  };
  skillLevel?: string;
  minParticipants?: number;
  maxParticipants?: number;
  neighborhoods?: string[];
  availableOnly?: boolean;
}

export interface ActivitySearchResponse {
  activities: Activity[];
  total: number;
  reasonCodes?: string[];
  nextCursor?: string;
}

// Group Creation/Management
export interface GroupDraft {
  name: string;
  activityId?: string;
  preferences: Group['preferences'];
  inviteUserIds?: string[];
}

export interface PartnerRequestDraft {
  activityCategory: ActivityCategory;
  cityId: string;
  neighborhood?: string;
  skillLevel?: string;
  message: string;
  desiredWindow: {
    from: Date;
    to: Date;
  };
  preferredDays?: string[];
  frequency: 'one_off' | 'recurring';
}

// Booking Requests
export interface BookingRequest {
  groupId: string;
  activityId: string;
  sessionId: string;
  participants: string[]; // user IDs
}

export interface SplitIntentRequest {
  bookingId: string;
  shareType: 'even' | 'custom';
  customShares?: {
    userId: string;
    amount: number;
  }[];
}

// AI Types
export interface AIResponse {
  answer: string;
  actions?: AIAction[];
  reasonCodes?: string[];
  suggestions?: Activity[];
}

export interface AIAction {
  type: 'search' | 'create_group' | 'create_partner_request' | 'book_activity';
  parameters: {
    [key: string]: any;
  };
  description: string;
}

export interface ActivityAlert {
  id: string;
  userId: string;
  criteria: ActivityAlertCriteria;
  status: 'active' | 'triggered' | 'expired';
  createdAt: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
}

export interface ActivityAlertCriteria {
  query?: string;
  filters: ActivityFilters;
  geo?: {
    lat: number;
    lng: number;
    radiusKm: number;
  };
}

export interface ProposedSlot {
  sessionId: string;
  startAt: Date;
  endAt: Date;
  activity: Activity;
  reasonCode: string;
  confidence: number;
}

export interface PartnerCandidate {
  userId: string;
  userName: string;
  matchScore: number;
  reasonCodes: string[];
  mutualFriends?: number;
  skillLevel?: string;
}

// Error Types
export class ActivitiesError extends Error {
  constructor(
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message);
    this.name = 'ActivitiesError';
  }
}

export const ErrorCodes = {
  ACTIVITY_NOT_FOUND: 'activity_not_found',
  PROVIDER_NOT_FOUND: 'provider_not_found',
  SESSION_NOT_AVAILABLE: 'session_not_available',
  INSUFFICIENT_CAPACITY: 'insufficient_capacity',
  BOOKING_NOT_FOUND: 'booking_not_found',
  GROUP_NOT_FOUND: 'group_not_found',
  UNAUTHORIZED: 'unauthorized',
  INVALID_REQUEST: 'invalid_request',
  PAYMENT_FAILED: 'payment_failed',
  SPLIT_EXPIRED: 'split_expired',
} as const;