import "dotenv/config";
import { createApp } from "./app";
import { seed } from "./db/store";

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3001;

seed();

const app = createApp();

app.listen(PORT, () => {
  console.log(`MoGarage Dev control-plane API listening on http://localhost:${PORT}`);
  console.log(`API base:  http://localhost:${PORT}/api/v1`);
  console.log(`Docs (Swagger UI): http://localhost:${PORT}/docs`);
});
