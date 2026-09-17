import { Router } from "express";
import { environments, envVars, domains, timestamp } from "../db/store";
import { NotFound, Conflict } from "../utils/http";
import { EnvironmentInput, EnvVarInput, DomainInput } from "../schemas";

export const environmentsRouter = Router();

environmentsRouter.get("/:environmentId", (req, res, next) => {
  const item = environments.get(req.params.environmentId);
  if (!item) return next(NotFound("Environment"));
  res.json(item);
});

environmentsRouter.delete("/:environmentId", (req, res, next) => {
  const item = environments.get(req.params.environmentId);
  if (!item) return next(NotFound("Environment"));
  if (item.isProduction) {
    return next(Conflict("Cannot delete the production environment"));
  }
  environments.delete(req.params.environmentId);
  res.status(204).send();
});

function redact(envVar: ReturnType<typeof envVars.get>) {
  if (!envVar) return envVar;
  return { ...envVar, value: "••••••••" };
}

environmentsRouter.get("/:environmentId/env-vars", (req, res, next) => {
  if (!environments.get(req.params.environmentId)) return next(NotFound("Environment"));
  const items = envVars
    .all()
    .filter((v) => v.environmentId === req.params.environmentId)
    .map(redact);
  res.json(items);
});

environmentsRouter.post("/:environmentId/env-vars", (req, res, next) => {
  try {
    if (!environments.get(req.params.environmentId)) return next(NotFound("Environment"));
    const input = EnvVarInput.parse(req.body);
    const created = envVars.create({
      environmentId: req.params.environmentId,
      ...input,
      createdAt: timestamp(),
      updatedAt: timestamp(),
    });
    // Value is echoed back once, on creation, so the caller can confirm it.
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});

environmentsRouter.get("/:environmentId/domains", (req, res, next) => {
  if (!environments.get(req.params.environmentId)) return next(NotFound("Environment"));
  res.json(domains.all().filter((d) => d.environmentId === req.params.environmentId));
});

environmentsRouter.post("/:environmentId/domains", (req, res, next) => {
  try {
    if (!environments.get(req.params.environmentId)) return next(NotFound("Environment"));
    const input = DomainInput.parse(req.body);
    const created = domains.create({
      environmentId: req.params.environmentId,
      hostname: input.hostname,
      verified: false, // real impl: kick off DNS verification here
      createdAt: timestamp(),
    });
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});
