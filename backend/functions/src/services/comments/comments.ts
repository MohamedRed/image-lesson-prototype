import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

export interface CommentData {
  authorUid: string;
  authorName: string;
  text: string;
  replyTo?: string;
  sentiment?: string;
  clusterId?: string;
}

export interface CommentCluster {
  id: string;
  label: string;
  count: number;
  sentiment?: string;
}

// Submit a comment
export const submitComment = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to post comments'
      );
    }

    const { parentCollection, parentId, text, replyTo } = data;

    if (!parentCollection || !parentId || !text) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    if (typeof text !== 'string' || text.trim().length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Comment text must be a non-empty string'
      );
    }

    if (text.length > 2000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Comment text must be 2000 characters or less'
      );
    }

    const uid = context.auth.uid;
    const userRecord = await admin.auth().getUser(uid);
    const displayName = userRecord.displayName || userRecord.email?.split('@')[0] || 'Anonymous';

    try {
      // Rate limiting check
      const rateLimitKey = `${uid}:${parentCollection}:${parentId}`;
      const rateLimitRef = db.collection('_rateLimit').doc(rateLimitKey);
      const rateLimitDoc = await rateLimitRef.get();
      
      const now = Date.now();
      const windowMs = 60 * 1000; // 1 minute
      const maxRequests = 10;

      if (rateLimitDoc.exists) {
        const data = rateLimitDoc.data()!;
        const windowStart = data.windowStart;
        const requestCount = data.requestCount;

        if (now - windowStart < windowMs) {
          if (requestCount >= maxRequests) {
            throw new functions.https.HttpsError(
              'resource-exhausted',
              'Too many comments. Please wait before posting again.'
            );
          }
          await rateLimitRef.update({
            requestCount: admin.firestore.FieldValue.increment(1)
          });
        } else {
          await rateLimitRef.set({
            windowStart: now,
            requestCount: 1
          });
        }
      } else {
        await rateLimitRef.set({
          windowStart: now,
          requestCount: 1
        });
      }

      // Validate reply parent exists
      if (replyTo) {
        const parentCommentRef = db
          .collection(parentCollection)
          .doc(parentId)
          .collection('comments')
          .doc(replyTo);
        
        const parentCommentDoc = await parentCommentRef.get();
        if (!parentCommentDoc.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            'Parent comment not found'
          );
        }
      }

      // Basic content moderation
      const cleanedText = moderateContent(text);
      
      // Sentiment analysis (simple)
      const sentiment = analyzeSentiment(cleanedText);

      // Create comment
      const commentData: CommentData = {
        authorUid: uid,
        authorName: displayName,
        text: cleanedText,
        replyTo: replyTo || null,
        sentiment
      };

      const commentRef = await db
        .collection(parentCollection)
        .doc(parentId)
        .collection('comments')
        .add({
          ...commentData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          reactionCounts: {
            like: 0,
            dislike: 0
          },
          flags: {}
        });

      // Update comment summary in parent document
      await updateCommentSummary(parentCollection, parentId);

      return { 
        commentId: commentRef.id,
        success: true 
      };
    } catch (error) {
      console.error('Error submitting comment:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to submit comment'
      );
    }
  });

// Delete a comment
export const deleteComment = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { parentCollection, parentId, commentId } = data;

    if (!parentCollection || !parentId || !commentId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    try {
      const commentRef = db
        .collection(parentCollection)
        .doc(parentId)
        .collection('comments')
        .doc(commentId);

      const commentDoc = await commentRef.get();

      if (!commentDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Comment not found'
        );
      }

      const commentData = commentDoc.data()!;

      // Check if user owns the comment or is admin
      if (commentData.authorUid !== context.auth.uid) {
        // TODO: Check for admin role
        throw new functions.https.HttpsError(
          'permission-denied',
          'You can only delete your own comments'
        );
      }

      // Soft delete by marking as deleted
      await commentRef.update({
        text: '[deleted]',
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedBy: context.auth.uid
      });

      // Update comment summary
      await updateCommentSummary(parentCollection, parentId);

      return { success: true };
    } catch (error) {
      console.error('Error deleting comment:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to delete comment'
      );
    }
  });

// React to a comment (like/dislike)
export const reactToComment = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { parentCollection, parentId, commentId, value } = data;

    if (!parentCollection || !parentId || !commentId || value === undefined) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    if (![1, 0, -1].includes(value)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Reaction value must be 1 (like), -1 (dislike), or 0 (remove)'
      );
    }

    const uid = context.auth.uid;

    try {
      await db.runTransaction(async (transaction) => {
        const commentRef = db
          .collection(parentCollection)
          .doc(parentId)
          .collection('comments')
          .doc(commentId);

        const reactionRef = commentRef
          .collection('reactions')
          .doc(uid);

        const commentDoc = await transaction.get(commentRef);
        const reactionDoc = await transaction.get(reactionRef);

        if (!commentDoc.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            'Comment not found'
          );
        }

        const currentReactionCounts = commentDoc.data()?.reactionCounts || {
          like: 0,
          dislike: 0
        };

        // Remove old reaction
        if (reactionDoc.exists) {
          const oldValue = reactionDoc.data()?.value;
          if (oldValue === 1) {
            currentReactionCounts.like = Math.max(0, currentReactionCounts.like - 1);
          } else if (oldValue === -1) {
            currentReactionCounts.dislike = Math.max(0, currentReactionCounts.dislike - 1);
          }
        }

        // Add new reaction
        if (value === 1) {
          currentReactionCounts.like += 1;
          transaction.set(reactionRef, {
            value,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
        } else if (value === -1) {
          currentReactionCounts.dislike += 1;
          transaction.set(reactionRef, {
            value,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          transaction.delete(reactionRef);
        }

        // Update comment reaction counts
        transaction.update(commentRef, {
          reactionCounts: currentReactionCounts
        });
      });

      return { success: true };
    } catch (error) {
      console.error('Error reacting to comment:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'Failed to react to comment'
      );
    }
  });

// Update comment summary for parent document
async function updateCommentSummary(
  parentCollection: string, 
  parentId: string
): Promise<void> {
  try {
    const commentsSnapshot = await db
      .collection(parentCollection)
      .doc(parentId)
      .collection('comments')
      .where('text', '!=', '[deleted]')
      .get();

    if (commentsSnapshot.empty) {
      // Remove comment summary if no comments
      await db.collection(parentCollection).doc(parentId).update({
        commentSummary: admin.firestore.FieldValue.delete()
      });
      return;
    }

    // Simple clustering by sentiment
    const clusters: Record<string, CommentCluster> = {};
    
    commentsSnapshot.forEach(doc => {
      const data = doc.data();
      const sentiment = data.sentiment || 'neutral';
      
      if (!clusters[sentiment]) {
        clusters[sentiment] = {
          id: sentiment,
          label: capitalizeFirst(sentiment),
          count: 0,
          sentiment
        };
      }
      
      clusters[sentiment].count += 1;
    });

    const commentSummary = Object.values(clusters)
      .sort((a, b) => b.count - a.count);

    await db.collection(parentCollection).doc(parentId).update({
      commentSummary,
      commentCount: commentsSnapshot.size,
      lastCommentAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    console.error('Error updating comment summary:', error);
  }
}

// Basic content moderation
function moderateContent(text: string): string {
  // Simple profanity filter - replace with more sophisticated solution
  const bannedWords = ['spam', 'fake', 'scam']; // Add more as needed
  let cleaned = text;
  
  bannedWords.forEach(word => {
    const regex = new RegExp(word, 'gi');
    cleaned = cleaned.replace(regex, '*'.repeat(word.length));
  });
  
  return cleaned.trim();
}

// Simple sentiment analysis
function analyzeSentiment(text: string): string {
  const positiveWords = [
    'good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic',
    'love', 'like', 'happy', 'glad', 'pleased', 'satisfied', 'hope',
    'support', 'agree', 'positive', 'helpful', 'useful'
  ];
  
  const negativeWords = [
    'bad', 'terrible', 'awful', 'horrible', 'hate', 'dislike',
    'angry', 'mad', 'frustrated', 'disappointed', 'disagree',
    'wrong', 'problem', 'issue', 'concern', 'worried', 'fear'
  ];
  
  const words = text.toLowerCase().split(/\s+/);
  let positiveCount = 0;
  let negativeCount = 0;
  
  words.forEach(word => {
    if (positiveWords.includes(word)) positiveCount++;
    if (negativeWords.includes(word)) negativeCount++;
  });
  
  if (positiveCount > negativeCount + 1) return 'positive';
  if (negativeCount > positiveCount + 1) return 'negative';
  return 'neutral';
}

function capitalizeFirst(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1);
}