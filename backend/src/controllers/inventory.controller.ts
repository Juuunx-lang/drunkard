import { PrismaClient } from "@prisma/client";
import { Request, Response } from "express";
import { broadcastRealtime } from "../realtime";

const prisma = new PrismaClient();

export async function listIngredients(
  _req: Request,
  res: Response,
): Promise<void> {
  const ingredients = await prisma.ingredient.findMany({
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });

  const grouped = {
    BASE_SPIRIT: ingredients.filter((i) => i.category === "BASE_SPIRIT"),
    SYRUP: ingredients.filter((i) => i.category === "SYRUP"),
    MIXER: ingredients.filter((i) => i.category === "MIXER"),
  };

  res.json(grouped);
}

export async function createIngredient(
  req: Request,
  res: Response,
): Promise<void> {
  const { name, category, notes } = req.body;
  const ingredient = await prisma.ingredient.create({
    data: { name, category, notes },
  });
  broadcastRealtime("inventory:updated", { ingredientId: ingredient.id });
  broadcastRealtime("drinks:updated", { reason: "inventory" });
  res.status(201).json(ingredient);
}

export async function updateIngredient(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const { name, category, notes } = req.body;
  const ingredient = await prisma.ingredient.update({
    where: { id },
    data: { name, category, notes },
  });
  broadcastRealtime("inventory:updated", { ingredientId: ingredient.id });
  broadcastRealtime("drinks:updated", { reason: "inventory" });
  res.json(ingredient);
}

export async function toggleStock(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const current = await prisma.ingredient.findUnique({ where: { id } });
  if (!current) {
    res.status(404).json({ error: "原料不存在" });
    return;
  }
  const ingredient = await prisma.ingredient.update({
    where: { id },
    data: { inStock: !current.inStock },
  });
  broadcastRealtime("inventory:updated", { ingredientId: ingredient.id });
  broadcastRealtime("drinks:updated", { reason: "inventory" });
  res.json(ingredient);
}

export async function deleteIngredient(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const usageCount = await prisma.drinkIngredient.count({
    where: { ingredientId: id },
  });
  if (usageCount > 0) {
    res.status(400).json({ error: "该原料仍被酒品配方使用，不能直接删除" });
    return;
  }
  await prisma.ingredient.delete({ where: { id } });
  broadcastRealtime("inventory:updated", { ingredientId: id });
  broadcastRealtime("drinks:updated", { reason: "inventory" });
  res.status(204).send();
}
