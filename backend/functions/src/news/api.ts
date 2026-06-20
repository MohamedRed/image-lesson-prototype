import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as express from 'express';
import * as cors from 'cors';

const db = admin.firestore();
const app = express();

// Enable CORS
app.use(cors({ origin: true }));
app.use(express.json());

// List news events
app.get('/events', async (req, res) => {
  try {
    const { goodness, region, tag, limit = 20, cursor } = req.query;
    
    let query = db.collection('newsEvents')
      .orderBy('lastUpdatedAt', 'desc')
      .limit(Number(limit));
    
    if (goodness && goodness !== 'all') {
      query = query.where('goodness', '==', goodness);
    }
    
    if (region) {
      query = query.where('regions', 'array-contains', region);
    }
    
    if (tag) {
      query = query.where('tags', 'array-contains', tag);
    }
    
    if (cursor) {
      const lastDoc = await db.collection('newsEvents').doc(String(cursor)).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }
    
    const snapshot = await query.get();
    
    const events = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      // Convert Firestore timestamps
      lastUpdatedAt: doc.data().lastUpdatedAt?.toDate?.() || new Date(),
      firstSeenAt: doc.data().firstSeenAt?.toDate?.() || new Date(),
      // Simplify perspectives for list view
      perspectives: (doc.data().perspectives || []).map((p: any) => ({
        id: p.id,
        label: p.label
      }))
    }));
    
    const nextCursor = snapshot.docs.length > 0 
      ? snapshot.docs[snapshot.docs.length - 1].id 
      : null;
    
    res.json({
      events,
      nextCursor,
      total: snapshot.size
    });
  } catch (error) {
    console.error('Error listing events:', error);
    res.status(500).json({ error: 'Failed to list events' });
  }
});

// Get single event details
app.get('/events/:eventId', async (req, res) => {
  try {
    const { eventId } = req.params;
    
    const doc = await db.collection('newsEvents').doc(eventId).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Event not found' });
    }
    
    const event = {
      id: doc.id,
      ...doc.data(),
      lastUpdatedAt: doc.data()?.lastUpdatedAt?.toDate?.() || new Date(),
      firstSeenAt: doc.data()?.firstSeenAt?.toDate?.() || new Date(),
      enrichedAt: doc.data()?.enrichedAt?.toDate?.(),
      historicalContext: doc.data()?.historicalContext ? {
        ...doc.data()?.historicalContext,
        generatedAt: doc.data()?.historicalContext?.generatedAt?.toDate?.()
      } : null
    };
    
    res.json(event);
  } catch (error) {
    console.error('Error getting event:', error);
    res.status(500).json({ error: 'Failed to get event' });
  }
});

// List articles for an event
app.get('/events/:eventId/articles', async (req, res) => {
  try {
    const { eventId } = req.params;
    const { limit = 20, cursor } = req.query;
    
    let query = db.collection('newsEvents')
      .doc(eventId)
      .collection('articles')
      .orderBy('publishedAt', 'desc')
      .limit(Number(limit));
    
    if (cursor) {
      const lastDoc = await db.collection('newsEvents')
        .doc(eventId)
        .collection('articles')
        .doc(String(cursor))
        .get();
      
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }
    
    const snapshot = await query.get();
    
    const articles = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      publishedAt: doc.data().publishedAt?.toDate?.() || new Date(),
      addedAt: doc.data().addedAt?.toDate?.()
    }));
    
    const nextCursor = snapshot.docs.length > 0 
      ? snapshot.docs[snapshot.docs.length - 1].id 
      : null;
    
    res.json({
      articles,
      nextCursor,
      total: snapshot.size
    });
  } catch (error) {
    console.error('Error listing articles:', error);
    res.status(500).json({ error: 'Failed to list articles' });
  }
});

// Refresh event (trigger re-enrichment)
app.post('/events/:eventId/refresh', async (req, res) => {
  try {
    const { eventId } = req.params;
    
    // Check if user is authenticated and has admin role
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Check admin role (implement your own role checking)
    // For now, just check if authenticated
    if (!decodedToken.uid) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    // Add to enrichment queue
    await db.collection('enrichmentQueue').add({
      eventId,
      type: 'news_event',
      status: 'pending',
      requestedBy: decodedToken.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true, 
      message: 'Event queued for refresh' 
    });
  } catch (error) {
    console.error('Error refreshing event:', error);
    res.status(500).json({ error: 'Failed to refresh event' });
  }
});

// Export the Express app as a Cloud Function
export const newsApi = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB'
  })
  .https.onRequest(app);