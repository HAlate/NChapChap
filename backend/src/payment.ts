import { Router } from "express";
import { Pool } from "pg";
// Utilisation de 'any' pour le client Redis afin d'éviter les erreurs de typage
export default function paymentRoutes(pgPool: Pool, redisClient: any) {
  const router = Router();

  // Paiement (simulation)
  router.post("/", async (req, res) => {
    const { user_id, trip_id, amount, method } = req.body;
    await pgPool.query(
      "INSERT INTO payments (user_id, trip_id, amount, method, status) VALUES ($1, $2, $3, $4, $5)",
      [user_id, trip_id, amount, method, "pending"]
    );
    // Simuler une notification via Redis (ex: file d’attente)
    // Vérifier si Redis est connecté avant de publier
    try {
      if (redisClient && redisClient.isReady) {
        await redisClient.publish(
          "payments",
          JSON.stringify({ user_id, trip_id, amount, method })
        );
      } else {
        console.log("Redis not available, skipping notification");
      }
    } catch (err) {
      console.warn("Failed to publish to Redis:", err);
    }
    res.json({ success: true });
  });

  return router;
}
