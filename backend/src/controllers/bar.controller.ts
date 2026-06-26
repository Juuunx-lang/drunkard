import { BarStatus, PrismaClient } from "@prisma/client";
import { Request, Response } from "express";
import { broadcastRealtime } from "../realtime";

const prisma = new PrismaClient();
const statuses = ["IDLE", "BUSY", "CLOSED"];

export async function getBarStatus(
  _req: Request,
  res: Response,
): Promise<void> {
  const setting = await prisma.barSetting.upsert({
    where: { id: "bar" },
    update: {},
    create: { id: "bar", status: "IDLE" },
  });
  res.json({ status: setting.status, updatedAt: setting.updatedAt });
}

export async function updateBarStatus(
  req: Request,
  res: Response,
): Promise<void> {
  const { status } = req.body;
  if (!statuses.includes(status)) {
    res.status(400).json({ error: "无效的吧台状态" });
    return;
  }
  const setting = await prisma.barSetting.upsert({
    where: { id: "bar" },
    update: { status: status as BarStatus },
    create: { id: "bar", status: status as BarStatus },
  });
  broadcastRealtime("bar:status_updated", { status: setting.status });
  res.json({ status: setting.status, updatedAt: setting.updatedAt });
}
