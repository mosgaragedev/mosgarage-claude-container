import { describe, it, expect } from "vitest";
import request from "supertest";
import { createApp } from "../src/app";

describe("Teams & Projects API", () => {
  const app = createApp();

  it("creates a team and a project, auto-provisioning production", async () => {
    const team = await request(app)
      .post("/api/v1/teams")
      .send({ name: "Acme Inc", slug: "acme-inc", ownerId: crypto.randomUUID() });
    expect(team.status).toBe(201);

    const project = await request(app).post("/api/v1/projects").send({
      teamId: team.body.id,
      name: "marketing-site",
      slug: "marketing-site",
      framework: "static",
    });
    expect(project.status).toBe(201);

    const envs = await request(app).get(
      `/api/v1/projects/${project.body.id}/environments`
    );
    expect(envs.status).toBe(200);
    expect(envs.body).toHaveLength(1);
    expect(envs.body[0].name).toBe("production");
    expect(envs.body[0].isProduction).toBe(true);
  });

  it("rejects an invalid slug", async () => {
    const res = await request(app)
      .post("/api/v1/teams")
      .send({ name: "Bad Slug Co", slug: "Not Valid Slug!" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Validation failed");
  });

  it("redacts env var values in list responses", async () => {
    const team = await request(app)
      .post("/api/v1/teams")
      .send({ name: "T", slug: "t-" + Date.now() });
    const project = await request(app).post("/api/v1/projects").send({
      teamId: team.body.id,
      name: "app",
      slug: "app-" + Date.now(),
    });
    const [env] = (
      await request(app).get(`/api/v1/projects/${project.body.id}/environments`)
    ).body;

    await request(app)
      .post(`/api/v1/environments/${env.id}/env-vars`)
      .send({ key: "SECRET_KEY", value: "super-secret" });

    const list = await request(app).get(`/api/v1/environments/${env.id}/env-vars`);
    expect(list.status).toBe(200);
    expect(list.body[0].value).not.toBe("super-secret");
  });
});
