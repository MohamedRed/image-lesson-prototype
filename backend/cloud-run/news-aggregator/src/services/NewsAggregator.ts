import axios from 'axios';
import RSSParser from 'rss-parser';
import * as cheerio from 'cheerio';
import { Firestore } from '@google-cloud/firestore';
import { VertexAI } from '@google-cloud/vertexai';
import { logger } from '../utils/logger';

interface NewsSource {
  id: string;
  name: string;
  type: 'rss' | 'api' | 'web';
  url: string;
  credibilityScore: number;
  categories: string[];
  language: string;
  region: string;
  updateFrequency: number; // hours
  lastFetched?: Date;
  isActive: boolean;
}

interface NewsArticle {
  id: string;
  title: string;
  summary: string;
  content?: string;
  url: string;
  imageUrl?: string;
  publishedAt: Date;
  author?: string;
  source: {
    id: string;
    name: string;
    credibilityScore: number;
  };
  categories: string[];
  tags: string[];
  healthConditions: string[];
  nutrients: string[];
  exercises: string[];
  credibilityMetrics: {
    sourceTrustScore: number;
    contentQualityScore: number;
    expertiseScore: number;
    recencyScore: number;
    overallScore: number;
  };
  engagement: {
    clicks: number;
    shares: number;
    bookmarks: number;
    avgReadTime: number;
  };
  moderation: {
    isVerified: boolean;
    hasDisclaimer: boolean;
    riskLevel: 'low' | 'medium' | 'high';
    flags: string[];
  };
}

export class NewsAggregator {
  private firestore: Firestore;
  private vertexai: VertexAI;
  private rssParser: RSSParser;
  private model: any;

  constructor() {
    this.firestore = new Firestore();
    this.vertexai = new VertexAI({
      project: process.env.GOOGLE_CLOUD_PROJECT || 'liive-health',
      location: 'us-central1',
    });
    this.rssParser = new RSSParser({
      customFields: {
        feed: ['image'],
        item: ['media:content', 'media:thumbnail', 'enclosure']
      }
    });
    
    this.model = this.vertexai.preview.getGenerativeModel({
      model: 'gemini-1.5-pro-002',
      generationConfig: {
        maxOutputTokens: 2048,
        temperature: 0.3,
      },
    });
  }

  // Fetch articles from all active sources
  async fetchAllNews(): Promise<NewsArticle[]> {
    logger.info('Starting news aggregation from all sources');

    try {
      const sources = await this.getActiveSources();
      const allArticles: NewsArticle[] = [];

      for (const source of sources) {
        try {
          logger.info(`Fetching from source: ${source.name}`);
          
          const articles = await this.fetchFromSource(source);
          const processedArticles = await this.processArticles(articles, source);
          
          allArticles.push(...processedArticles);
          
          // Update last fetched timestamp
          await this.updateSourceLastFetched(source.id);
          
        } catch (error) {
          logger.error(`Error fetching from source ${source.name}: ${error}`);
          continue;
        }
      }

      logger.info(`Fetched ${allArticles.length} articles from ${sources.length} sources`);
      
      // Store articles in Firestore
      await this.storeArticles(allArticles);
      
      return allArticles;

    } catch (error) {
      logger.error(`Error in news aggregation: ${error}`);
      throw error;
    }
  }

  // Fetch from specific source based on type
  private async fetchFromSource(source: NewsSource): Promise<Partial<NewsArticle>[]> {
    switch (source.type) {
      case 'rss':
        return await this.fetchFromRSS(source);
      case 'api':
        return await this.fetchFromAPI(source);
      case 'web':
        return await this.fetchFromWeb(source);
      default:
        throw new Error(`Unsupported source type: ${source.type}`);
    }
  }

  // RSS feed fetching
  private async fetchFromRSS(source: NewsSource): Promise<Partial<NewsArticle>[]> {
    try {
      const feed = await this.rssParser.parseURL(source.url);
      
      return feed.items.map(item => ({
        title: item.title || '',
        summary: item.contentSnippet || item.content || '',
        url: item.link || '',
        publishedAt: new Date(item.pubDate || Date.now()),
        author: item.creator || item.author,
        imageUrl: this.extractImageFromRSSItem(item)
      })).filter(article => article.title && article.url);

    } catch (error) {
      logger.error(`RSS fetch error for ${source.name}: ${error}`);
      return [];
    }
  }

  // API-based fetching (for sources with APIs)
  private async fetchFromAPI(source: NewsSource): Promise<Partial<NewsArticle>[]> {
    try {
      // Example implementation for NewsAPI or similar services
      const response = await axios.get(source.url, {
        headers: {
          'Authorization': `Bearer ${process.env.NEWS_API_KEY}`,
          'User-Agent': 'Liive Health News Aggregator'
        },
        timeout: 30000
      });

      if (response.data && response.data.articles) {
        return response.data.articles.map((article: any) => ({
          title: article.title,
          summary: article.description,
          content: article.content,
          url: article.url,
          publishedAt: new Date(article.publishedAt),
          author: article.author,
          imageUrl: article.urlToImage
        }));
      }

      return [];

    } catch (error) {
      logger.error(`API fetch error for ${source.name}: ${error}`);
      return [];
    }
  }

  // Web scraping for sources without RSS/API
  private async fetchFromWeb(source: NewsSource): Promise<Partial<NewsArticle>[]> {
    try {
      const response = await axios.get(source.url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Liive Health Aggregator)'
        },
        timeout: 30000
      });

      const $ = cheerio.load(response.data);
      const articles: Partial<NewsArticle>[] = [];

      // Generic article extraction (would be customized per site)
      $('article, .article, [class*="post"], [class*="news"]').each((i, element) => {
        const $el = $(element);
        
        const title = $el.find('h1, h2, h3, .title, [class*="title"]').first().text().trim();
        const summary = $el.find('p, .summary, [class*="excerpt"]').first().text().trim();
        const url = $el.find('a').first().attr('href');
        const imageUrl = $el.find('img').first().attr('src');
        
        if (title && url) {
          articles.push({
            title,
            summary: summary.substring(0, 300),
            url: url.startsWith('http') ? url : new URL(url, source.url).href,
            imageUrl: imageUrl && imageUrl.startsWith('http') ? imageUrl : 
                      imageUrl ? new URL(imageUrl, source.url).href : undefined,
            publishedAt: new Date() // Default to now for web scraping
          });
        }
      });

      return articles.slice(0, 20); // Limit per source

    } catch (error) {
      logger.error(`Web scraping error for ${source.name}: ${error}`);
      return [];
    }
  }

  // Process and enhance articles with AI
  private async processArticles(articles: Partial<NewsArticle>[], source: NewsSource): Promise<NewsArticle[]> {
    const processedArticles: NewsArticle[] = [];

    for (const article of articles) {
      try {
        if (!article.title || !article.url) continue;

        // AI classification and tagging
        const aiAnalysis = await this.analyzeArticleWithAI(article);
        
        // Check for duplicates
        const isDuplicate = await this.checkForDuplicate(article.url!);
        if (isDuplicate) continue;

        // Generate credibility scores
        const credibilityMetrics = this.calculateCredibilityMetrics(article, source, aiAnalysis);
        
        // Content moderation
        const moderation = await this.moderateContent(article, aiAnalysis);
        
        // Skip low-quality or risky content
        if (credibilityMetrics.overallScore < 0.3 || moderation.riskLevel === 'high') {
          continue;
        }

        const processedArticle: NewsArticle = {
          id: this.generateArticleId(article.url!),
          title: article.title,
          summary: aiAnalysis.enhancedSummary || article.summary || '',
          content: article.content,
          url: article.url,
          imageUrl: article.imageUrl,
          publishedAt: article.publishedAt || new Date(),
          author: article.author,
          source: {
            id: source.id,
            name: source.name,
            credibilityScore: source.credibilityScore
          },
          categories: aiAnalysis.categories || [],
          tags: aiAnalysis.tags || [],
          healthConditions: aiAnalysis.healthConditions || [],
          nutrients: aiAnalysis.nutrients || [],
          exercises: aiAnalysis.exercises || [],
          credibilityMetrics,
          engagement: {
            clicks: 0,
            shares: 0,
            bookmarks: 0,
            avgReadTime: this.estimateReadTime(article.summary || '')
          },
          moderation
        };

        processedArticles.push(processedArticle);

      } catch (error) {
        logger.error(`Error processing article "${article.title}": ${error}`);
        continue;
      }
    }

    return processedArticles;
  }

  // AI-powered article analysis and classification
  private async analyzeArticleWithAI(article: Partial<NewsArticle>): Promise<any> {
    try {
      const prompt = `
Analyze this health news article and provide structured classification:

Title: ${article.title}
Summary: ${article.summary || ''}
URL: ${article.url}

Please provide analysis in JSON format:
{
  "categories": ["list of relevant health categories"],
  "tags": ["relevant tags for searchability"],
  "healthConditions": ["specific conditions mentioned"],
  "nutrients": ["nutrients or supplements mentioned"],
  "exercises": ["exercises or activities mentioned"],
  "enhancedSummary": "improved summary if original is poor",
  "qualityScore": 0.8,
  "expertiseLevel": "basic|intermediate|advanced",
  "targetAudience": "general|patients|professionals",
  "contentType": "news|research|opinion|guide",
  "riskFactors": ["potential misinformation risks"],
  "evidenceLevel": "high|medium|low|none"
}

Categories should be from: nutrition, fitness, mental-health, sleep, chronic-disease, prevention, research, policy, technology, supplements, alternative-medicine

Focus on accuracy and safety. Flag potential misinformation.
`;

      const result = await this.model.generateContent([{ parts: [{ text: prompt }] }]);
      
      if (result.response.candidates?.[0]?.content?.parts?.[0]?.text) {
        try {
          return JSON.parse(result.response.candidates[0].content.parts[0].text);
        } catch (parseError) {
          logger.warn(`Failed to parse AI analysis for article: ${article.title}`);
          return this.getDefaultAnalysis();
        }
      }

      return this.getDefaultAnalysis();

    } catch (error) {
      logger.error(`AI analysis error for article "${article.title}": ${error}`);
      return this.getDefaultAnalysis();
    }
  }

  // Calculate credibility metrics
  private calculateCredibilityMetrics(article: Partial<NewsArticle>, source: NewsSource, aiAnalysis: any): NewsArticle['credibilityMetrics'] {
    const sourceTrustScore = source.credibilityScore;
    
    const contentQualityScore = Math.min(1, (
      (article.summary && article.summary.length > 100 ? 0.3 : 0) +
      (article.author ? 0.2 : 0) +
      (aiAnalysis.evidenceLevel === 'high' ? 0.3 : aiAnalysis.evidenceLevel === 'medium' ? 0.2 : 0.1) +
      (aiAnalysis.qualityScore || 0.5) * 0.2
    ));

    const expertiseScore = aiAnalysis.expertiseLevel === 'advanced' ? 0.9 : 
                          aiAnalysis.expertiseLevel === 'intermediate' ? 0.7 : 0.5;

    const recencyScore = this.calculateRecencyScore(article.publishedAt || new Date());

    const overallScore = (
      sourceTrustScore * 0.3 +
      contentQualityScore * 0.3 +
      expertiseScore * 0.2 +
      recencyScore * 0.2
    );

    return {
      sourceTrustScore,
      contentQualityScore,
      expertiseScore,
      recencyScore,
      overallScore
    };
  }

  // Content moderation
  private async moderateContent(article: Partial<NewsArticle>, aiAnalysis: any): Promise<NewsArticle['moderation']> {
    const riskFactors = aiAnalysis.riskFactors || [];
    
    const riskLevel: 'low' | 'medium' | 'high' = 
      riskFactors.length > 2 ? 'high' :
      riskFactors.length > 0 ? 'medium' : 'low';

    return {
      isVerified: aiAnalysis.evidenceLevel === 'high',
      hasDisclaimer: this.needsHealthDisclaimer(aiAnalysis),
      riskLevel,
      flags: riskFactors
    };
  }

  // Store processed articles in Firestore
  private async storeArticles(articles: NewsArticle[]): Promise<void> {
    if (articles.length === 0) return;

    const batch = this.firestore.batch();
    const now = new Date();

    articles.forEach(article => {
      const docRef = this.firestore
        .collection('healthNews')
        .doc(article.id);

      batch.set(docRef, {
        ...article,
        createdAt: now,
        updatedAt: now
      });
    });

    await batch.commit();
    logger.info(`Stored ${articles.length} articles in Firestore`);
  }

  // Get active news sources
  private async getActiveSources(): Promise<NewsSource[]> {
    try {
      const sourcesSnapshot = await this.firestore
        .collection('newsSources')
        .where('isActive', '==', true)
        .get();

      if (sourcesSnapshot.empty) {
        // Return default sources if none configured
        return this.getDefaultSources();
      }

      return sourcesSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as NewsSource));

    } catch (error) {
      logger.error(`Error getting news sources: ${error}`);
      return this.getDefaultSources();
    }
  }

  // Default curated health news sources
  private getDefaultSources(): NewsSource[] {
    return [
      {
        id: 'cdc-health-news',
        name: 'CDC Health News',
        type: 'rss',
        url: 'https://tools.cdc.gov/api/embed/downloader/download.asp?m=404952&c=451398',
        credibilityScore: 0.95,
        categories: ['public-health', 'disease-prevention', 'research'],
        language: 'en',
        region: 'US',
        updateFrequency: 12,
        isActive: true
      },
      {
        id: 'nih-news',
        name: 'NIH News Releases',
        type: 'rss',
        url: 'https://www.nih.gov/news-events/news-releases/rss.xml',
        credibilityScore: 0.95,
        categories: ['research', 'medical-breakthroughs', 'health-policy'],
        language: 'en',
        region: 'US',
        updateFrequency: 24,
        isActive: true
      },
      {
        id: 'harvard-health',
        name: 'Harvard Health Publishing',
        type: 'rss',
        url: 'https://www.health.harvard.edu/blog/rss',
        credibilityScore: 0.90,
        categories: ['wellness', 'nutrition', 'fitness', 'mental-health'],
        language: 'en',
        region: 'US',
        updateFrequency: 24,
        isActive: true
      },
      {
        id: 'mayo-clinic-news',
        name: 'Mayo Clinic News',
        type: 'rss',
        url: 'https://newsnetwork.mayoclinic.org/feed/',
        credibilityScore: 0.92,
        categories: ['medical-news', 'patient-care', 'health-tips'],
        language: 'en',
        region: 'US',
        updateFrequency: 12,
        isActive: true
      },
      {
        id: 'webmd-news',
        name: 'WebMD Health News',
        type: 'rss',
        url: 'https://www.webmd.com/rss/rss.aspx?RSSSource=RSS_PUBLIC',
        credibilityScore: 0.75,
        categories: ['health-news', 'wellness', 'conditions'],
        language: 'en',
        region: 'US',
        updateFrequency: 6,
        isActive: true
      }
    ];
  }

  // Helper methods
  private extractImageFromRSSItem(item: any): string | undefined {
    // Try various RSS image fields
    if (item['media:content'] && item['media:content']['$'] && item['media:content']['$'].url) {
      return item['media:content']['$'].url;
    }
    if (item['media:thumbnail'] && item['media:thumbnail']['$'] && item['media:thumbnail']['$'].url) {
      return item['media:thumbnail']['$'].url;
    }
    if (item.enclosure && item.enclosure.url && item.enclosure.type && item.enclosure.type.startsWith('image/')) {
      return item.enclosure.url;
    }
    return undefined;
  }

  private generateArticleId(url: string): string {
    return Buffer.from(url).toString('base64').replace(/[+/=]/g, '').substring(0, 20);
  }

  private async checkForDuplicate(url: string): Promise<boolean> {
    const existing = await this.firestore
      .collection('healthNews')
      .where('url', '==', url)
      .limit(1)
      .get();

    return !existing.empty;
  }

  private calculateRecencyScore(publishedAt: Date): number {
    const ageInDays = (Date.now() - publishedAt.getTime()) / (1000 * 60 * 60 * 24);
    
    if (ageInDays <= 1) return 1.0;
    if (ageInDays <= 7) return 0.8;
    if (ageInDays <= 30) return 0.6;
    if (ageInDays <= 90) return 0.4;
    return 0.2;
  }

  private estimateReadTime(text: string): number {
    const wordsPerMinute = 200;
    const wordCount = text.split(/\s+/).length;
    return Math.max(1, Math.round(wordCount / wordsPerMinute));
  }

  private needsHealthDisclaimer(aiAnalysis: any): boolean {
    return aiAnalysis.contentType === 'guide' || 
           aiAnalysis.categories?.includes('supplements') ||
           aiAnalysis.categories?.includes('alternative-medicine') ||
           aiAnalysis.targetAudience === 'patients';
  }

  private getDefaultAnalysis(): any {
    return {
      categories: ['health-news'],
      tags: [],
      healthConditions: [],
      nutrients: [],
      exercises: [],
      enhancedSummary: null,
      qualityScore: 0.5,
      expertiseLevel: 'basic',
      targetAudience: 'general',
      contentType: 'news',
      riskFactors: [],
      evidenceLevel: 'medium'
    };
  }

  private async updateSourceLastFetched(sourceId: string): Promise<void> {
    await this.firestore
      .collection('newsSources')
      .doc(sourceId)
      .update({
        lastFetched: new Date()
      });
  }
}

export const newsAggregator = new NewsAggregator();