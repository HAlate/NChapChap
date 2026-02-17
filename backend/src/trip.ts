import { Router } from "express";
import { Pool } from "pg";

export default function tripRoutes(pgPool: Pool) {
  const router = Router();
  // Proposer ou mettre à jour le prix d'un trajet (négociation)
  router.post("/propose-price", async (req, res) => {
    const { trip_id, user_id, proposed_price } = req.body;
    if (!trip_id || !user_id || !proposed_price) {
      return res.status(400).json({ error: "Paramètres manquants" });
    }
    // Met à jour le prix proposé pour le trajet
    const result = await pgPool.query(
      "UPDATE trips SET proposed_price = $1 WHERE id = $2 RETURNING *",
      [proposed_price, trip_id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Trajet non trouvé" });
    }
    res.json(result.rows[0]);
  });

  // Accepter un trajet (SANS consommer de jeton - jeton sera déduit au démarrage)
  router.post("/accept", async (req, res) => {
    const { trip_id, driver_id } = req.body;
    // NOTE: Le jeton ne sera déduit que lorsque le driver démarre la course
    // Cela évite de perdre un jeton en cas de "no show" du passager

    // Mettre à jour le trajet (status, driver_id...)
    await pgPool.query(
      "UPDATE trips SET status = 'accepted', driver_id = $1 WHERE id = $2",
      [driver_id, trip_id]
    );
    res.json({ success: true });
  });

  // Démarrer un trajet (driver consomme un jeton via le trigger DB)
  router.post("/start", async (req, res) => {
    const { trip_id, driver_id } = req.body;

    try {
      // Vérifier que le driver a au moins 1 jeton AVANT de démarrer
      // (Le trigger fera la vérification aussi, mais on fait une pre-check pour UX)
      const tokenCheck = await pgPool.query(
        "SELECT balance FROM token_balances WHERE user_id = $1 AND token_type = 'course'",
        [driver_id]
      );

      if (!tokenCheck.rows.length || tokenCheck.rows[0].balance < 1) {
        return res.status(403).json({
          error: "Pas assez de jetons",
          balance: tokenCheck.rows[0]?.balance || 0,
        });
      }

      // Mettre à jour le statut du trajet à 'started'
      // ⚡ LE TRIGGER spend_token_on_trip_start() VA DÉDUIRE LE JETON AUTOMATIQUEMENT
      await pgPool.query(
        "UPDATE trips SET status = 'started', started_at = NOW() WHERE id = $1",
        [trip_id]
      );

      console.log(
        `[TRIP_START] Trip ${trip_id} started by driver ${driver_id} - Token deducted via trigger`
      );

      res.json({ success: true, message: "Course démarrée, 1 jeton déduit" });
    } catch (error: any) {
      console.error("[TRIP_START] Error:", error);

      // Si c'est une erreur de jeton insuffisant depuis le trigger
      if (error.message && error.message.includes("pas assez de jetons")) {
        return res.status(403).json({ error: "Pas assez de jetons" });
      }

      res.status(500).json({ error: "Erreur lors du démarrage de la course" });
    }
  });

  // Créer un trajet
  router.post("/", async (req, res) => {
    const {
      user_id,
      origin,
      origin_lat,
      origin_lng,
      destination,
      dest_lat,
      dest_lng,
      vehicle_type,
    } = req.body;
    const result = await pgPool.query(
      `INSERT INTO trips (user_id, origin, origin_lat, origin_lng, destination, dest_lat, dest_lng, vehicle_type, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [
        user_id,
        origin,
        origin_lat,
        origin_lng,
        destination,
        dest_lat,
        dest_lng,
        vehicle_type,
        "pending",
      ]
    );
    res.json(result.rows[0]);
  });

  // Lister les trajets d’un utilisateur
  router.get("/user/:user_id", async (req, res) => {
    const { user_id } = req.params;
    const result = await pgPool.query(
      "SELECT * FROM trips WHERE user_id = $1",
      [user_id]
    );
    res.json(result.rows);
  });
  // Sauvegarder les évaluations de fin de course
  router.post("/rate", async (req, res) => {
    const { trip_id, driver_rating, rider_rating } = req.body;

    if (!trip_id) {
      return res.status(400).json({ error: "trip_id manquant" });
    }

    // Construire la requête dynamiquement selon les champs fournis
    const updates: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (driver_rating !== undefined) {
      updates.push(`driver_rating = $${paramIndex}`);
      values.push(driver_rating);
      paramIndex++;
    }

    if (rider_rating !== undefined) {
      updates.push(`rider_rating = $${paramIndex}`);
      values.push(rider_rating);
      paramIndex++;
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: "Aucune évaluation fournie" });
    }

    // Ajouter le trip_id comme dernier paramètre
    values.push(trip_id);

    const query = `UPDATE trips SET ${updates.join(
      ", "
    )} WHERE id = $${paramIndex} RETURNING *`;

    try {
      const result = await pgPool.query(query, values);
      if (result.rows.length === 0) {
        return res.status(404).json({ error: "Trajet non trouvé" });
      }
      res.json({ success: true, trip: result.rows[0] });
    } catch (error) {
      console.error("Error saving ratings:", error);
      res
        .status(500)
        .json({ error: "Erreur lors de la sauvegarde des évaluations" });
    }
  });
  return router;
}
