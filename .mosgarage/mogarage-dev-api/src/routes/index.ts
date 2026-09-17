import { Router } from "express";
import { usersRouter } from "./users";
import { teamsRouter } from "./teams";
import { projectsRouter } from "./projects";
import { environmentsRouter } from "./environments";
import { envVarsRouter } from "./envVars";
import { deploymentsRouter } from "./deployments";
import { domainsRouter } from "./domains";

export const apiRouter = Router();

apiRouter.use("/users", usersRouter);
apiRouter.use("/teams", teamsRouter);
apiRouter.use("/projects", projectsRouter);
apiRouter.use("/environments", environmentsRouter);
apiRouter.use("/env-vars", envVarsRouter);
apiRouter.use("/deployments", deploymentsRouter);
apiRouter.use("/domains", domainsRouter);
