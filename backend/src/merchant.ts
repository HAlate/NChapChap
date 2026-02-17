import { Router } from "express";
import { Pool } from "pg";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

export default function merchantRoutes(pgPool: Pool) {
  const router = Router();

  router.post("/register", async (req, res) => {
    const { phone, password, business_name, address, category } = req.body;

    if (!phone || !password || !business_name) {
      return res.status(400).json({ error: "Champs requis manquants" });
    }

    try {
      const hash = await bcrypt.hash(password, 10);
      const result = await pgPool.query(
        `INSERT INTO merchants (phone, password, business_name, address, category)
         VALUES ($1, $2, $3, $4, $5) RETURNING id, phone, business_name, address, category, is_active`,
        [phone, hash, business_name, address || null, category || null]
      );
      res.status(201).json({ success: true, merchant: result.rows[0] });
    } catch (error: any) {
      if (error.code === '23505') {
        return res.status(400).json({ error: "Ce numéro est déjà utilisé" });
      }
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.post("/login", async (req, res) => {
    const { phone, password } = req.body;

    try {
      const result = await pgPool.query(
        "SELECT * FROM merchants WHERE phone = $1",
        [phone]
      );

      if (!result.rows.length) {
        return res.status(401).json({ error: "Marchand non trouvé" });
      }

      const merchant = result.rows[0];
      const valid = await bcrypt.compare(password, merchant.password);

      if (!valid) {
        return res.status(401).json({ error: "Mot de passe incorrect" });
      }

      const token = jwt.sign(
        { id: merchant.id, phone: merchant.phone, type: "merchant" },
        process.env.JWT_SECRET || "secret"
      );

      const { password: _, ...merchantData } = merchant;
      res.json({ token, merchant: merchantData });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/:merchantId", async (req, res) => {
    const { merchantId } = req.params;

    try {
      const result = await pgPool.query(
        "SELECT id, phone, business_name, address, latitude, longitude, category, is_active, created_at FROM merchants WHERE id = $1",
        [merchantId]
      );

      if (!result.rows.length) {
        return res.status(404).json({ error: "Marchand non trouvé" });
      }

      res.json(result.rows[0]);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/:merchantId/orders", async (req, res) => {
    const { merchantId } = req.params;

    try {
      const result = await pgPool.query(
        `SELECT o.*, u.phone as customer_phone
         FROM orders o
         LEFT JOIN users u ON o.customer_id = u.id
         WHERE o.merchant_id = $1
         ORDER BY o.created_at DESC`,
        [merchantId]
      );

      res.json(result.rows);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/:merchantId/products", async (req, res) => {
    const { merchantId } = req.params;

    try {
      const result = await pgPool.query(
        "SELECT * FROM products WHERE merchant_id = $1 ORDER BY created_at DESC",
        [merchantId]
      );

      res.json(result.rows);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  return router;
}
