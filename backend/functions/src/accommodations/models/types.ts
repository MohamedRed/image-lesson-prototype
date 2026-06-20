export interface AccommodationProperty {
  id: string;
  providerRefs: ProviderReference[];
  name: string;
  brand?: string;
  type: AccommodationType;
  rating?: number;
  reviewsCount: number;
  address: Address;
  coordinates: Coordinates;
  photos: Photo[];
  amenities: string[];
  safetyFeatures: string[];
  checkInTime: string;
  checkOutTime: string;
  policies: PropertyPolicies;
  priceRange?: PriceRange;
}

export enum AccommodationType {
  HOTEL = 'HOTEL',
  HOSTEL = 'HOSTEL',
  APARTMENT = 'APARTMENT',
  ROOM = 'ROOM',
  HOMESTAY = 'HOMESTAY',
  BED_AND_BREAKFAST = 'BED_AND_BREAKFAST',
  VACATION_RENTAL = 'VACATION_RENTAL',
}

export interface Address {
  street?: string;
  city: string;
  state?: string;
  postalCode?: string;
  country: string;
  formattedAddress: string;
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface Photo {
  id: string;
  url: string;
  thumbnailUrl?: string;
  caption?: string;
  width?: number;
  height?: number;
}

export interface PropertyPolicies {
  cancellationPolicy: CancellationPolicy;
  childrenAllowed: boolean;
  petsAllowed: boolean;
  smokingAllowed: boolean;
  partyEventsAllowed: boolean;
  additionalRules: string[];
}

export interface CancellationPolicy {
  type: CancellationType;
  refundableUntil?: Date;
  penaltyAmount?: number;
  description: string;
}

export enum CancellationType {
  FLEXIBLE = 'FLEXIBLE',
  MODERATE = 'MODERATE',
  STRICT = 'STRICT',
  NON_REFUNDABLE = 'NON_REFUNDABLE',
}

export interface PriceRange {
  min: number;
  max: number;
  currency: string;
}

export interface ProviderReference {
  provider: string;
  providerPropertyId: string;
  deepLink?: string;
  terms?: string;
}

export interface RoomType {
  id: string;
  name: string;
  capacity: RoomCapacity;
  beds: BedConfiguration[];
  amenities: string[];
  images: Photo[];
  size?: RoomSize;
}

export interface RoomCapacity {
  adults: number;
  children: number;
  infants: number;
}

export interface BedConfiguration {
  type: BedType;
  count: number;
}

export enum BedType {
  SINGLE = 'SINGLE',
  DOUBLE = 'DOUBLE',
  QUEEN = 'QUEEN',
  KING = 'KING',
  SOFA_BED = 'SOFA_BED',
  BUNK_BED = 'BUNK_BED',
}

export interface RoomSize {
  value: number;
  unit: SizeUnit;
}

export enum SizeUnit {
  SQUARE_METERS = 'SQUARE_METERS',
  SQUARE_FEET = 'SQUARE_FEET',
}

export interface RatePlan {
  id: string;
  name: string;
  mealPlan: MealPlan;
  cancellationPolicy: CancellationPolicy;
  inclusions: string[];
  exclusions: string[];
  paymentType: PaymentType;
  prepaymentRequired: boolean;
  depositRequired: boolean;
  depositAmount?: number;
}

export enum MealPlan {
  ROOM_ONLY = 'ROOM_ONLY',
  BED_AND_BREAKFAST = 'BED_AND_BREAKFAST',
  HALF_BOARD = 'HALF_BOARD',
  FULL_BOARD = 'FULL_BOARD',
  ALL_INCLUSIVE = 'ALL_INCLUSIVE',
}

export enum PaymentType {
  PAY_NOW = 'PAY_NOW',
  PAY_LATER = 'PAY_LATER',
  PAY_AT_PROPERTY = 'PAY_AT_PROPERTY',
}

export interface Availability {
  propertyId: string;
  roomTypeId: string;
  ratePlanId: string;
  dateRange: DateRange;
  inventoryCount: number;
  priceBreakdown: PriceBreakdown;
  lastUpdated: Date;
  isAvailable: boolean;
}

export interface DateRange {
  startDate: Date;
  endDate: Date;
}

export interface PriceBreakdown {
  basePrice: number;
  taxes: Tax[];
  fees: Fee[];
  currency: string;
  totalPrice: number;
}

export interface Tax {
  type: TaxType;
  name: string;
  amount: number;
  percentage?: number;
}

export enum TaxType {
  VAT = 'VAT',
  SALES_TAX = 'SALES_TAX',
  CITY_TAX = 'CITY_TAX',
  TOURIST_TAX = 'TOURIST_TAX',
  OCCUPANCY_TAX = 'OCCUPANCY_TAX',
  OTHER = 'OTHER',
}

export interface Fee {
  type: FeeType;
  name: string;
  amount: number;
  mandatory: boolean;
}

export enum FeeType {
  SERVICE_FEE = 'SERVICE_FEE',
  RESORT_FEE = 'RESORT_FEE',
  CLEANING_FEE = 'CLEANING_FEE',
  BOOKING_FEE = 'BOOKING_FEE',
  PROCESSING_FEE = 'PROCESSING_FEE',
  OTHER = 'OTHER',
}

export interface Booking {
  id: string;
  userId: string;
  propertyRef: AccommodationProperty;
  roomTypeRef: RoomType;
  ratePlanRef: RatePlan;
  guests: Guest[];
  dateRange: DateRange;
  priceSnapshot: PriceBreakdown;
  paymentInfo: PaymentInfo;
  status: BookingStatus;
  providerConfirmation?: ProviderConfirmation;
  specialRequests?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Guest {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  dateOfBirth?: Date;
  isLead: boolean;
}

export interface PaymentInfo {
  method: PaymentMethod;
  stripePaymentIntentId?: string;
  stripePaymentMethodId?: string;
  last4?: string;
  brand?: string;
  status: PaymentStatus;
}

export enum PaymentMethod {
  CARD = 'CARD',
  APPLE_PAY = 'APPLE_PAY',
  GOOGLE_PAY = 'GOOGLE_PAY',
  BANK_TRANSFER = 'BANK_TRANSFER',
  PAY_AT_PROPERTY = 'PAY_AT_PROPERTY',
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  PROCESSING = 'PROCESSING',
  SUCCEEDED = 'SUCCEEDED',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
  PARTIAL_REFUND = 'PARTIAL_REFUND',
}

export enum BookingStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  CANCELLED = 'CANCELLED',
  COMPLETED = 'COMPLETED',
  NO_SHOW = 'NO_SHOW',
  IN_PROGRESS = 'IN_PROGRESS',
}

export interface ProviderConfirmation {
  provider: string;
  confirmationCode: string;
  providerBookingId?: string;
  providerStatus?: string;
  deepLink?: string;
}

export interface ImportRecord {
  id: string;
  userId: string;
  sourceUrl?: string;
  confirmationCode?: string;
  parsedAttributes: Record<string, any>;
  status: ImportStatus;
  provenance: string;
  createdAt: Date;
}

export enum ImportStatus {
  PENDING = 'PENDING',
  PROCESSING = 'PROCESSING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
  PARTIAL = 'PARTIAL',
}

export interface SearchRequest {
  location: SearchLocation;
  dateRange: DateRange;
  guests: GuestConfiguration;
  filters?: SearchFilters;
  sortBy?: SortOption;
  pageToken?: string;
}

export type SearchLocation = 
  | { type: 'coordinates'; lat: number; lng: number }
  | { type: 'placeId'; placeId: string }
  | { type: 'address'; address: string };

export interface GuestConfiguration {
  rooms: number;
  adults: number;
  children: number;
  childrenAges: number[];
}

export interface SearchFilters {
  budgetMin?: number;
  budgetMax?: number;
  rating?: number;
  amenities?: string[];
  types?: AccommodationType[];
  cancellable?: boolean;
  accessibilityNeeds?: string[];
  brands?: string[];
  mealPlans?: MealPlan[];
}

export enum SortOption {
  RELEVANCE = 'RELEVANCE',
  PRICE_ASC = 'PRICE_ASC',
  PRICE_DESC = 'PRICE_DESC',
  RATING = 'RATING',
  DISTANCE = 'DISTANCE',
  POPULARITY = 'POPULARITY',
}

export interface SearchResponse {
  properties: AccommodationProperty[];
  availability: Record<string, AvailabilitySummary>;
  totalResults: number;
  pageToken?: string;
  searchId: string;
  cacheMetadata?: CacheMetadata;
}

export interface AvailabilitySummary {
  propertyId: string;
  isAvailable: boolean;
  lowestPrice?: number;
  currency?: string;
  roomsAvailable?: number;
}

export interface CacheMetadata {
  cached: boolean;
  cacheAge?: number;
  ttl?: number;
}

export interface RecommendationRequest {
  userId?: string;
  sessionId?: string;
  context: RecommendationContext;
  limit?: number;
}

export interface RecommendationContext {
  tripId?: string;
  location?: SearchLocation;
  dateRange?: DateRange;
  budget?: Budget;
  preferences?: UserPreferences;
}

export interface Budget {
  min: number;
  max: number;
  currency: string;
}

export interface UserPreferences {
  favoriteTypes?: AccommodationType[];
  favoriteAmenities?: string[];
  favoriteBrands?: string[];
  accessibilityNeeds?: string[];
}

export interface RecommendationResponse {
  recommendations: RecommendedProperty[];
  explanations: Record<string, string>;
}

export interface RecommendedProperty {
  property: AccommodationProperty;
  score: number;
  explanation: string;
  matchReasons: string[];
}

export interface VoiceInterpretRequest {
  transcript: string;
  audioRef?: string;
  context?: SearchContext;
}

export interface SearchContext {
  previousSearch?: SearchRequest;
  sessionId?: string;
  userId?: string;
}

export interface VoiceInterpretResponse {
  intent: SearchIntent;
  normalizedParams: SearchRequest;
  nextPrompt?: string;
  confidence: number;
}

export interface SearchIntent {
  type: IntentType;
  entities: Record<string, any>;
}

export enum IntentType {
  SEARCH = 'SEARCH',
  FILTER = 'FILTER',
  SORT = 'SORT',
  BOOK = 'BOOK',
  DETAILS = 'DETAILS',
  HELP = 'HELP',
  CANCEL = 'CANCEL',
}