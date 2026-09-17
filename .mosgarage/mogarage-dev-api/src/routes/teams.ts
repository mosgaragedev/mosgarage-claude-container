import { Router } from "express";
import { teams, teamMembersStore, timestamp } from "../db/store";
import { paginate, NotFound } from "../utils/http";
import {
  TeamInput,
  TeamUpdate,
  TeamMemberInput,
  TeamMemberRoleUpdate,
} from "../schemas";

export const teamsRouter = Router();

teamsRouter.get("/", (req, res) => {
  res.json(paginate(teams.all(), req));
});

teamsRouter.post("/", (req, res, next) => {
  try {
    const input = TeamInput.parse(req.body);
    const created = teams.create({
      ...input,
      ownerId: req.body.ownerId ?? "unknown", // real impl: derive from auth context
      createdAt: timestamp(),
      updatedAt: timestamp(),
    });
    teamMembersStore.add({
      teamId: created.id,
      userId: created.ownerId,
      role: "owner",
      joinedAt: timestamp(),
    });
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});

teamsRouter.get("/:teamId", (req, res, next) => {
  const item = teams.get(req.params.teamId);
  if (!item) return next(NotFound("Team"));
  res.json(item);
});

teamsRouter.patch("/:teamId", (req, res, next) => {
  try {
    const patch = TeamUpdate.parse(req.body);
    const updated = teams.update(req.params.teamId, {
      ...patch,
      updatedAt: timestamp(),
    });
    if (!updated) return next(NotFound("Team"));
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

teamsRouter.delete("/:teamId", (req, res, next) => {
  const ok = teams.delete(req.params.teamId);
  if (!ok) return next(NotFound("Team"));
  res.status(204).send();
});

teamsRouter.get("/:teamId/members", (req, res, next) => {
  if (!teams.get(req.params.teamId)) return next(NotFound("Team"));
  res.json(teamMembersStore.all(req.params.teamId));
});

teamsRouter.post("/:teamId/members", (req, res, next) => {
  try {
    if (!teams.get(req.params.teamId)) return next(NotFound("Team"));
    const input = TeamMemberInput.parse(req.body);
    const member = teamMembersStore.add({
      teamId: req.params.teamId,
      userId: input.userId,
      role: input.role,
      joinedAt: timestamp(),
    });
    res.status(201).json(member);
  } catch (err) {
    next(err);
  }
});

teamsRouter.patch("/:teamId/members/:userId", (req, res, next) => {
  try {
    const { role } = TeamMemberRoleUpdate.parse(req.body);
    const updated = teamMembersStore.update(
      req.params.teamId,
      req.params.userId,
      role
    );
    if (!updated) return next(NotFound("Team member"));
    res.json(updated);
  } catch (err) {
    next(err);
  }
});

teamsRouter.delete("/:teamId/members/:userId", (req, res, next) => {
  const ok = teamMembersStore.remove(req.params.teamId, req.params.userId);
  if (!ok) return next(NotFound("Team member"));
  res.status(204).send();
});
