import { describe, it, expect } from "vitest";
import request from "supertest";
import { createApp } from "../src/app";

async function waitForStatus(
  app: ReturnType<typeof createApp>,
  deploymentId: string,
  status: string,
  timeoutMs = 3000
) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const res = await request(app).get(`/api/v1/deployments/${deploymentId}`);
    if (res.body.status === status) return res.body;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error(`Timed out waiting for status ${status}`);
}

describe("Deployment lifecycle", () => {
  const app = createApp();

  it("progresses queued -> building -> deploying -> ready, then can be promoted", async () => {
    const team = await request(app)
      .post("/api/v1/teams")
      .send({ name: "DeployCo", slug: "deployco-" + Date.now() });
    const project = await request(app).post("/api/v1/projects").send({
      teamId: team.body.id,
      name: "svc",
      slug: "svc-" + Date.now(),
    });
    const [env] = (
      await request(app).get(`/api/v1/projects/${project.body.id}/environments`)
    ).body;

    const deployment = await request(app)
      .post(`/api/v1/projects/${project.body.id}/deployments`)
      .send({ environmentId: env.id, commitSha: "abcdef1", commitMessage: "test" });

    expect(deployment.status).toBe(201);
    expect(deployment.body.status).toBe("queued");

    const ready = await waitForStatus(app, deployment.body.id, "ready");
    expect(ready.url).toBeTruthy();
    expect(ready.readyAt).toBeTruthy();

    const promote = await request(app).post(
      `/api/v1/deployments/${deployment.body.id}/promote`
    );
    expect(promote.status).toBe(200);

    const updatedEnv = await request(app).get(`/api/v1/environments/${env.id}`);
    expect(updatedEnv.body.latestDeploymentId).toBe(deployment.body.id);
  });

  it("blocks promoting a deployment that isn't ready", async () => {
    const team = await request(app)
      .post("/api/v1/teams")
      .send({ name: "T2", slug: "t2-" + Date.now() });
    const project = await request(app).post("/api/v1/projects").send({
      teamId: team.body.id,
      name: "svc2",
      slug: "svc2-" + Date.now(),
    });
    const [env] = (
      await request(app).get(`/api/v1/projects/${project.body.id}/environments`)
    ).body;

    const deployment = await request(app)
      .post(`/api/v1/projects/${project.body.id}/deployments`)
      .send({ environmentId: env.id, commitSha: "abcdef2" });

    const promote = await request(app).post(
      `/api/v1/deployments/${deployment.body.id}/promote`
    );
    expect(promote.status).toBe(409);
  });

  it("can cancel a queued deployment", async () => {
    const team = await request(app)
      .post("/api/v1/teams")
      .send({ name: "T3", slug: "t3-" + Date.now() });
    const project = await request(app).post("/api/v1/projects").send({
      teamId: team.body.id,
      name: "svc3",
      slug: "svc3-" + Date.now(),
    });
    const [env] = (
      await request(app).get(`/api/v1/projects/${project.body.id}/environments`)
    ).body;

    const deployment = await request(app)
      .post(`/api/v1/projects/${project.body.id}/deployments`)
      .send({ environmentId: env.id, commitSha: "abcdef3" });

    const cancel = await request(app).delete(
      `/api/v1/deployments/${deployment.body.id}`
    );
    expect(cancel.status).toBe(204);

    const getRes = await request(app).get(
      `/api/v1/deployments/${deployment.body.id}`
    );
    expect(getRes.body.status).toBe("canceled");
  });
});
