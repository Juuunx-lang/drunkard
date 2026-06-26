import { PrismaClient } from '@prisma/client';
import { Request, Response } from 'express';

const prisma = new PrismaClient();

function serializeFavorite(favorite: any) {
  return {
    id: favorite.id,
    createdAt: favorite.createdAt,
    drink: favorite.drink,
  };
}

export async function listFavorites(req: Request, res: Response): Promise<void> {
  const favorites = await prisma.favorite.findMany({
    where: { userId: req.user!.userId },
    orderBy: { createdAt: 'desc' },
    include: { drink: true },
  });
  res.json(favorites.map(serializeFavorite));
}

export async function getFavoriteStatus(req: Request<{ drinkId: string }>, res: Response): Promise<void> {
  const favorite = await prisma.favorite.findUnique({
    where: {
      userId_drinkId: {
        userId: req.user!.userId,
        drinkId: req.params.drinkId,
      },
    },
  });
  res.json({ liked: Boolean(favorite) });
}

export async function addFavorite(req: Request<{ drinkId: string }>, res: Response): Promise<void> {
  const drink = await prisma.drink.findUnique({ where: { id: req.params.drinkId } });
  if (!drink) {
    res.status(404).json({ error: '酒品不存在' });
    return;
  }

  await prisma.favorite.upsert({
    where: {
      userId_drinkId: {
        userId: req.user!.userId,
        drinkId: req.params.drinkId,
      },
    },
    update: {},
    create: {
      userId: req.user!.userId,
      drinkId: req.params.drinkId,
    },
  });
  res.status(204).send();
}

export async function removeFavorite(req: Request<{ drinkId: string }>, res: Response): Promise<void> {
  await prisma.favorite.deleteMany({
    where: {
      userId: req.user!.userId,
      drinkId: req.params.drinkId,
    },
  });
  res.status(204).send();
}
