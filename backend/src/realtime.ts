import { Server } from "http";
import { Server as SocketServer } from "socket.io";
import { config } from "./config";
import { verifyToken } from "./utils/jwt";

let io: SocketServer | null = null;

export type RealtimeEvent =
  | "order:created"
  | "order:updated"
  | "bar:status_updated"
  | "drinks:updated"
  | "inventory:updated";

export function initRealtime(server: Server): SocketServer {
  io = new SocketServer(server, {
    cors: {
      origin: (origin, callback) => {
        if (!origin || config.isDev) {
          callback(null, true);
          return;
        }
        const allowedOrigins = new Set([
          config.frontendUrl,
          ...config.corsOrigins,
        ]);
        callback(null, allowedOrigins.has(origin));
      },
    },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (typeof token !== "string" || !token.trim()) {
      next(new Error("未登录"));
      return;
    }

    try {
      const user = verifyToken(token);
      socket.data.user = user;
      socket.join(user.role === "ADMIN" ? "admins" : `user:${user.userId}`);
      next();
    } catch {
      next(new Error("登录已过期"));
    }
  });

  io.on("connection", (socket) => {
    socket.emit("realtime:ready");
  });

  return io;
}

export function broadcastRealtime(
  event: RealtimeEvent,
  payload: Record<string, unknown> = {},
): void {
  io?.emit(event, { ...payload, emittedAt: new Date().toISOString() });
}

export function broadcastOrderCreated(userId: string, orderId: string): void {
  io?.to("admins").to(`user:${userId}`).emit("order:created", {
    orderId,
    userId,
    emittedAt: new Date().toISOString(),
  });
}

export function broadcastOrderUpdated(userId: string, orderId: string): void {
  io?.to("admins").to(`user:${userId}`).emit("order:updated", {
    orderId,
    userId,
    emittedAt: new Date().toISOString(),
  });
}
