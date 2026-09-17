import { Router } from "express";
import { deployments, environments, timestamp } from "../db/store";
import { NotFound, Conflict } from "../utils/http";

export const deploymentsRouter = Router();

const TERMINAL_STATES = new Set(["ready", "error", "canceled"]);

deploymentsRouter.get("/:deploymentId", (req, res, next) => {
  const item = deployments.get(req.params.deploymentId);
  if (!item) return next(NotFound("Deployment"));
  res.json(item);
});

deploymentsRouter.delete("/:deploymentId", (req, res, next) => {
  const item = deployments.get(req.params.deploymentId);
  if (!item) return next(NotFound("Deployment"));
  if (TERMINAL_STATES.has(item.status)) {
    return next(Conflict(`Deployment is already ${item.status}`));
  }
  deployments.update(req.params.deploymentId, {
    status: "canceled",
    updatedAt: timestamp(),
    logs: [...item.logs, `[${timestamp()}] deployment canceled`],
  });
  res.status(204).send();
});

deploymentsRouter.get("/:deploymentId/logs", (req, res, next) => {
  const item = deployments.get(req.params.deploymentId);
  if (!item) return next(NotFound("Deployment"));
  res.json({ deploymentId: item.id, lines: item.logs });
});

deploymentsRouter.post("/:deploymentId/promote", (req, res, next) => {
  const item = deployments.get(req.params.deploymentId);
  if (!item) return next(NotFound("Deployment"));
  if (item.status !== "ready") {
    return next(Conflict("Only a ready deployment can be promoted"));
  }
  environments.update(item.environmentId, { latestDeploymentId: item.id });
  res.json(item);
});
