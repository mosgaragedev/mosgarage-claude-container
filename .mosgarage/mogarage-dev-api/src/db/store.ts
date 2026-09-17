// Simple in-memory data store.
// Swap this out for a real database (Postgres/Prisma, etc.) when you're ready -
// every route only talks to the methods below, so that's the one file to replace.

import { randomUUID } from "crypto";

export type ID = string;

export interface User {
  id: ID;
  email: string;
  name: string;
  createdAt: string;
}

export type TeamRole = "owner" | "admin" | "member";

export interface Team {
  id: ID;
  name: string;
  slug: string;
  ownerId: ID;
  createdAt: string;
  updatedAt: string;
}

export interface TeamMember {
  teamId: ID;
  userId: ID;
  role: TeamRole;
  joinedAt: string;
}

export type ProjectFramework =
  | "node"
  | "python"
  | "go"
  | "static"
  | "docker"
  | "other";

export interface Project {
  id: ID;
  teamId: ID;
  name: string;
  slug: string;
  repoUrl?: string;
  framework?: ProjectFramework;
  createdAt: string;
  updatedAt: string;
}

export interface Environment {
  id: ID;
  projectId: ID;
  name: string;
  isProduction: boolean;
  latestDeploymentId?: ID | null;
  createdAt: string;
}

export interface EnvVar {
  id: ID;
  environmentId: ID;
  key: string;
  value: string;
  createdAt: string;
  updatedAt: string;
}

export type DeploymentStatus =
  | "queued"
  | "building"
  | "deploying"
  | "ready"
  | "error"
  | "canceled";

export interface Deployment {
  id: ID;
  projectId: ID;
  environmentId: ID;
  status: DeploymentStatus;
  commitSha: string;
  commitMessage?: string;
  url?: string | null;
  createdAt: string;
  updatedAt: string;
  readyAt?: string | null;
  logs: string[];
}

export interface Domain {
  id: ID;
  environmentId: ID;
  hostname: string;
  verified: boolean;
  createdAt: string;
}

function now(): string {
  return new Date().toISOString();
}

class Store<T extends { id: ID }> {
  private items = new Map<ID, T>();

  all(): T[] {
    return Array.from(this.items.values());
  }

  get(id: ID): T | undefined {
    return this.items.get(id);
  }

  create(data: Omit<T, "id">): T {
    const id = randomUUID();
    const item = { ...data, id } as T;
    this.items.set(id, item);
    return item;
  }

  update(id: ID, patch: Partial<T>): T | undefined {
    const existing = this.items.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...patch } as T;
    this.items.set(id, updated);
    return updated;
  }

  delete(id: ID): boolean {
    return this.items.delete(id);
  }
}

export const users = new Store<User>();
export const teams = new Store<Team>();
export const projects = new Store<Project>();
export const environments = new Store<Environment>();
export const envVars = new Store<EnvVar>();
export const deployments = new Store<Deployment>();
export const domains = new Store<Domain>();

// Team membership isn't keyed by a single id, so it's stored separately.
const teamMembers: TeamMember[] = [];
export const teamMembersStore = {
  all(teamId: ID) {
    return teamMembers.filter((m) => m.teamId === teamId);
  },
  find(teamId: ID, userId: ID) {
    return teamMembers.find((m) => m.teamId === teamId && m.userId === userId);
  },
  add(member: TeamMember) {
    teamMembers.push(member);
    return member;
  },
  update(teamId: ID, userId: ID, role: TeamRole) {
    const m = teamMembers.find((m) => m.teamId === teamId && m.userId === userId);
    if (m) m.role = role;
    return m;
  },
  remove(teamId: ID, userId: ID) {
    const idx = teamMembers.findIndex(
      (m) => m.teamId === teamId && m.userId === userId
    );
    if (idx === -1) return false;
    teamMembers.splice(idx, 1);
    return true;
  },
};

export function timestamp(): string {
  return now();
}

// ---- Deployment lifecycle simulation ----
// Real implementations would drive this from actual build/deploy workers.
// Here we just advance the status on a short timer so the API behaves
// realistically (queued -> building -> deploying -> ready).
const LIFECYCLE: DeploymentStatus[] = ["queued", "building", "deploying", "ready"];
const STEP_MS = 150;

export function startDeploymentLifecycle(deploymentId: ID) {
  let stepIndex = LIFECYCLE.indexOf("queued");

  const advance = () => {
    const deployment = deployments.get(deploymentId);
    // Stop if the deployment was canceled/deleted out from under us.
    if (!deployment || deployment.status === "canceled" || deployment.status === "error") {
      return;
    }

    stepIndex += 1;
    if (stepIndex >= LIFECYCLE.length) return;

    const status = LIFECYCLE[stepIndex];
    const isReady = status === "ready";
    deployments.update(deploymentId, {
      status,
      updatedAt: timestamp(),
      logs: [...deployment.logs, `[${timestamp()}] status -> ${status}`],
      ...(isReady
        ? {
            readyAt: timestamp(),
            url: `https://${deployment.commitSha.slice(0, 7)}.${deployment.environmentId.slice(
              0,
              8
            )}.mogarage.dev`,
          }
        : {}),
    });

    if (isReady) {
      environments.update(deployment.environmentId, {
        latestDeploymentId: deploymentId,
      });
    } else {
      setTimeout(advance, STEP_MS);
    }
  };

  setTimeout(advance, STEP_MS);
}

// ---- Seed data so the API is immediately explorable ----
export function seed() {
  const u1 = users.create({
    email: "mo@mogarage.dev",
    name: "Moses",
    createdAt: now(),
  });

  const t1 = teams.create({
    name: "MoGarage",
    slug: "mogarage",
    ownerId: u1.id,
    createdAt: now(),
    updatedAt: now(),
  });

  teamMembersStore.add({
    teamId: t1.id,
    userId: u1.id,
    role: "owner",
    joinedAt: now(),
  });

  const p1 = projects.create({
    teamId: t1.id,
    name: "example-web-app",
    slug: "example-web-app",
    repoUrl: "https://github.com/mosgarage/example-web-app",
    framework: "node",
    createdAt: now(),
    updatedAt: now(),
  });

  const prodEnv = environments.create({
    projectId: p1.id,
    name: "production",
    isProduction: true,
    latestDeploymentId: null,
    createdAt: now(),
  });

  environments.create({
    projectId: p1.id,
    name: "staging",
    isProduction: false,
    latestDeploymentId: null,
    createdAt: now(),
  });

  envVars.create({
    environmentId: prodEnv.id,
    key: "NODE_ENV",
    value: "production",
    createdAt: now(),
    updatedAt: now(),
  });

  const d1 = deployments.create({
    projectId: p1.id,
    environmentId: prodEnv.id,
    status: "queued",
    commitSha: "a1b2c3d4",
    commitMessage: "Initial deploy",
    url: null,
    createdAt: now(),
    updatedAt: now(),
    readyAt: null,
    logs: [`[${now()}] deployment queued`],
  });
  startDeploymentLifecycle(d1.id);
}
