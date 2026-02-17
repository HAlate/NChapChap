import express, { Request, Response } from "express";
import {
  getNJIABalance,
  verifyTransaction,
  creditTokensFromNJIA,
  isValidTxHash,
  isValidAddress,
  calculateChapChapTokensFromNJIA,
  calculateNJIAFromChapChapTokens,
  config,
} from "./crypto";

const router = express.Router();

// Middleware d'authentification (à adapter selon votre système)
const requireAuth = (req: Request, res: Response, next: Function) => {
  const userId = req.headers["x-user-id"] as string;

  if (!userId) {
    return res.status(401).json({ error: "Non authentifié" });
  }

  (req as any).userId = userId;
  next();
};

// =====================================================
// ROUTES CRYPTO
// =====================================================

/**
 * GET /api/crypto/config
 * Récupère la configuration publique du système crypto
 */
router.get("/config", (req: Request, res: Response) => {
  res.json({
    njiaTokenAddress: config.NJIA_TOKEN_ADDRESS,
    conversionRates: {
      njiaToFcfa: config.NJIA_TO_FCFA,
      njiaToChapChapTokens: config.NJIA_TO_CHAPCHAP_TOKENS,
      chapChapTokenCostFcfa: config.CHAPCHAP_TOKEN_COST_FCFA,
    },
    isTestnet: config.isTestnet,
    network: config.isTestnet ? "Polygon Amoy Testnet" : "Polygon Mainnet",
    rpcUrl: config.POLYGON_RPC_URL,
  });
});

/**
 * GET /api/crypto/balance/:address
 * Récupère le solde NJIA d'une adresse wallet
 */
router.get("/balance/:address", async (req: Request, res: Response) => {
  try {
    const { address } = req.params;

    if (!isValidAddress(address)) {
      return res.status(400).json({ error: "Adresse wallet invalide" });
    }

    const balance = await getNJIABalance(address);

    res.json({
      success: true,
      address,
      ...balance,
    });
  } catch (error) {
    console.error("[API] Error getting balance:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Erreur inconnue",
    });
  }
});

/**
 * GET /api/crypto/verify/:txHash
 * Vérifie une transaction blockchain
 */
router.get("/verify/:txHash", async (req: Request, res: Response) => {
  try {
    const { txHash } = req.params;

    if (!isValidTxHash(txHash)) {
      return res.status(400).json({ error: "Hash de transaction invalide" });
    }

    const txInfo = await verifyTransaction(txHash);

    res.json({
      success: true,
      transaction: txInfo,
    });
  } catch (error) {
    console.error("[API] Error verifying transaction:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Erreur inconnue",
    });
  }
});

/**
 * POST /api/crypto/deposit
 * Enregistre un dépôt NJIA et crédite les tokens CHAP-CHAP
 *
 * Body: {
 *   txHash: string,
 *   walletAddress: string
 * }
 */
router.post("/deposit", requireAuth, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { txHash, walletAddress } = req.body;

    if (!txHash || !isValidTxHash(txHash)) {
      return res.status(400).json({ error: "Hash de transaction invalide" });
    }

    if (!walletAddress || !isValidAddress(walletAddress)) {
      return res.status(400).json({ error: "Adresse wallet invalide" });
    }

    // Créditer les tokens
    const result = await creditTokensFromNJIA(userId, txHash);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.message,
      });
    }

    res.json({
      success: true,
      message: result.message,
      tokensAdded: result.tokensAdded,
      njiaAmount: result.njiaAmount,
      transaction: {
        hash: txHash,
        walletAddress,
      },
    });
  } catch (error) {
    console.error("[API] Error processing deposit:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Erreur inconnue",
    });
  }
});

/**
 * GET /api/crypto/calculate
 * Calcule les conversions NJIA ↔ CHAP-CHAP Tokens
 *
 * Query params:
 *   - njia: montant NJIA → retourne tokens CHAP-CHAP
 *   - tokens: montant tokens CHAP-CHAP → retourne NJIA nécessaire
 */
router.get("/calculate", (req: Request, res: Response) => {
  const { njia, tokens } = req.query;

  if (njia) {
    const njiaAmount = parseFloat(njia as string);
    if (isNaN(njiaAmount) || njiaAmount <= 0) {
      return res.status(400).json({ error: "Montant NJIA invalide" });
    }

    const chapChapTokens = calculateChapChapTokensFromNJIA(njiaAmount);

    return res.json({
      success: true,
      input: { njia: njiaAmount },
      output: {
        chapChapTokens,
        fcfaEquivalent: njiaAmount * config.NJIA_TO_FCFA,
      },
    });
  }

  if (tokens) {
    const tokenAmount = parseInt(tokens as string);
    if (isNaN(tokenAmount) || tokenAmount <= 0) {
      return res.status(400).json({ error: "Montant tokens invalide" });
    }

    const njiaNeeded = calculateNJIAFromChapChapTokens(tokenAmount);

    return res.json({
      success: true,
      input: { chapChapTokens: tokenAmount },
      output: {
        njiaNeeded,
        fcfaEquivalent: njiaNeeded * config.NJIA_TO_FCFA,
      },
    });
  }

  res.status(400).json({
    error: "Paramètre manquant: spécifiez ?njia=X ou ?tokens=X",
  });
});

/**
 * GET /api/crypto/health
 * Vérifie que la connexion blockchain fonctionne
 */
router.get("/health", async (req: Request, res: Response) => {
  try {
    // Tester la connexion RPC
    const testAddress = "0x0000000000000000000000000000000000000000";
    await getNJIABalance(testAddress);

    res.json({
      success: true,
      message: "Connexion blockchain OK",
      network: config.isTestnet ? "Testnet" : "Mainnet",
    });
  } catch (error) {
    res.status(503).json({
      success: false,
      error: "Connexion blockchain échouée",
      details: error instanceof Error ? error.message : "Erreur inconnue",
    });
  }
});

export default router;
