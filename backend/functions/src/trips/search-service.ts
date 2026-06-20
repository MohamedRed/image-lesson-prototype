import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { callOpenAI } from '../utils/openai';

const db = getFirestore();

// External API integrations (mocked for now)
interface ExternalAPIConfig {
    amadeus?: {
        clientId: string;
        clientSecret: string;
    };
    skyscanner?: {
        apiKey: string;
    };
    booking?: {
        apiKey: string;
    };
}

/**
 * Search flights using external APIs
 */
export const searchFlights = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { from, to, date, returnDate, passengers = 1 } = request.data;

            if (!from || !to || !date) {
                throw new HttpsError('invalid-argument', 'Missing required fields: from, to, date');
            }

            logger.info('Searching flights', { from, to, date, returnDate, passengers });

            // Mock flight search (in production, integrate with Amadeus, Skyscanner, etc.)
            const flights = await mockFlightSearch(from, to, date, returnDate, passengers);

            return { success: true, flights };

        } catch (error) {
            logger.error('Error searching flights', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to search flights');
        }
    }
);

/**
 * Search hotels using external APIs
 */
export const searchHotels = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { location, checkIn, checkOut, guests = 2, rooms = 1 } = request.data;

            if (!location || !checkIn || !checkOut) {
                throw new HttpsError('invalid-argument', 'Missing required fields: location, checkIn, checkOut');
            }

            logger.info('Searching hotels', { location, checkIn, checkOut, guests, rooms });

            // Mock hotel search (in production, integrate with Booking.com, Expedia, etc.)
            const hotels = await mockHotelSearch(location, checkIn, checkOut, guests, rooms);

            return { success: true, hotels };

        } catch (error) {
            logger.error('Error searching hotels', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to search hotels');
        }
    }
);

/**
 * Search points of interest
 */
export const searchPOIs = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { location, type, radius = 5000 } = request.data;

            if (!location) {
                throw new HttpsError('invalid-argument', 'Missing required field: location');
            }

            logger.info('Searching POIs', { location, type, radius });

            // Use AI to enhance POI search
            const prompt = `
                Find points of interest near: ${location}
                ${type ? `Type filter: ${type}` : ''}
                
                Return a JSON array with:
                - name: string
                - type: 'museum' | 'monument' | 'park' | 'beach' | 'restaurant' | 'shopping' | 'entertainment' | 'religious' | 'viewpoint' | 'market' | 'nightlife' | 'sports'
                - description: string
                - location: { latitude: number, longitude: number, address: string }
                - rating?: number (0-5)
                - reviewCount?: number
                - priceLevel?: 'free' | 'low' | 'moderate' | 'high' | 'luxury'
                - duration: number (recommended visit time in seconds)
                - ticketPrice?: { amount: number, currency: string }
                - bookingRequired: boolean
                - imageURLs: string[]
                - tags: string[]
                
                Limit to 20 results, prioritize highly-rated and popular attractions.
            `;

            const aiResponse = await callOpenAI([
                { role: 'system', content: 'You are a knowledgeable local guide. Provide accurate information about attractions and points of interest.' },
                { role: 'user', content: prompt }
            ]);

            let pois;
            try {
                pois = JSON.parse(aiResponse);
                if (!Array.isArray(pois)) {
                    pois = [];
                }
            } catch {
                pois = generateMockPOIs(location, type);
            }

            return { success: true, pois };

        } catch (error) {
            logger.error('Error searching POIs', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to search points of interest');
        }
    }
);

/**
 * Get availability calendar for flights, hotels, or activities
 */
export const getAvailabilityCalendar = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { type, location, month } = request.data;

            if (!type || !location || !month) {
                throw new HttpsError('invalid-argument', 'Missing required fields: type, location, month');
            }

            logger.info('Getting availability calendar', { type, location, month });

            // Generate mock availability data
            const calendar = generateMockAvailabilityCalendar(type, location, month);

            return { success: true, calendar };

        } catch (error) {
            logger.error('Error getting availability calendar', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to get availability calendar');
        }
    }
);

/**
 * Search activities and experiences
 */
export const searchActivities = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { location, category, date, duration } = request.data;

            if (!location) {
                throw new HttpsError('invalid-argument', 'Missing required field: location');
            }

            logger.info('Searching activities', { location, category, date, duration });

            // Use AI to find activities
            const prompt = `
                Find activities and experiences in: ${location}
                ${category ? `Category: ${category}` : ''}
                ${date ? `Date: ${date}` : ''}
                ${duration ? `Duration preference: ${duration} hours` : ''}
                
                Return a JSON array with:
                - name: string
                - category: string
                - description: string
                - location: { latitude: number, longitude: number, address: string }
                - duration: number (in hours)
                - price: { amount: number, currency: string }
                - rating?: number (0-5)
                - reviewCount?: number
                - difficulty?: 'easy' | 'moderate' | 'hard'
                - groupSize: { min: number, max: number }
                - includes: string[]
                - requirements: string[]
                - bookingRequired: boolean
                - cancellationPolicy: string
                - imageURLs: string[]
                - tags: string[]
                
                Focus on unique, authentic experiences. Limit to 15 results.
            `;

            const aiResponse = await callOpenAI([
                { role: 'system', content: 'You are a local experience curator. Provide diverse, authentic activities and tours.' },
                { role: 'user', content: prompt }
            ]);

            let activities;
            try {
                activities = JSON.parse(aiResponse);
                if (!Array.isArray(activities)) {
                    activities = [];
                }
            } catch {
                activities = generateMockActivities(location, category);
            }

            return { success: true, activities };

        } catch (error) {
            logger.error('Error searching activities', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to search activities');
        }
    }
);

// Mock functions (replace with real API integrations)

async function mockFlightSearch(from: string, to: string, date: string, returnDate?: string, passengers = 1) {
    const airlines = ['Delta', 'United', 'American', 'JetBlue', 'Southwest'];
    const flights = [];
    
    for (let i = 0; i < 5; i++) {
        const airline = airlines[Math.floor(Math.random() * airlines.length)];
        const basePrice = 300 + Math.random() * 500;
        
        const outbound = {
            segments: [{
                airline,
                flightNumber: `${airline.substring(0, 2).toUpperCase()}${Math.floor(Math.random() * 9000) + 1000}`,
                departure: {
                    code: getAirportCode(from),
                    name: `${from} Airport`,
                    city: from,
                    terminal: Math.floor(Math.random() * 4) + 1
                },
                arrival: {
                    code: getAirportCode(to),
                    name: `${to} Airport`,
                    city: to,
                    terminal: Math.floor(Math.random() * 4) + 1
                },
                departureTime: new Date(date + 'T08:00:00Z'),
                arrivalTime: new Date(date + 'T14:00:00Z'),
                duration: 6 * 3600, // 6 hours
                aircraft: 'Boeing 737'
            }],
            totalDuration: 6 * 3600,
            stops: 0
        };
        
        let inbound = null;
        if (returnDate) {
            inbound = {
                segments: [{
                    airline,
                    flightNumber: `${airline.substring(0, 2).toUpperCase()}${Math.floor(Math.random() * 9000) + 1000}`,
                    departure: {
                        code: getAirportCode(to),
                        name: `${to} Airport`,
                        city: to,
                        terminal: Math.floor(Math.random() * 4) + 1
                    },
                    arrival: {
                        code: getAirportCode(from),
                        name: `${from} Airport`,
                        city: from,
                        terminal: Math.floor(Math.random() * 4) + 1
                    },
                    departureTime: new Date(returnDate + 'T16:00:00Z'),
                    arrivalTime: new Date(returnDate + 'T22:00:00Z'),
                    duration: 6 * 3600,
                    aircraft: 'Boeing 737'
                }],
                totalDuration: 6 * 3600,
                stops: 0
            };
        }
        
        flights.push({
            id: `flight_${i}`,
            outbound,
            inbound,
            price: { amount: Math.round(basePrice), currency: 'USD' },
            bookingClass: Math.random() > 0.7 ? 'Business' : 'Economy',
            baggageIncluded: {
                carry: 1,
                checked: Math.random() > 0.5 ? 1 : 0,
                weight: 23
            },
            changeable: Math.random() > 0.3,
            refundable: Math.random() > 0.7,
            provider: `${airline} Direct`,
            deepLink: `https://example.com/book/flight_${i}`
        });
    }
    
    return flights;
}

async function mockHotelSearch(location: string, checkIn: string, checkOut: string, guests: number, rooms: number) {
    const hotelTypes = ['Hotel', 'Resort', 'Inn', 'Boutique Hotel', 'Grand Hotel'];
    const hotels = [];
    
    for (let i = 0; i < 8; i++) {
        const hotelType = hotelTypes[Math.floor(Math.random() * hotelTypes.length)];
        const basePrice = 100 + Math.random() * 400;
        const stars = Math.floor(Math.random() * 3) + 3; // 3-5 stars
        
        const roomTypes = [];
        const roomNames = ['Standard Room', 'Deluxe Room', 'Suite', 'Executive Room'];
        
        for (let j = 0; j < Math.floor(Math.random() * 3) + 1; j++) {
            roomTypes.push({
                id: `room_${i}_${j}`,
                name: roomNames[j % roomNames.length],
                description: `Comfortable ${roomNames[j % roomNames.length].toLowerCase()} with modern amenities`,
                maxOccupancy: 2 + Math.floor(Math.random() * 2),
                bedConfiguration: Math.random() > 0.5 ? '1 King bed' : '2 Queen beds',
                size: 25 + Math.floor(Math.random() * 20),
                price: { amount: Math.round(basePrice + j * 50), currency: 'USD' },
                breakfast: Math.random() > 0.5,
                available: Math.floor(Math.random() * 5) + 1
            });
        }
        
        hotels.push({
            id: `hotel_${i}`,
            name: `${location} ${hotelType}`,
            address: `${100 + i} Main Street, ${location}`,
            location: {
                latitude: 40.7128 + (Math.random() - 0.5) * 0.1,
                longitude: -74.0060 + (Math.random() - 0.5) * 0.1,
                address: `${100 + i} Main Street, ${location}`
            },
            starRating: stars,
            guestRating: 3.5 + Math.random() * 1.5,
            reviewCount: Math.floor(Math.random() * 5000) + 100,
            roomTypes,
            amenities: ['WiFi', 'Pool', 'Gym', 'Restaurant', 'Bar', 'Spa', 'Business Center'].slice(0, Math.floor(Math.random() * 5) + 3),
            images: [`https://example.com/hotel_${i}_1.jpg`, `https://example.com/hotel_${i}_2.jpg`],
            cancellationPolicy: 'Free cancellation up to 24 hours before check-in',
            provider: 'Hotels.com',
            deepLink: `https://example.com/book/hotel_${i}`
        });
    }
    
    return hotels;
}

function generateMockPOIs(location: string, type?: string) {
    const poiTypes = ['museum', 'monument', 'park', 'restaurant', 'shopping', 'entertainment', 'viewpoint'];
    const pois = [];
    
    for (let i = 0; i < 10; i++) {
        const poiType = type || poiTypes[Math.floor(Math.random() * poiTypes.length)];
        
        pois.push({
            id: `poi_${i}`,
            name: `${location} ${poiType.charAt(0).toUpperCase() + poiType.slice(1)} ${i + 1}`,
            type: poiType,
            description: `Popular ${poiType} in ${location}`,
            location: {
                latitude: 40.7128 + (Math.random() - 0.5) * 0.1,
                longitude: -74.0060 + (Math.random() - 0.5) * 0.1,
                address: `${100 + i} ${poiType.charAt(0).toUpperCase() + poiType.slice(1)} Street, ${location}`
            },
            rating: 3.5 + Math.random() * 1.5,
            reviewCount: Math.floor(Math.random() * 2000) + 50,
            priceLevel: ['free', 'low', 'moderate', 'high'][Math.floor(Math.random() * 4)],
            duration: (1 + Math.random() * 3) * 3600, // 1-4 hours
            ticketPrice: Math.random() > 0.3 ? { amount: Math.floor(Math.random() * 50) + 10, currency: 'USD' } : null,
            bookingRequired: Math.random() > 0.7,
            imageURLs: [`https://example.com/poi_${i}.jpg`],
            tags: ['popular', 'must-see', 'family-friendly'].slice(0, Math.floor(Math.random() * 3) + 1)
        });
    }
    
    return pois;
}

function generateMockActivities(location: string, category?: string) {
    const categories = ['tours', 'outdoor', 'cultural', 'food', 'adventure', 'wellness'];
    const activities = [];
    
    for (let i = 0; i < 8; i++) {
        const activityCategory = category || categories[Math.floor(Math.random() * categories.length)];
        
        activities.push({
            id: `activity_${i}`,
            name: `${location} ${activityCategory.charAt(0).toUpperCase() + activityCategory.slice(1)} Experience ${i + 1}`,
            category: activityCategory,
            description: `Authentic ${activityCategory} experience in ${location}`,
            location: {
                latitude: 40.7128 + (Math.random() - 0.5) * 0.1,
                longitude: -74.0060 + (Math.random() - 0.5) * 0.1,
                address: `Meeting Point ${i + 1}, ${location}`
            },
            duration: Math.floor(Math.random() * 6) + 2, // 2-8 hours
            price: { amount: Math.floor(Math.random() * 200) + 50, currency: 'USD' },
            rating: 4.0 + Math.random() * 1.0,
            reviewCount: Math.floor(Math.random() * 500) + 20,
            difficulty: ['easy', 'moderate', 'hard'][Math.floor(Math.random() * 3)],
            groupSize: { min: 1, max: Math.floor(Math.random() * 15) + 5 },
            includes: ['Guide', 'Transportation', 'Refreshments'].slice(0, Math.floor(Math.random() * 3) + 1),
            requirements: ['Comfortable walking shoes', 'Valid ID'].slice(0, Math.floor(Math.random() * 2) + 1),
            bookingRequired: true,
            cancellationPolicy: 'Free cancellation up to 24 hours before',
            imageURLs: [`https://example.com/activity_${i}.jpg`],
            tags: ['authentic', 'local', 'recommended'].slice(0, Math.floor(Math.random() * 3) + 1)
        });
    }
    
    return activities;
}

function generateMockAvailabilityCalendar(type: string, location: string, month: string) {
    const monthDate = new Date(month);
    const daysInMonth = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate();
    const days = [];
    
    for (let day = 1; day <= daysInMonth; day++) {
        const date = new Date(monthDate.getFullYear(), monthDate.getMonth(), day);
        const available = Math.random() > 0.2; // 80% availability
        const basePrice = type === 'hotel' ? 150 : type === 'flight' ? 300 : 75;
        const price = available ? basePrice + Math.random() * 100 : null;
        
        days.push({
            date: date.toISOString().split('T')[0],
            available,
            price: price ? { amount: Math.round(price), currency: 'USD' } : null,
            remaining: available ? Math.floor(Math.random() * 10) + 1 : 0
        });
    }
    
    return {
        type,
        location,
        month: monthDate.toISOString().split('T')[0],
        days
    };
}

function getAirportCode(city: string): string {
    const codes: { [key: string]: string } = {
        'New York': 'JFK',
        'Los Angeles': 'LAX',
        'Chicago': 'ORD',
        'Houston': 'IAH',
        'Phoenix': 'PHX',
        'Philadelphia': 'PHL',
        'San Antonio': 'SAT',
        'San Diego': 'SAN',
        'Dallas': 'DFW',
        'San Jose': 'SJC',
        'Paris': 'CDG',
        'London': 'LHR',
        'Tokyo': 'NRT',
        'Rome': 'FCO',
        'Barcelona': 'BCN',
        'Amsterdam': 'AMS',
        'Berlin': 'BER',
        'Madrid': 'MAD'
    };
    
    return codes[city] || city.substring(0, 3).toUpperCase();
}