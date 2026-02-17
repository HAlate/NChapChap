import { Router } from "express";
import { Pool } from "pg";

export default function orderRoutes(pgPool: Pool) {
  const router = Router();

  router.post("/", async (req, res) => {
    const {
      merchant_id,
      customer_id,
      total_amount,
      delivery_address,
      delivery_lat,
      delivery_lng,
      customer_phone,
      items,
    } = req.body;

    if (!merchant_id || !customer_id || !total_amount || !delivery_address || !items || !items.length) {
      return res.status(400).json({ error: "Champs requis manquants" });
    }

    try {
      const orderResult = await pgPool.query(
        `INSERT INTO orders (merchant_id, customer_id, total_amount, delivery_address, delivery_lat, delivery_lng, customer_phone)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [merchant_id, customer_id, total_amount, delivery_address, delivery_lat || null, delivery_lng || null, customer_phone || null]
      );

      const order = orderResult.rows[0];

      for (const item of items) {
        await pgPool.query(
          `INSERT INTO order_items (order_id, product_id, product_name, quantity, price)
           VALUES ($1, $2, $3, $4, $5)`,
          [order.id, item.product_id, item.product_name, item.quantity, item.price]
        );
      }

      res.status(201).json(order);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/:orderId", async (req, res) => {
    const { orderId } = req.params;

    try {
      const orderResult = await pgPool.query(
        "SELECT * FROM orders WHERE id = $1",
        [orderId]
      );

      if (!orderResult.rows.length) {
        return res.status(404).json({ error: "Commande non trouvée" });
      }

      const order = orderResult.rows[0];

      const itemsResult = await pgPool.query(
        "SELECT * FROM order_items WHERE order_id = $1",
        [orderId]
      );

      res.json({ ...order, items: itemsResult.rows });
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.put("/:orderId/status", async (req, res) => {
    const { orderId } = req.params;
    const { status } = req.body;

    if (!status) {
      return res.status(400).json({ error: "Statut requis" });
    }

    const validStatuses = ['pending', 'preparing', 'ready', 'delivering', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: "Statut invalide" });
    }

    try {
      const result = await pgPool.query(
        "UPDATE orders SET status = $1 WHERE id = $2 RETURNING *",
        [status, orderId]
      );

      if (!result.rows.length) {
        return res.status(404).json({ error: "Commande non trouvée" });
      }

      res.json(result.rows[0]);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  router.get("/customer/:customerId", async (req, res) => {
    const { customerId } = req.params;

    try {
      const result = await pgPool.query(
        `SELECT o.*, m.business_name as merchant_name
         FROM orders o
         LEFT JOIN merchants m ON o.merchant_id = m.id
         WHERE o.customer_id = $1
         ORDER BY o.created_at DESC`,
        [customerId]
      );

      res.json(result.rows);
    } catch (error) {
      res.status(500).json({ error: "Erreur serveur" });
    }
  });

  return router;
}
