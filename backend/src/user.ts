import { Router } from "express";
import { Pool } from "pg";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

export default function userRoutes(pgPool: Pool) {
  const router = Router();
  // Validation du paiement mobile money par code de confirmation
  router.post("/validate-payment", async (req, res) => {
    const { user_id, amount, code_confirmation } = req.body;
    // Ici, il faudrait vérifier le code auprès de l'opérateur mobile money
    // Pour la démo, on accepte tout code à 6 chiffres
    if (!/^[0-9]{6}$/.test(code_confirmation)) {
      return res.status(400).json({ error: "Code de confirmation invalide" });
    }
    // 1 jeton = 10 F CFA
    const tokensToAdd = Math.floor(amount / 10);
    if (tokensToAdd <= 0)
      return res.status(400).json({ error: "Montant insuffisant" });
    await pgPool.query("UPDATE users SET tokens = tokens + $1 WHERE id = $2", [
      tokensToAdd,
      user_id,
    ]);
    res.json({ success: true, tokensAdded: tokensToAdd });
  });
  // Récupérer le numéro mobile money administrateur par pays
  router.get("/admin-mobile-money/:country", async (req, res) => {
    const { country } = req.params;
    const result = await pgPool.query(
      "SELECT phone_number, operator FROM admin_mobile_money WHERE country = $1 AND is_active = TRUE ORDER BY id DESC LIMIT 1",
      [country]
    );
    if (!result.rows.length) {
      return res
        .status(404)
        .json({ error: "Aucun numéro mobile money pour ce pays" });
    }
    res.json(result.rows[0]);
  });

  // Achat de jetons (mobile money simulé)
  router.post("/buy-tokens", async (req, res) => {
    const { user_id, amount } = req.body;
    // 1 jeton = 10 F CFA
    const tokensToAdd = Math.floor(amount / 10);
    if (tokensToAdd <= 0)
      return res.status(400).json({ error: "Montant insuffisant" });
    await pgPool.query("UPDATE users SET tokens = tokens + $1 WHERE id = $2", [
      tokensToAdd,
      user_id,
    ]);
    res.json({ success: true, tokensAdded: tokensToAdd });
  });

  // Inscription
  router.post("/register", async (req, res) => {
    const { phone, password, role } = req.body;
    if (!phone || !password)
      return res.status(400).json({ error: "Champs requis" });
    const hash = await bcrypt.hash(password, 10);
    await pgPool.query(
      "INSERT INTO users (phone, password, role) VALUES ($1, $2, $3)",
      [phone, hash, role || "rider"]
    );
    res.json({ success: true });
  });

  // Authentification
  router.post("/login", async (req, res) => {
    const { phone, password, role } = req.body;
    let query = "SELECT * FROM users WHERE phone = $1";
    let params: any[] = [phone];
    if (role) {
      query += " AND role = $2";
      params.push(role);
    }
    const result = await pgPool.query(query, params);
    if (!result.rows.length)
      return res.status(401).json({ error: "Utilisateur non trouvé" });
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password);
    if (!valid)
      return res.status(401).json({ error: "Mot de passe incorrect" });
    const token = jwt.sign(
      { id: user.id, phone: user.phone, role: user.role },
      process.env.JWT_SECRET || "secret"
    );
    res.json({ token });
  });

  // Profil utilisateur (protégé)
  router.get("/me", async (req, res) => {
    // À compléter avec vérification JWT
    res.json({ message: "Profil utilisateur (à sécuriser)" });
  });

  return router;
}
