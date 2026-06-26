import app from "./app";
import { config } from "./config";
import { createServer } from "http";
import { initRealtime } from "./realtime";

const server = createServer(app);
initRealtime(server);

server.listen(config.port, () => {
  console.log(
    `Drunkard API running on port ${config.port} [${config.nodeEnv}]`,
  );
});
