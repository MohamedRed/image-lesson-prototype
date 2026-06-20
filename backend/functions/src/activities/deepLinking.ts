import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity,
  ActivityGroup,
  Booking,
  ActivitySession
} from './models';
import { incrementCounter } from '../shared/metrics';

const db = admin.firestore();

// Generate deep link for activity details
export const createActivityDeepLink = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId, referralCode, source = 'share' } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    // Verify activity exists
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;

    // Build deep link parameters
    const params = new URLSearchParams({
      activity_id: activityId,
      source,
      ...(referralCode && { referral: referralCode }),
      shared_by: context.auth.uid
    });

    const deepLink = `liive://activities/details?${params.toString()}`;

    // Create shareable web link that redirects to deep link
    const webLink = `https://liive.app/activity/${activityId}?${params.toString()}`;

    await incrementCounter('activities_deeplinks_created', 1);

    logger.info('Activity deep link created', {
      activityId,
      userId: context.auth.uid,
      source,
      deepLink,
      webLink
    });

    return { 
      deepLink, 
      webLink,
      title: activity.title,
      description: activity.description.substring(0, 100) + '...'
    };

  } catch (error) {
    logger.error('Error creating activity deep link:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create deep link');
  }
});

// Generate deep link for group invitation
export const createGroupInviteDeepLink = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, inviteCode } = data;

  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID required');
  }

  try {
    // Verify group exists and user is organizer
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (group.organizerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only group organizer can create invite links');
    }

    // Generate or use existing invite code
    const code = inviteCode || generateInviteCode();

    // Store invite code mapping
    await db.collection('groupInvites').doc(code).set({
      groupId,
      organizerId: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
      ),
      usedCount: 0,
      maxUses: 20
    });

    const deepLink = `liive://activities/join-group?invite_code=${code}`;
    const webLink = `https://liive.app/join/${code}`;

    await incrementCounter('activities_group_invites_created', 1);

    return { 
      deepLink, 
      webLink, 
      inviteCode: code,
      groupName: group.name
    };

  } catch (error) {
    logger.error('Error creating group invite deep link:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create invite link');
  }
});

// Process group invitation from deep link
export const joinGroupFromInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { inviteCode } = data;

  if (!inviteCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Invite code required');
  }

  try {
    // Get invite details
    const inviteDoc = await db.collection('groupInvites').doc(inviteCode).get();
    if (!inviteDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invalid invite code');
    }

    const invite = inviteDoc.data()!;

    // Check expiration
    if (invite.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError('failed-precondition', 'Invite code expired');
    }

    // Check usage limit
    if (invite.usedCount >= invite.maxUses) {
      throw new functions.https.HttpsError('failed-precondition', 'Invite code usage limit reached');
    }

    // Get group details
    const groupDoc = await db.collection('groups').doc(invite.groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;

    // Check if user is already in group
    if (group.participantUserIds.includes(context.auth.uid)) {
      return { 
        success: true, 
        alreadyMember: true,
        groupId: invite.groupId,
        groupName: group.name
      };
    }

    // Add user to group
    await db.collection('groups').doc(invite.groupId).update({
      participantUserIds: admin.firestore.FieldValue.arrayUnion(context.auth.uid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Increment invite usage
    await db.collection('groupInvites').doc(inviteCode).update({
      usedCount: admin.firestore.FieldValue.increment(1)
    });

    await incrementCounter('activities_group_invites_used', 1);

    logger.info('User joined group via invite', {
      userId: context.auth.uid,
      groupId: invite.groupId,
      inviteCode
    });

    return { 
      success: true,
      groupId: invite.groupId,
      groupName: group.name,
      chatThreadId: group.chatThreadId
    };

  } catch (error) {
    logger.error('Error joining group from invite:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to join group');
  }
});

// Handle web link redirects and app detection
export const handleWebLinkRedirect = functions.https.onRequest(async (req, res) => {
  const path = req.path;
  const userAgent = req.get('User-Agent') || '';
  const isIOS = /iPhone|iPad|iPod/.test(userAgent);
  const isAndroid = /Android/.test(userAgent);

  try {
    // Parse different URL patterns
    if (path.startsWith('/activity/')) {
      const activityId = path.split('/')[2];
      const queryParams = req.query;

      if (activityId) {
        // Build deep link
        const params = new URLSearchParams(queryParams as any);
        const deepLink = `liive://activities/details?activity_id=${activityId}&${params.toString()}`;

        // Try to open app, fallback to app store
        const appStoreUrl = 'https://apps.apple.com/app/liive/id123456789';
        const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.liive.app';

        const html = generateRedirectHTML({
          deepLink,
          appStoreUrl: isIOS ? appStoreUrl : playStoreUrl,
          title: 'Check out this activity on Liive!',
          description: 'Join this amazing activity with friends'
        });

        res.set('Content-Type', 'text/html');
        res.send(html);
        return;
      }
    }

    if (path.startsWith('/join/')) {
      const inviteCode = path.split('/')[2];

      if (inviteCode) {
        const deepLink = `liive://activities/join-group?invite_code=${inviteCode}`;
        const appStoreUrl = 'https://apps.apple.com/app/liive/id123456789';
        const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.liive.app';

        const html = generateRedirectHTML({
          deepLink,
          appStoreUrl: isIOS ? appStoreUrl : playStoreUrl,
          title: 'Join group on Liive!',
          description: 'Join this activity group and meet new people'
        });

        res.set('Content-Type', 'text/html');
        res.send(html);
        return;
      }
    }

    // Default fallback
    res.redirect('https://liive.app');

  } catch (error) {
    logger.error('Error handling web link redirect:', error);
    res.redirect('https://liive.app');
  }
});

// Track deep link usage analytics
export const trackDeepLinkUsage = functions.https.onCall(async (data, context) => {
  const { source, activityId, groupId, action } = data;

  try {
    // Store analytics data
    await db.collection('deepLinkAnalytics').add({
      userId: context.auth?.uid || null,
      source,
      activityId: activityId || null,
      groupId: groupId || null,
      action,
      userAgent: data.userAgent || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    await incrementCounter(`activities_deeplink_${action}`, 1);

    return { success: true };

  } catch (error) {
    logger.error('Error tracking deep link usage:', error);
    // Don't throw - analytics failures shouldn't break user flow
    return { success: false };
  }
});

// Helper functions
function generateInviteCode(): string {
  // Generate 8-character alphanumeric code
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function generateRedirectHTML({ deepLink, appStoreUrl, title, description }: {
  deepLink: string;
  appStoreUrl: string;
  title: string;
  description: string;
}): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    <meta property="og:image" content="https://liive.app/og-image.png" />
</head>
<body>
    <script>
        // Try to open app
        window.location = '${deepLink}';
        
        // Fallback to app store after delay
        setTimeout(function() {
            window.location = '${appStoreUrl}';
        }, 2000);
    </script>
    
    <div style="text-align: center; padding: 50px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
        <h1>${title}</h1>
        <p>${description}</p>
        <p>If the app doesn't open automatically, <a href="${appStoreUrl}">download Liive</a>.</p>
    </div>
</body>
</html>
  `;
}