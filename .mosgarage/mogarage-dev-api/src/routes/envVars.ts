import { Router } from "express";
import { envVars, timestamp } from "../db/store";
import { NotFound } from "../utils/http";
import { EnvVarValueUpdate } from "../schemas";

export const envVarsRouter = Router();

envVarsRouter.patch("/:envVarId", (req, res, next) => {
  try {
    const { value } = EnvVarValueUpdate.parse(req.body);
    const updated = envVars.update(req.params.envVarId, {
      value,
      updatedAt: timestamp(),
    });
    if (!updated) return next(NotFound("EnvVar"));
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

envVarsRouter.delete("/:envVarId", (req, res, next) => {
  const ok = envVars.delete(req.params.envVarId);
  if (!ok) return next(NotFound("EnvVar"));
  res.status(204).send();
});
