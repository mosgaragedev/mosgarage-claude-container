import { z } from "zod";

export const TeamRole = z.enum(["owner", "admin", "member"]);

export const TeamInput = z.object({
  name: z.string().min(1),
  slug: z
    .string()
    .min(1)
    .regex(/^[a-z0-9-]+$/, "slug must be lowercase alphanumeric with hyphens"),
});
export const TeamUpdate = z.object({
  name: z.string().min(1).optional(),
});
export const TeamMemberInput = z.object({
  userId: z.string().uuid(),
  role: TeamRole,
});
export const TeamMemberRoleUpdate = z.object({
  role: TeamRole,
});

export const ProjectFramework = z.enum([
  "node",
  "python",
  "go",
  "static",
  "docker",
  "other",
]);
export const ProjectInput = z.object({
  teamId: z.string().uuid(),
  name: z.string().min(1),
  slug: z
    .string()
    .min(1)
    .regex(/^[a-z0-9-]+$/, "slug must be lowercase alphanumeric with hyphens"),
  repoUrl: z.string().url().optional(),
  framework: ProjectFramework.optional(),
});
export const ProjectUpdate = z.object({
  name: z.string().min(1).optional(),
  repoUrl: z.string().url().optional(),
  framework: ProjectFramework.optional(),
});

export const EnvironmentInput = z.object({
  name: z.string().min(1),
});

export const EnvVarInput = z.object({
  key: z
    .string()
    .min(1)
    .regex(/^[A-Z0-9_]+$/, "key should be UPPER_SNAKE_CASE"),
  value: z.string(),
});
export const EnvVarValueUpdate = z.object({
  value: z.string(),
});

export const DeploymentStatus = z.enum([
  "queued",
  "building",
  "deploying",
  "ready",
  "error",
  "canceled",
]);
export const DeploymentInput = z.object({
  environmentId: z.string().uuid(),
  commitSha: z.string().min(4),
  commitMessage: z.string().optional(),
});

export const DomainInput = z.object({
  hostname: z
    .string()
    .min(3)
    .regex(/^[a-z0-9.-]+\.[a-z]{2,}$/i, "must be a valid hostname"),
});
