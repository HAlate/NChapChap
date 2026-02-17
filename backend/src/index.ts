import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { json } from "body-parser";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import userRoutes from "./user";
import tripRoutes from "./trip";
import paymentRoutes from "./payment";
import merchantRoutes from "./merchant";
import productRoutes from "./product";
import orderRoutes from "./order";
import cryptoRoutes from "./cryptoRoutes";
import noShowRoutes from "./noShow";
import { createClient } from "redis";
import { Pool } from "pg";

dotenv.config();

const app = express();
const port = process.env.PORT || 3001;

// Sécurité : En-têtes HTTP sécurisés
app.use(helmet());

// Sécurité : Limitation de débit (Rate Limiting)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 100, // Limite chaque IP à 100 requêtes par fenêtre
  standardHeaders: true, // Retourne les infos de limite dans les headers `RateLimit-*`
  legacyHeaders: false, // Désactive les headers `X-RateLimit-*`
  message: "Trop de requêtes, veuillez réessayer plus tard."
});
app.use(limiter);

// Sécurité : Configuration CORS plus stricte
const allowedOrigins = process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*';
app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// PostgreSQL
const pgPool = new Pool({
  connectionString:
    process.env.DATABASE_URL ||
    "postgresql://postgres:postgres@localhost:5432/urbanmobility",
});

// Redis (optionnel)
let redisClient: any = null;

if (process.env.REDIS_URL) {
  redisClient = createClient({
    url: process.env.REDIS_URL,
  });

  // Connexion Redis avec gestion d'erreur
  redisClient.connect().catch((err: Error) => {
    console.warn("⚠️  Redis not available:", err.message);
    console.warn("⚠️  Backend will run without Redis cache");
    redisClient = null;
  });

  redisClient.on("error", (err: Error) => {
    console.warn("Redis Client Error:", err.message);
  });
} else {
  console.log("ℹ️  Redis disabled (no REDIS_URL configured)");
}

app.use(json());

// Routes
app.use("/api/users", userRoutes(pgPool));
app.use("/api/trips", tripRoutes(pgPool));
app.use("/api/payments", paymentRoutes(pgPool, redisClient));
app.use("/api/merchants", merchantRoutes(pgPool));
app.use("/api/products", productRoutes(pgPool));
app.use("/api/orders", orderRoutes(pgPool));
app.use("/api/crypto", cryptoRoutes);
app.use("/api/no-show", noShowRoutes(pgPool));

app.get("/", (req, res) => {
  res.send("Urban Mobility Backend API (Secured)");
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
