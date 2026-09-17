import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import path from "path";
import swaggerUi from "swagger-ui-express";
import YAML from "yamljs";

import { apiRouter } from "./routes";
import { requireAuth } from "./middleware/auth";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(morgan("dev"));
  app.use(express.json());

  // Health check is unauthenticated, outside the /api/v1 auth gate.
  app.get("/api/v1/health", (_req, res) => {
    res.json({ status: "ok", time: new Date().toISOString() });
  });

  // Swagger UI at /docs, serving openapi.yaml from the project root.
  const openapiDocument = YAML.load(path.join(__dirname, "..", "openapi.yaml"));
  app.use("/docs", swaggerUi.serve, swaggerUi.setup(openapiDocument));
  app.get("/openapi.json", (_req, res) => res.json(openapiDocument));

  app.use("/api/v1", requireAuth, apiRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
