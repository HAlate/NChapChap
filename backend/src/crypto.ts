import dotenv from "dotenv";
import { ethers } from "ethers";
import { createClient } from "@supabase/supabase-js";

// Charger les variables d'environnement
dotenv.config();

// =====================================================
// CONFIGURATION POLYGON & NJIA TOKEN
// =====================================================

const POLYGON_RPC_URL =
  process.env.POLYGON_RPC_URL || "https://polygon-rpc.com";
const POLYGON_TESTNET_RPC = "https://rpc-amoy.polygon.technology"; // Mumbai remplacé par Amoy

// Adresse du contrat NJIA
const NJIA_TOKEN_ADDRESS =
  process.env.NJIA_TOKEN_ADDRESS ||
  "0x38511b83942C4b467761E8d690605244A26AC9e0";

// Conversion rates
const NJIA_TO_FCFA = 65.5957; // 1 NJIA = 65.5957 FCFA
const CHAPCHAP_TOKEN_COST_FCFA = 20; // 1 Token CHAP-CHAP = 20 FCFA
const NJIA_TO_CHAPCHAP_TOKENS = NJIA_TO_FCFA / CHAPCHAP_TOKEN_COST_FCFA; // 3.28 tokens par NJIA

// ABI minimal ERC20 pour balanceOf et transfer events
const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
];

// =====================================================
// PROVIDER POLYGON
// =====================================================

const isTestnet = process.env.NODE_ENV !== "production";
const provider = new ethers.JsonRpcProvider(
  isTestnet ? POLYGON_TESTNET_RPC : POLYGON_RPC_URL
);

// Instance du contrat NJIA
const njiaContract = new ethers.Contract(
  NJIA_TOKEN_ADDRESS,
  ERC20_ABI,
  provider
);

// Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_SERVICE_ROLE_KEY || ""
);

// =====================================================
// FONCTIONS BLOCKCHAIN
// =====================================================

/**
 * Récupère le solde NJIA d'une adresse wallet
 */
export async function getNJIABalance(walletAddress: string): Promise<{
  balance: string;
  balanceFormatted: string;
  equivalentFCFA: number;
  equivalentChapChapTokens: number;
}> {
  try {
    const balance = await njiaContract.balanceOf(walletAddress);
    const decimals = await njiaContract.decimals();
    const balanceFormatted = ethers.formatUnits(balance, decimals);
    const balanceNumber = parseFloat(balanceFormatted);

    return {
      balance: balance.toString(),
      balanceFormatted,
      equivalentFCFA: balanceNumber * NJIA_TO_FCFA,
      equivalentChapChapTokens: Math.floor(
        balanceNumber * NJIA_TO_CHAPCHAP_TOKENS
      ),
    };
  } catch (error) {
    console.error("[Crypto] Error getting NJIA balance:", error);
    throw new Error("Failed to get NJIA balance");
  }
}

/**
 * Vérifie qu'une transaction existe et est confirmée
 */
export async function verifyTransaction(txHash: string): Promise<{
  isValid: boolean;
  from: string | null;
  to: string | null;
  amount: string | null;
  amountFormatted: string | null;
  blockNumber: number | null;
  confirmations: number;
}> {
  try {
    const receipt = await provider.getTransactionReceipt(txHash);

    if (!receipt) {
      return {
        isValid: false,
        from: null,
        to: null,
        amount: null,
        amountFormatted: null,
        blockNumber: null,
        confirmations: 0,
      };
    }

    const tx = await provider.getTransaction(txHash);
    const currentBlock = await provider.getBlockNumber();
    const confirmations = receipt.blockNumber
      ? currentBlock - receipt.blockNumber
      : 0;

    // Parser les logs pour trouver le Transfer event
    let transferAmount = null;
    let transferAmountFormatted = null;

    for (const log of receipt.logs) {
      if (log.address.toLowerCase() === NJIA_TOKEN_ADDRESS.toLowerCase()) {
        try {
          const parsedLog = njiaContract.interface.parseLog({
            topics: [...log.topics],
            data: log.data,
          });

          if (parsedLog && parsedLog.name === "Transfer") {
            transferAmount = parsedLog.args.value.toString();
            transferAmountFormatted = ethers.formatUnits(
              parsedLog.args.value,
              18
            );
          }
        } catch (e) {
          // Log parsing failed, continue
        }
      }
    }

    return {
      isValid: receipt.status === 1,
      from: tx?.from || null,
      to: tx?.to || null,
      amount: transferAmount,
      amountFormatted: transferAmountFormatted,
      blockNumber: receipt.blockNumber,
      confirmations,
    };
  } catch (error) {
    console.error("[Crypto] Error verifying transaction:", error);
    throw new Error("Failed to verify transaction");
  }
}

/**
 * Vérifie et crédite les tokens CHAP-CHAP suite à un dépôt NJIA
 */
export async function creditTokensFromNJIA(
  userId: string,
  txHash: string,
  expectedAmount?: number
): Promise<{
  success: boolean;
  tokensAdded: number;
  njiaAmount: number;
  message: string;
}> {
  try {
    console.log(
      `[Crypto] Processing NJIA deposit for user ${userId}, tx ${txHash}`
    );

    // Vérifier que la transaction n'a pas déjà été traitée
    const { data: existingPurchase } = await supabase
      .from("token_purchases")
      .select("id")
      .eq("transaction_reference", txHash)
      .single();

    if (existingPurchase) {
      return {
        success: false,
        tokensAdded: 0,
        njiaAmount: 0,
        message: "Cette transaction a déjà été traitée",
      };
    }

    // Vérifier la transaction sur la blockchain
    const txInfo = await verifyTransaction(txHash);

    if (!txInfo.isValid) {
      return {
        success: false,
        tokensAdded: 0,
        njiaAmount: 0,
        message: "Transaction invalide ou non confirmée",
      };
    }

    if (txInfo.confirmations < 3) {
      return {
        success: false,
        tokensAdded: 0,
        njiaAmount: 0,
        message: `Transaction en cours de confirmation (${txInfo.confirmations}/3 blocks)`,
      };
    }

    const njiaAmount = parseFloat(txInfo.amountFormatted || "0");

    if (njiaAmount === 0) {
      return {
        success: false,
        tokensAdded: 0,
        njiaAmount: 0,
        message: "Montant NJIA invalide",
      };
    }

    // Vérifier le montant minimum (10 NJIA)
    if (njiaAmount < 10) {
      return {
        success: false,
        tokensAdded: 0,
        njiaAmount: 0,
        message: `Montant minimum : 10 NJIA (reçu : ${njiaAmount.toFixed(
          2
        )} NJIA)`,
      };
    }

    // Calculer le nombre de tokens CHAP-CHAP à créditer
    const tokensToCredit = Math.floor(njiaAmount * NJIA_TO_CHAPCHAP_TOKENS);

    // Enregistrer l'achat dans token_purchases
    const { error: purchaseError } = await supabase
      .from("token_purchases")
      .insert({
        user_id: userId,
        package_id: null, // Pas de package pour crypto
        token_amount: tokensToCredit,
        bonus_tokens: 0,
        total_tokens: tokensToCredit,
        price_paid: Math.round(njiaAmount * NJIA_TO_FCFA),
        transaction_reference: txHash,
        payment_status: "completed",
        sender_phone: null,
        mobile_money_number_id: null,
        validated_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
        admin_notes: `Crédit automatique depuis ${njiaAmount} NJIA (blockchain: ${txHash})`,
      });

    if (purchaseError) {
      console.error("[Crypto] Error recording purchase:", purchaseError);
      throw purchaseError;
    }

    // Créditer les tokens via la fonction add_tokens
    const { error: creditError } = await supabase.rpc("add_tokens", {
      p_user_id: userId,
      p_token_type: "course",
      p_amount: tokensToCredit,
      p_reference_id: txHash,
    });

    if (creditError) {
      console.error("[Crypto] Error crediting tokens:", creditError);
      throw creditError;
    }

    console.log(
      `[Crypto] ✅ Credited ${tokensToCredit} tokens from ${njiaAmount} NJIA`
    );

    return {
      success: true,
      tokensAdded: tokensToCredit,
      njiaAmount,
      message: `${tokensToCredit} tokens crédités depuis ${njiaAmount.toFixed(
        2
      )} NJIA`,
    };
  } catch (error) {
    console.error("[Crypto] Error in creditTokensFromNJIA:", error);
    return {
      success: false,
      tokensAdded: 0,
      njiaAmount: 0,
      message: error instanceof Error ? error.message : "Erreur inconnue",
    };
  }
}

/**
 * Récupère l'historique des transactions NJIA d'une adresse
 */
export async function getNJIATransactionHistory(
  walletAddress: string,
  limit: number = 50
): Promise<
  Array<{
    hash: string;
    from: string;
    to: string;
    amount: string;
    timestamp: number;
    blockNumber: number;
  }>
> {
  try {
    // Utiliser etherscan-like API ou subgraph
    // Pour l'instant, retourner tableau vide
    // TODO: Implémenter avec Polygon scan API
    console.log(`[Crypto] Getting transaction history for ${walletAddress}`);
    return [];
  } catch (error) {
    console.error("[Crypto] Error getting transaction history:", error);
    return [];
  }
}

// =====================================================
// UTILITAIRES
// =====================================================

/**
 * Valide un hash de transaction Polygon
 */
export function isValidTxHash(txHash: string): boolean {
  return /^0x([A-Fa-f0-9]{64})$/.test(txHash);
}

/**
 * Valide une adresse Ethereum/Polygon
 */
export function isValidAddress(address: string): boolean {
  return ethers.isAddress(address);
}

/**
 * Calcule le nombre de tokens CHAP-CHAP équivalents à X NJIA
 */
export function calculateChapChapTokensFromNJIA(njiaAmount: number): number {
  return Math.floor(njiaAmount * NJIA_TO_CHAPCHAP_TOKENS);
}

/**
 * Calcule le montant NJIA nécessaire pour X tokens CHAT-CHAP
 */
export function calculateNJIAFromChapChapTokens(
  chatChapTokens: number
): number {
  return chatChapTokens / NJIA_TO_CHAPCHAP_TOKENS;
}

// Export configuration pour tests
export const config = {
  NJIA_TO_FCFA,
  CHAPCHAP_TOKEN_COST_FCFA,
  NJIA_TO_CHAPCHAP_TOKENS,
  NJIA_TOKEN_ADDRESS,
  POLYGON_RPC_URL: isTestnet ? POLYGON_TESTNET_RPC : POLYGON_RPC_URL,
  isTestnet,
};
