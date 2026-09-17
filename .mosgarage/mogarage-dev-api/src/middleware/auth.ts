import { NextFunction, Request, Response } from "express";

// Minimal bearer-token check for demo purposes.
// Set API_TOKEN in .env; requests must send `Authorization: Bearer <token>`.
// Swap this for real JWT/OAuth verification (and per-user identity resolution)
// before going to production.
export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const configuredToken = process.env.API_TOKEN;

  // If no token is configured, auth is disabled (useful for local dev).
  if (!configuredToken) return next();

  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing bearer token" });
  }

  const token = header.slice("Bearer ".length);
  if (token !== configuredToken) {
    return res.status(401).json({ error: "Invalid token" });
  }

  next();
}
