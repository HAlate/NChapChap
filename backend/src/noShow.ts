import { Router } from "express";
import { Pool } from "pg";

export default function noShowRoutes(pgPool: Pool) {
  const router = Router();

  /**
   * POST /api/no-show/report
   * Signaler un No Show (passager ou chauffeur absent)
   */
  router.post("/report", async (req, res) => {
    const {
      trip_id,
      reported_user_id,
      user_type, // 'rider' ou 'driver'
      reason,
    } = req.body;
    const reporter_id = req.body.reporter_id; // En production: req.user.id depuis auth middleware

    try {
      // Vérifier que le trip existe et que le reporter était impliqué
      const tripCheck = await pgPool.query(
        "SELECT * FROM trips WHERE id = $1 AND (rider_id = $2 OR driver_id = $2)",
        [trip_id, reporter_id]
      );

      if (tripCheck.rows.length === 0) {
        return res
          .status(403)
          .json({ error: "Vous n'êtes pas autorisé à signaler ce trajet" });
      }

      const trip = tripCheck.rows[0];

      // Vérifier que l'utilisateur signalé fait bien partie du trajet
      if (
        reported_user_id !== trip.rider_id &&
        reported_user_id !== trip.driver_id
      ) {
        return res.status(400).json({
          error: "L'utilisateur signalé ne fait pas partie de ce trajet",
        });
      }

      // Créer le signalement
      const reportResult = await pgPool.query(
        `INSERT INTO no_show_reports 
         (trip_id, reported_by, reported_user, user_type, reason, status)
         VALUES ($1, $2, $3, $4, $5, 'confirmed')
         RETURNING *`,
        [trip_id, reporter_id, reported_user_id, user_type, reason]
      );

      const report = reportResult.rows[0];

      // Appliquer les sanctions selon le type d'utilisateur
      if (user_type === "driver") {
        // CHAUFFF CFA No Show: déduire 1 jeton
        const driverCheck = await pgPool.query(
          "SELECT tokens FROM users WHERE id = $1",
          [reported_user_id]
        );

        if (driverCheck.rows.length > 0) {
          const currentTokens = driverCheck.rows[0].tokens;

          await pgPool.query(
            "UPDATE users SET tokens = GREATEST(0, tokens - 1) WHERE id = $1",
            [reported_user_id]
          );

          // Créer une pénalité
          await pgPool.query(
            `INSERT INTO user_penalties 
             (user_id, penalty_type, severity, reason, trip_id, report_id, tokens_deducted, is_active)
             VALUES ($1, 'no_show', 1, $2, $3, $4, 1, TRUE)`,
            [
              reported_user_id,
              "No Show signalé - 1 jeton déduit",
              trip_id,
              report.id,
            ]
          );

          console.log(
            `[NO_SHOW] Driver ${reported_user_id} sanctioned: 1 token deducted (${currentTokens} -> ${
              currentTokens - 1
            })`
          );
        }
      } else if (user_type === "rider") {
        // PASSAGER No Show: système de restrictions progressif
        const riderCheck = await pgPool.query(
          `SELECT no_show_count, last_no_show_at FROM users WHERE id = $1`,
          [reported_user_id]
        );

        if (riderCheck.rows.length > 0) {
          const { no_show_count, last_no_show_at } = riderCheck.rows[0];
          const newCount = no_show_count + 1;

          // Calculer la restriction selon le nombre de No Show
          let restrictionDays = 0;
          let severity = 1;

          if (newCount === 1) {
            // 1er No Show: Avertissement seulement
            restrictionDays = 0;
            severity = 1;
          } else if (newCount === 2) {
            // 2ème No Show: 24h de restriction
            restrictionDays = 1;
            severity = 1;
          } else if (newCount === 3) {
            // 3ème No Show: 7 jours
            restrictionDays = 7;
            severity = 2;
          } else {
            // 4+ No Show: 30 jours
            restrictionDays = 30;
            severity = 3;
          }

          const restrictionUntil =
            restrictionDays > 0
              ? new Date(Date.now() + restrictionDays * 24 * 60 * 60 * 1000)
              : null;

          // Mettre à jour l'utilisateur
          await pgPool.query(
            `UPDATE users 
             SET no_show_count = no_show_count + 1,
                 last_no_show_at = NOW(),
                 is_restricted = $1,
                 restriction_until = $2
             WHERE id = $3`,
            [restrictionDays > 0, restrictionUntil, reported_user_id]
          );

          // Créer la pénalité
          await pgPool.query(
            `INSERT INTO user_penalties 
             (user_id, penalty_type, severity, reason, trip_id, report_id, expires_at, is_active)
             VALUES ($1, 'no_show', $2, $3, $4, $5, $6, TRUE)`,
            [
              reported_user_id,
              severity,
              `No Show #${newCount} - Restriction ${restrictionDays} jour${
                restrictionDays > 1 ? "s" : ""
              }`,
              trip_id,
              report.id,
              restrictionUntil,
            ]
          );

          console.log(
            `[NO_SHOW] Rider ${reported_user_id} sanctioned: No Show #${newCount}, restriction ${restrictionDays} days`
          );
        }
      }

      // Annuler le trip
      await pgPool.query(
        "UPDATE trips SET status = 'cancelled', cancellation_reason = 'no_show' WHERE id = $1",
        [trip_id]
      );

      res.json({
        success: true,
        report,
        message: "No Show signalé avec succès",
      });
    } catch (error) {
      console.error("[NO_SHOW] Error reporting no show:", error);
      res.status(500).json({ error: "Erreur lors du signalement" });
    }
  });

  /**
   * GET /api/no-show/my-reports
   * Récupérer les signalements de l'utilisateur connecté
   */
  router.get("/my-reports", async (req, res) => {
    const user_id = req.query.user_id as string; // En production: req.user.id

    try {
      const reports = await pgPool.query(
        `SELECT 
          r.*,
          reporter.full_name as reporter_name,
          reported.full_name as reported_name,
          t.departure, t.destination, t.price
         FROM no_show_reports r
         JOIN users reporter ON r.reported_by = reporter.id
         JOIN users reported ON r.reported_user = reported.id
         JOIN trips t ON r.trip_id = t.id
         WHERE r.reported_by = $1 OR r.reported_user = $1
         ORDER BY r.created_at DESC`,
        [user_id]
      );

      res.json(reports.rows);
    } catch (error) {
      console.error("[NO_SHOW] Error fetching reports:", error);
      res.status(500).json({ error: "Erreur lors de la récupération" });
    }
  });

  /**
   * GET /api/no-show/my-penalties
   * Récupérer les pénalités actives de l'utilisateur
   */
  router.get("/my-penalties", async (req, res) => {
    const user_id = req.query.user_id as string;

    try {
      const penalties = await pgPool.query(
        `SELECT * FROM user_penalties
         WHERE user_id = $1 AND is_active = TRUE
         ORDER BY created_at DESC`,
        [user_id]
      );

      res.json(penalties.rows);
    } catch (error) {
      console.error("[NO_SHOW] Error fetching penalties:", error);
      res.status(500).json({ error: "Erreur lors de la récupération" });
    }
  });

  /**
   * GET /api/no-show/check-restriction/:user_id
   * Vérifier si un utilisateur est restreint
   */
  router.get("/check-restriction/:user_id", async (req, res) => {
    const { user_id } = req.params;

    try {
      // D'abord, expirer les restrictions périmées
      await pgPool.query(
        `UPDATE users
         SET is_restricted = FALSE, restriction_until = NULL
         WHERE id = $1 AND is_restricted = TRUE 
         AND restriction_until IS NOT NULL 
         AND restriction_until < NOW()`,
        [user_id]
      );

      // Récupérer le statut actuel
      const result = await pgPool.query(
        `SELECT 
          is_restricted, 
          restriction_until, 
          no_show_count,
          (SELECT COUNT(*) FROM user_penalties 
           WHERE user_id = $1 AND is_active = TRUE) as active_penalties_count
         FROM users 
         WHERE id = $1`,
        [user_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: "Utilisateur non trouvé" });
      }

      const user = result.rows[0];

      res.json({
        is_restricted: user.is_restricted,
        restriction_until: user.restriction_until,
        no_show_count: user.no_show_count,
        active_penalties_count: user.active_penalties_count,
        can_request_trip: !user.is_restricted,
      });
    } catch (error) {
      console.error("[NO_SHOW] Error checking restriction:", error);
      res.status(500).json({ error: "Erreur lors de la vérification" });
    }
  });

  return router;
}
