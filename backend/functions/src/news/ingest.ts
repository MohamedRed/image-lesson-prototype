import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import fetch from 'node-fetch';
import * as crypto from 'crypto';
import { getSecret, secretPath, SECRET_IDS } from '../shared/secretManager';

const db = admin.firestore();

// Connector interface
export interface NewsConnector {
  name: string;
  fetchBatch(params: FetchParams): Promise<NormalizedArticle[]>;
  rateLimit?: { perMinute: number };
}

export interface FetchParams {
  query?: string;
  categories?: string[];
  languages?: string[];
  countries?: string[];
  from?: Date;
  to?: Date;
  pageSize?: number;
  page?: number;
}

export interface NormalizedArticle {
  sourceId?: string;
  sourceName: string;
  author?: string;
  title: string;
  description?: string;
  url: string;
  urlToImage?: string;
  publishedAt: Date;
  content?: string;
  language?: string;
  country?: string;
  category?: string;
}

// NewsAPI.org Connector
export class NewsAPIConnector implements NewsConnector {
  name = 'NewsAPI';
  private apiKey: string;
  rateLimit = { perMinute: 100 };

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async fetchBatch(params: FetchParams): Promise<NormalizedArticle[]> {
    const endpoint = params.query ? 'everything' : 'top-headlines';
    const url = new URL(`https://newsapi.org/v2/${endpoint}`);
    
    const queryParams: any = {
      apiKey: this.apiKey,
      pageSize: params.pageSize || 100,
      page: params.page || 1,
    };

    if (params.query) queryParams.q = params.query;
    if (params.languages?.length) queryParams.language = params.languages[0];
    if (params.countries?.length && endpoint === 'top-headlines') {
      queryParams.country = params.countries[0];
    }
    if (params.from) queryParams.from = params.from.toISOString();
    if (params.to) queryParams.to = params.to.toISOString();
    if (params.categories?.length && endpoint === 'top-headlines') {
      queryParams.category = params.categories[0];
    }

    Object.keys(queryParams).forEach(key => 
      url.searchParams.append(key, queryParams[key])
    );

    try {
      const response = await fetch(url.toString());
      const data = await response.json() as any;
      
      if (data.status !== 'ok') {
        throw new Error(`NewsAPI error: ${data.message || 'Unknown error'}`);
      }

      return (data.articles || []).map((article: any) => ({
        sourceId: article.source?.id,
        sourceName: article.source?.name || 'Unknown',
        author: article.author,
        title: article.title,
        description: article.description,
        url: article.url,
        urlToImage: article.urlToImage,
        publishedAt: new Date(article.publishedAt),
        content: article.content,
        language: params.languages?.[0],
        country: params.countries?.[0],
      }));
    } catch (error) {
      console.error('NewsAPI fetch error:', error);
      throw error;
    }
  }
}

// Article deduplication and clustering
export async function dedupeAndCluster(articles: NormalizedArticle[]): Promise<Map<string, NormalizedArticle[]>> {
  const clusters = new Map<string, NormalizedArticle[]>();
  
  for (const article of articles) {
    // Generate canonical fingerprint
    const fingerprint = generateFingerprint(article);
    
    // Find similar cluster or create new one
    let clusterId: string | null = null;
    
    for (const [id, clusterArticles] of clusters.entries()) {
      if (isSimilar(article, clusterArticles[0])) {
        clusterId = id;
        break;
      }
    }
    
    if (!clusterId) {
      clusterId = generateClusterId(article);
      clusters.set(clusterId, []);
    }
    
    // Check if not duplicate within cluster
    const isDupe = clusters.get(clusterId)!.some(a => 
      generateFingerprint(a) === fingerprint
    );
    
    if (!isDupe) {
      clusters.get(clusterId)!.push(article);
    }
  }
  
  return clusters;
}

function generateFingerprint(article: NormalizedArticle): string {
  const normalized = `${article.url}|${article.title.toLowerCase().trim()}`;
  return crypto.createHash('md5').update(normalized).digest('hex');
}

function generateClusterId(article: NormalizedArticle): string {
  const titleWords = article.title.toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .split(/\s+/)
    .slice(0, 5)
    .join('-');
  
  const timestamp = Math.floor(Date.now() / (1000 * 60 * 60)); // Hour precision
  return `${titleWords}-${timestamp}`;
}

function isSimilar(a1: NormalizedArticle, a2: NormalizedArticle): boolean {
  // Simple Jaccard similarity on title words
  const words1 = new Set(a1.title.toLowerCase().split(/\s+/));
  const words2 = new Set(a2.title.toLowerCase().split(/\s+/));
  
  const intersection = new Set([...words1].filter(x => words2.has(x)));
  const union = new Set([...words1, ...words2]);
  
  const similarity = intersection.size / union.size;
  return similarity > 0.5; // Threshold for clustering
}

// Create or update news events from clusters
export async function createNewsEvents(
  clusters: Map<string, NormalizedArticle[]>
): Promise<string[]> {
  const eventIds: string[] = [];
  const batch = db.batch();
  
  for (const [clusterId, articles] of clusters.entries()) {
    if (articles.length === 0) continue;
    
    // Sort articles by date
    articles.sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime());
    
    // Generate event summary from articles
    const event = {
      clusterId,
      topicKey: clusterId,
      title: generateEventTitle(articles),
      summary: generateEventSummary(articles),
      goodness: 'neutral', // Will be classified by enrichment
      tags: extractTags(articles),
      regions: extractRegions(articles),
      languages: extractLanguages(articles),
      articleCount: articles.length,
      firstSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      thumbnailUrl: articles.find(a => a.urlToImage)?.urlToImage,
      provenance: {
        connectors: ['NewsAPI'],
        method: 'clustering_v1'
      }
    };
    
    const eventRef = db.collection('newsEvents').doc(clusterId);
    batch.set(eventRef, event, { merge: true });
    
    // Add articles as subcollection
    for (const article of articles) {
      const articleId = generateFingerprint(article);
      const articleRef = eventRef.collection('articles').doc(articleId);
      
      batch.set(articleRef, {
        ...article,
        publishedAt: admin.firestore.Timestamp.fromDate(article.publishedAt),
        canonicalFingerprint: articleId,
        dedupeGroup: clusterId,
        addedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    eventIds.push(clusterId);
  }
  
  await batch.commit();
  return eventIds;
}

function generateEventTitle(articles: NormalizedArticle[]): string {
  // Use most common title patterns or first article title
  return articles[0].title;
}

function generateEventSummary(articles: NormalizedArticle[]): string {
  // Combine descriptions from top articles
  const descriptions = articles
    .slice(0, 3)
    .map(a => a.description)
    .filter(Boolean);
  
  if (descriptions.length === 0) return articles[0].title;
  
  // Simple summary: combine and truncate
  const combined = descriptions.join(' ');
  return combined.length > 300 
    ? combined.substring(0, 297) + '...' 
    : combined;
}

function extractTags(articles: NormalizedArticle[]): string[] {
  const tags = new Set<string>();
  
  // Extract from categories
  articles.forEach(a => {
    if (a.category) tags.add(a.category);
  });
  
  // Add common news tags based on content
  const allText = articles.map(a => 
    `${a.title} ${a.description || ''}`
  ).join(' ').toLowerCase();
  
  const tagKeywords = {
    'Technology': ['tech', 'ai', 'software', 'computer', 'digital'],
    'Politics': ['election', 'government', 'president', 'minister', 'policy'],
    'Economy': ['economy', 'market', 'finance', 'stock', 'trade'],
    'Health': ['health', 'medical', 'covid', 'vaccine', 'disease'],
    'Environment': ['climate', 'environment', 'pollution', 'energy', 'renewable'],
    'Science': ['research', 'study', 'scientist', 'discovery', 'space'],
    'Sports': ['sport', 'game', 'player', 'team', 'championship'],
    'Culture': ['art', 'music', 'film', 'culture', 'festival']
  };
  
  for (const [tag, keywords] of Object.entries(tagKeywords)) {
    if (keywords.some(kw => allText.includes(kw))) {
      tags.add(tag);
    }
  }
  
  return Array.from(tags).slice(0, 5);
}

function extractRegions(articles: NormalizedArticle[]): string[] {
  const regions = new Set<string>();
  
  const countryToRegion: Record<string, string> = {
    'us': 'North America',
    'ca': 'North America',
    'mx': 'North America',
    'gb': 'Europe',
    'fr': 'Europe',
    'de': 'Europe',
    'it': 'Europe',
    'es': 'Europe',
    'cn': 'Asia',
    'jp': 'Asia',
    'in': 'Asia',
    'kr': 'Asia',
    'au': 'Oceania',
    'nz': 'Oceania',
    'za': 'Africa',
    'eg': 'Middle East',
    'sa': 'Middle East',
    'ae': 'Middle East',
    'br': 'Latin America',
    'ar': 'Latin America',
  };
  
  articles.forEach(a => {
    if (a.country) {
      const region = countryToRegion[a.country.toLowerCase()];
      if (region) regions.add(region);
    }
  });
  
  if (regions.size === 0) regions.add('Global');
  
  return Array.from(regions);
}

function extractLanguages(articles: NormalizedArticle[]): string[] {
  const languages = new Set<string>();
  
  articles.forEach(a => {
    if (a.language) languages.add(a.language);
  });
  
  if (languages.size === 0) languages.add('en');
  
  return Array.from(languages);
}

// Scheduled function to ingest news
export const ingestNews = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '1GB'
  })
  .pubsub.schedule('every 10 minutes')
  .onRun(async (context) => {
    try {
      // Get API key from Secret Manager
      const apiKey = await getSecret(secretPath(SECRET_IDS.NEWSAPI_KEY));
      if (!apiKey) {
        throw new Error('NewsAPI key not found');
      }
      
      const connector = new NewsAPIConnector(apiKey);
      
      // Fetch latest news
      const articles = await connector.fetchBatch({
        pageSize: 100,
        languages: ['en'],
        categories: ['general', 'technology', 'science', 'health', 'business']
      });
      
      console.log(`Fetched ${articles.length} articles`);
      
      // Dedupe and cluster
      const clusters = await dedupeAndCluster(articles);
      console.log(`Created ${clusters.size} clusters`);
      
      // Create news events
      const eventIds = await createNewsEvents(clusters);
      console.log(`Created/updated ${eventIds.length} news events`);
      
      // Trigger enrichment for new events
      for (const eventId of eventIds) {
        await admin.firestore()
          .collection('enrichmentQueue')
          .add({
            eventId,
            type: 'news_event',
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
      }
      
      return { success: true, eventsCreated: eventIds.length };
    } catch (error) {
      console.error('News ingestion error:', error);
      throw error;
    }
  });