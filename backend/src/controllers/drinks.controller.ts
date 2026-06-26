import { PrismaClient } from "@prisma/client";
import { Request, Response } from "express";
import { processAndSaveImage } from "../services/storage.service";
import { broadcastRealtime } from "../realtime";

const prisma = new PrismaClient();

async function ensureDrinkCategory(category: unknown): Promise<string | null> {
  if (typeof category !== "string") return null;
  const name = category.trim();
  if (!name) return null;
  await prisma.drinkCategory.upsert({
    where: { name },
    update: {},
    create: { name },
  });
  return name;
}

export async function listDrinkCategories(
  _req: Request,
  res: Response,
): Promise<void> {
  const [managedCategories, legacyCategories] = await Promise.all([
    prisma.drinkCategory.findMany({
      orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
    }),
    prisma.drink.findMany({
      where: { category: { not: null } },
      distinct: ["category"],
      select: { category: true },
      orderBy: { category: "asc" },
    }),
  ]);
  const managedNames = new Set(
    managedCategories.map((category) => category.name),
  );
  const legacy = legacyCategories
    .map((item) => item.category?.trim())
    .filter((name): name is string => Boolean(name && !managedNames.has(name)));

  res.json([
    ...managedCategories.map((category) => ({
      id: category.id,
      name: category.name,
      description: category.description,
      sortOrder: category.sortOrder,
    })),
    ...legacy.map((name) => ({
      id: `legacy:${name}`,
      name,
      description: null,
      sortOrder: 999,
    })),
  ]);
}

export async function listDrinks(req: Request, res: Response): Promise<void> {
  const drinks = await prisma.drink.findMany({
    orderBy: { sortOrder: "asc" },
    include: { ingredients: { include: { ingredient: true } } },
  });

  const isAdmin = req.user?.role === "ADMIN";
  const result = drinks.map((d) => {
    const hasMissingRequiredIngredients = d.ingredients.some(
      (di) => !di.ingredient.inStock && !di.isOptional,
    );

    return {
      id: d.id,
      name: d.name,
      nameEn: d.nameEn,
      description: d.description,
      recipe: isAdmin ? d.recipe : undefined,
      photoUrl: d.photoUrl,
      category: d.category,
      abv: d.abv,
      isAvailable: d.isAvailable && !hasMissingRequiredIngredients,
      ingredients: d.ingredients.map((di) => ({
        id: di.ingredient.id,
        name: di.ingredient.name,
        category: di.ingredient.category,
        inStock: di.ingredient.inStock,
        amount: di.amount,
        isOptional: di.isOptional,
      })),
    };
  });

  res.json(result);
}

export async function getDrink(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const drink = await prisma.drink.findUnique({
    where: { id },
    include: {
      ingredients: { include: { ingredient: true } },
      reviews: {
        take: 3,
        orderBy: { createdAt: "desc" },
        include: {
          user: { select: { id: true, nickname: true, avatarUrl: true } },
          photos: true,
        },
      },
    },
  });

  if (!drink) {
    res.status(404).json({ error: "酒品不存在" });
    return;
  }

  const isAdmin = req.user?.role === "ADMIN";
  const missingIngredients = drink.ingredients
    .filter((di) => !di.ingredient.inStock && !di.isOptional)
    .map((di) => ({
      name: di.ingredient.name,
      category: di.ingredient.category,
    }));
  const hasMissingRequiredIngredients = missingIngredients.length > 0;

  res.json({
    id: drink.id,
    name: drink.name,
    nameEn: drink.nameEn,
    description: drink.description,
    recipe: isAdmin ? drink.recipe : undefined,
    photoUrl: drink.photoUrl,
    category: drink.category,
    abv: drink.abv,
    isAvailable: drink.isAvailable && !hasMissingRequiredIngredients,
    missingIngredients,
    ingredients: drink.ingredients.map((di) => ({
      id: di.ingredient.id,
      name: di.ingredient.name,
      category: di.ingredient.category,
      inStock: di.ingredient.inStock,
      amount: di.amount,
      isOptional: di.isOptional,
    })),
    reviews: drink.reviews.map((r) => ({
      id: r.id,
      content: r.content,
      rating: r.rating,
      user: r.user,
      photos: r.photos.map((p) => p.url),
      createdAt: r.createdAt,
    })),
  });
}

export async function createDrink(req: Request, res: Response): Promise<void> {
  const {
    name,
    nameEn,
    description,
    recipe,
    category,
    abv,
    photoUrl,
    isAvailable,
    sortOrder,
    ingredientIds,
  } = req.body;
  const normalizedCategory = await ensureDrinkCategory(category);
  const drink = await prisma.drink.create({
    data: {
      name,
      nameEn,
      description,
      recipe,
      category: normalizedCategory,
      abv: abv ? parseFloat(abv) : null,
      photoUrl,
      isAvailable: isAvailable ?? true,
      sortOrder: sortOrder ?? 0,
      ingredients: ingredientIds?.length
        ? {
            create: ingredientIds.map(
              (item: {
                id: string;
                amount?: string;
                isOptional?: boolean;
              }) => ({
                ingredientId: item.id,
                amount: item.amount,
                isOptional: item.isOptional || false,
              }),
            ),
          }
        : undefined,
    },
  });
  broadcastRealtime("drinks:updated", { drinkId: drink.id });
  res.status(201).json(drink);
}

export async function updateDrink(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const {
    name,
    nameEn,
    description,
    recipe,
    category,
    abv,
    photoUrl,
    isAvailable,
    sortOrder,
    ingredientIds,
  } = req.body;
  const normalizedCategory =
    category === null ? null : await ensureDrinkCategory(category);
  const drink = await prisma.drink.update({
    where: { id },
    data: {
      name,
      nameEn,
      description,
      recipe,
      category: normalizedCategory,
      abv: abv == null || abv == "" ? null : parseFloat(abv),
      photoUrl,
      isAvailable,
      sortOrder,
      ingredients: ingredientIds
        ? {
            deleteMany: {},
            create: ingredientIds.map(
              (item: {
                id: string;
                amount?: string;
                isOptional?: boolean;
              }) => ({
                ingredientId: item.id,
                amount: item.amount,
                isOptional: item.isOptional || false,
              }),
            ),
          }
        : undefined,
    },
    include: {
      ingredients: { include: { ingredient: true } },
    },
  });
  broadcastRealtime("drinks:updated", { drinkId: drink.id });
  res.json(drink);
}

export async function deleteDrink(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const orderItemCount = await prisma.orderItem.count({
    where: { drinkId: id },
  });
  if (orderItemCount > 0) {
    res
      .status(400)
      .json({
        error: "该酒品已有历史订单，不能直接删除；建议下架或改为不可点单",
      });
    return;
  }
  await prisma.drink.delete({ where: { id } });
  broadcastRealtime("drinks:updated", { drinkId: id });
  res.status(204).send();
}

export async function uploadDrinkPhoto(
  req: Request,
  res: Response,
): Promise<void> {
  if (!req.file) {
    res.status(400).json({ error: "请上传酒品图片" });
    return;
  }

  const saved = await processAndSaveImage(
    req.file.path,
    "drinks",
    req.file.filename,
  );
  res
    .status(201)
    .json({ photoUrl: saved.url, thumbnailUrl: saved.thumbnailUrl });
}
