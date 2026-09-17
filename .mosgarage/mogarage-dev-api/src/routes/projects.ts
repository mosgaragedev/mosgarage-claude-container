import { Router } from "express";
import {
  projects,
  environments,
  deployments,
  timestamp,
  startDeploymentLifecycle,
} from "../db/store";
import { paginate, NotFound } from "../utils/http";
import { ProjectInput, ProjectUpdate, DeploymentInput } from "../schemas";

export const projectsRouter = Router();

projectsRouter.get("/", (req, res) => {
  let items = projects.all();
  if (req.query.teamId) {
    items = items.filter((p) => p.teamId === req.query.teamId);
  }
  res.json(paginate(items, req));
});

projectsRouter.post("/", (req, res, next) => {
  try {
    const input = ProjectInput.parse(req.body);
    const created = projects.create({
      ...input,
      createdAt: timestamp(),
      updatedAt: timestamp(),
    });

    // Every project gets a default production environment.
    environments.create({
      projectId: created.id,
      name: "production",
      isProduction: true,
      latestDeploymentId: null,
      createdAt: timestamp(),
    });

    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});

projectsRouter.get("/:projectId", (req, res, next) => {
  const item = projects.get(req.params.projectId);
  if (!item) return next(NotFound("Project"));
  res.json(item);
});

projectsRouter.patch("/:projectId", (req, res, next) => {
  try {
    const patch = ProjectUpdate.parse(req.body);
    const updated = projects.update(req.params.projectId, {
      ...patch,
      updatedAt: timestamp(),
    });
    if (!updated) return next(NotFound("Project"));
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

projectsRouter.delete("/:projectId", (req, res, next) => {
  if (!projects.get(req.params.projectId)) return next(NotFound("Project"));

  // Cascade delete environments and deployments belonging to this project.
  environments
    .all()
    .filter((e) => e.projectId === req.params.projectId)
    .forEach((e) => environments.delete(e.id));
  deployments
    .all()
    .filter((d) => d.projectId === req.params.projectId)
    .forEach((d) => deployments.delete(d.id));

  projects.delete(req.params.projectId);
  res.status(204).send();
});

// ---- Nested: environments ----
projectsRouter.get("/:projectId/environments", (req, res, next) => {
  if (!projects.get(req.params.projectId)) return next(NotFound("Project"));
  res.json(environments.all().filter((e) => e.projectId === req.params.projectId));
});

// ---- Nested: deployments ----
projectsRouter.get("/:projectId/deployments", (req, res, next) => {
  if (!projects.get(req.params.projectId)) return next(NotFound("Project"));
  let items = deployments.all().filter((d) => d.projectId === req.params.projectId);
  if (req.query.environmentId) {
    items = items.filter((d) => d.environmentId === req.query.environmentId);
  }
  if (req.query.status) {
    items = items.filter((d) => d.status === req.query.status);
  }
  res.json(paginate(items, req));
});

projectsRouter.post("/:projectId/deployments", (req, res, next) => {
  try {
    if (!projects.get(req.params.projectId)) return next(NotFound("Project"));
    const input = DeploymentInput.parse(req.body);
    if (!environments.get(input.environmentId)) {
      return next(NotFound("Environment"));
    }

    const created = deployments.create({
      projectId: req.params.projectId,
      environmentId: input.environmentId,
      status: "queued",
      commitSha: input.commitSha,
      commitMessage: input.commitMessage,
      url: null,
      createdAt: timestamp(),
      updatedAt: timestamp(),
      readyAt: null,
      logs: [`[${timestamp()}] deployment queued`],
    });

    startDeploymentLifecycle(created.id);
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});
