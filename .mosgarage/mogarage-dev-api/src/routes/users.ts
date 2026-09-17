import { Router } from "express";
import { users } from "../db/store";

export const usersRouter = Router();

// In this reference implementation there's no real session/identity
// resolution wired up, so /users/me just returns the seeded demo user.
// Wire this to your auth layer (JWT claims, session lookup, etc.) later.
usersRouter.get("/me", (_req, res) => {
  const me = users.all()[0];
  res.json(me);
});
