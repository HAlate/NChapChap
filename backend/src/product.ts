import { Router } from "express";
import { Pool } from "pg";

export default function productRoutes(pgPool: Pool) {
  const router = Router();

  router.post("/", async (req, res) => {
    const { merchant_id, name, description, price, category, image_url } = req.body;

    if (!merchant_id || !name || !price) {
      return res.status(400).json({ error: "Champs requis manquants" });
    }

    try {
      const result = await pgPool.query(
        `INSERT INTO products (merchant_id, name, description, price, category, image_url)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [merchant_id, name, description || null, price, category || null, image_url || null]
      );

      res.status(201).json(result.rows[0]);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.put("/:productId", async (req, res) => {
    const { productId } = req.params;
    const { name, description, price, is_available, category, image_url } = req.body;

    try {
      const updates: string[] = [];
      const values: any[] = [];
      let paramCount = 1;

      if (name !== undefined) {
        updates.push(`name = $${paramCount++}`);
        values.push(name);
      }
      if (description !== undefined) {
        updates.push(`description = $${paramCount++}`);
        values.push(description);
      }
      if (price !== undefined) {
        updates.push(`price = $${paramCount++}`);
        values.push(price);
      }
      if (is_available !== undefined) {
        updates.push(`is_available = $${paramCount++}`);
        values.push(is_available);
      }
      if (category !== undefined) {
        updates.push(`category = $${paramCount++}`);
        values.push(category);
      }
      if (image_url !== undefined) {
        updates.push(`image_url = $${paramCount++}`);
        values.push(image_url);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: "Aucun champ à mettre à jour" });
      }

      values.push(productId);
      const query = `UPDATE products SET ${updates.join(", ")} WHERE id = $${paramCount} RETURNING *`;

      const result = await pgPool.query(query, values);

      if (!result.rows.length) {
        return res.status(404).json({ error: "Produit non trouvé" });
      }

      res.json(result.rows[0]);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.delete("/:productId", async (req, res) => {
    const { productId } = req.params;

    try {
      const result = await pgPool.query(
        "DELETE FROM products WHERE id = $1 RETURNING *",
        [productId]
      );

      if (!result.rows.length) {
        return res.status(404).json({ error: "Produit non trouvé" });
      }

      res.json({ success: true, message: "Produit supprimé" });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/merchant/:merchantId", async (req, res) => {
    const { merchantId } = req.params;

    try {
      const result = await pgPool.query(
        "SELECT * FROM products WHERE merchant_id = $1 AND is_available = TRUE ORDER BY created_at DESC",
        [merchantId]
      );

      res.json(result.rows);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  return router;
}
