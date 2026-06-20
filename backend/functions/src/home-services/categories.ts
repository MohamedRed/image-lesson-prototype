import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Get all active service categories
 * GET /home/categories
 */
export const listCategories = withMetrics("listCategories",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const snapshot = await db.collection('serviceCategories')
        .where('isActive', '==', true)
        .orderBy('displayOrder')
        .get();

      const categories = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ categories });
    } catch (error: any) {
      logger.error("Failed to list categories", { error: error.message });
      res.status(500).json({ error: "Failed to list categories" });
    }
  })
);

/**
 * Get a specific category by ID
 * GET /home/categories/:id
 */
export const getCategory = withMetrics("getCategory",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const { categoryId } = req.query;
      
      if (!categoryId) {
        res.status(400).json({ error: "Category ID is required" });
        return;
      }

      const doc = await db.collection('serviceCategories').doc(categoryId as string).get();
      
      if (!doc.exists) {
        res.status(404).json({ error: "Category not found" });
        return;
      }

      res.json({
        id: doc.id,
        ...doc.data()
      });
    } catch (error: any) {
      logger.error("Failed to get category", { error: error.message });
      res.status(500).json({ error: "Failed to get category" });
    }
  })
);

/**
 * Create a new service category (Admin only)
 * POST /home/categories
 */
export const createCategory = withMetrics("createCategory",
  onRequest({ cors: true }, async (req, res) => {
    try {
      // Check admin permissions
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { name, nameAr, nameFr, icon, attributesSchema, displayOrder } = req.body;

      if (!name || !icon) {
        res.status(400).json({ error: "Name and icon are required" });
        return;
      }

      const categoryData = {
        name,
        nameAr: nameAr || null,
        nameFr: nameFr || null,
        icon,
        attributesSchema: attributesSchema || {},
        isActive: true,
        displayOrder: displayOrder || 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const docRef = await db.collection('serviceCategories').add(categoryData);

      logger.info("Category created", { categoryId: docRef.id, name });

      res.json({
        categoryId: docRef.id,
        ...categoryData
      });
    } catch (error: any) {
      logger.error("Failed to create category", { error: error.message });
      res.status(500).json({ error: "Failed to create category" });
    }
  })
);

/**
 * Update a service category (Admin only)
 * PUT /home/categories/:id
 */
export const updateCategory = withMetrics("updateCategory",
  onRequest({ cors: true }, async (req, res) => {
    try {
      // Check admin permissions
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { categoryId } = req.query;
      const updates = req.body;

      if (!categoryId) {
        res.status(400).json({ error: "Category ID is required" });
        return;
      }

      // Remove fields that shouldn't be updated directly
      delete updates.createdAt;
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

      await db.collection('serviceCategories').doc(categoryId as string).update(updates);

      logger.info("Category updated", { categoryId, updates });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to update category", { error: error.message });
      res.status(500).json({ error: "Failed to update category" });
    }
  })
);

/**
 * Delete/deactivate a service category (Admin only)
 * DELETE /home/categories/:id
 */
export const deleteCategory = withMetrics("deleteCategory",
  onRequest({ cors: true }, async (req, res) => {
    try {
      // Check admin permissions
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { categoryId } = req.query;

      if (!categoryId) {
        res.status(400).json({ error: "Category ID is required" });
        return;
      }

      // Soft delete by marking as inactive
      await db.collection('serviceCategories').doc(categoryId as string).update({
        isActive: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Category deactivated", { categoryId });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to delete category", { error: error.message });
      res.status(500).json({ error: "Failed to delete category" });
    }
  })
);