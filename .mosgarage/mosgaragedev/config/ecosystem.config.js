// PM2 Ecosystem — mosgaragedev home base
// Usage: pm2 start /app/ecosystem.config.js
module.exports = {
  apps: [
    {
      name: "node-server",
      script: "/app/server/index.js",
      cwd: "/app/server",
      instances: 1,
      exec_mode: "fork",
      watch: false,
      env: {
        NODE_ENV: process.env.NODE_ENV || "production",
        PORT: process.env.NODE_SERVER_PORT || 3001,
      },
      error_file: "/var/log/mosgaragedev/node-server.err",
      out_file: "/var/log/mosgaragedev/node-server.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      max_restarts: 10,
      restart_delay: 3001,
    },
    {
      name: "api-server",
      script: "/app/api/index.js",
      cwd: "/app/api",
      instances: 1,
      exec_mode: "fork",
      watch: false,
      env: {
        NODE_ENV: process.env.NODE_ENV || "production",
        PORT: process.env.API_PORT || 4001,
      },
      error_file: "/var/log/mosgaragedev/api-server.err",
      out_file: "/var/log/mosgaragedev/api-server.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      max_restarts: 10,
      restart_delay: 3001,
    },
  ],
};
