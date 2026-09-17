import { Router } from "express";
import { domains } from "../db/store";
import { NotFound } from "../utils/http";

export const domainsRouter = Router();

domainsRouter.delete("/:domainId", (req, res, next) => {
  const ok = domains.delete(req.params.domainId);
  if (!ok) return next(NotFound("Domain"));
  res.status(204).send();
});
