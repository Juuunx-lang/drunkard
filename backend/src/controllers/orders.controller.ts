import { PrismaClient } from "@prisma/client";
import { Request, Response } from "express";
import { broadcastOrderCreated, broadcastOrderUpdated } from "../realtime";

const prisma = new PrismaClient();

function toClientStatus(status: string): string {
  switch (status) {
    case "CONFIRMED":
      return "PENDING";
    case "READY":
      return "PREPARING";
    default:
      return status;
  }
}

function serializeOrder(order: any) {
  return {
    ...order,
    status: toClientStatus(order.status),
    items: (order.items ?? []).map((item: any) => ({
      ...item,
      review: item.reviews?.[0]
        ? {
            id: item.reviews[0].id,
            content: item.reviews[0].content,
            rating: item.reviews[0].rating,
            user: item.reviews[0].user,
            photos: item.reviews[0].photos.map((photo: any) => photo.url),
            createdAt: item.reviews[0].createdAt,
            updatedAt: item.reviews[0].updatedAt,
          }
        : null,
    })),
  };
}

export async function listOrders(req: Request, res: Response): Promise<void> {
  const isAdmin = req.user?.role === "ADMIN";
  const where = isAdmin ? {} : { userId: req.user!.userId };

  const orders = await prisma.order.findMany({
    where,
    orderBy: { createdAt: "desc" },
    include: {
      user: { select: { id: true, nickname: true, avatarUrl: true } },
      items: {
        include: {
          drink: { select: { id: true, name: true, photoUrl: true } },
          reviews: {
            take: 1,
            orderBy: { createdAt: "desc" },
            include: {
              user: {
                select: {
                  id: true,
                  nickname: true,
                  avatarUrl: true,
                  role: true,
                },
              },
              photos: { orderBy: { sortOrder: "asc" } },
            },
          },
        },
      },
    },
  });

  res.json(orders.map(serializeOrder));
}

export async function getOrder(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const order = await prisma.order.findUnique({
    where: { id },
    include: {
      user: { select: { id: true, nickname: true, avatarUrl: true } },
      items: {
        include: {
          drink: { select: { id: true, name: true, photoUrl: true } },
          reviews: {
            take: 1,
            orderBy: { createdAt: "desc" },
            include: {
              user: {
                select: {
                  id: true,
                  nickname: true,
                  avatarUrl: true,
                  role: true,
                },
              },
              photos: { orderBy: { sortOrder: "asc" } },
            },
          },
        },
      },
    },
  });

  if (!order) {
    res.status(404).json({ error: "订单不存在" });
    return;
  }

  const isAdmin = req.user?.role === "ADMIN";
  if (!isAdmin && order.userId !== req.user!.userId) {
    res.status(403).json({ error: "无权查看此订单" });
    return;
  }

  res.json(serializeOrder(order));
}

export async function createOrder(req: Request, res: Response): Promise<void> {
  const { items, notes } = req.body;
  if (!items?.length) {
    res.status(400).json({ error: "请至少选择一款酒" });
    return;
  }

  const requestedItems = items as Array<{
    drinkId: string;
    quantity?: number;
    notes?: string;
  }>;
  const drinkIds = [
    ...new Set(requestedItems.map((item) => item.drinkId).filter(Boolean)),
  ];
  const drinks = await prisma.drink.findMany({
    where: { id: { in: drinkIds } },
    include: { ingredients: { include: { ingredient: true } } },
  });
  const drinkMap = new Map(drinks.map((drink) => [drink.id, drink]));
  for (const item of requestedItems) {
    const drink = drinkMap.get(item.drinkId);
    if (!drink) {
      res.status(404).json({ error: "酒品不存在" });
      return;
    }
    if (!drink.isAvailable) {
      res.status(400).json({ error: `${drink.name} 当前不可点单` });
      return;
    }
  }

  const order = await prisma.order.create({
    data: {
      userId: req.user!.userId,
      notes,
      items: {
        create: requestedItems.map(
          (item: { drinkId: string; quantity?: number; notes?: string }) => ({
            drinkId: item.drinkId,
            quantity: item.quantity || 1,
            notes: item.notes,
          }),
        ),
      },
    },
    include: {
      user: { select: { id: true, nickname: true, avatarUrl: true } },
      items: {
        include: {
          drink: { select: { id: true, name: true, photoUrl: true } },
          reviews: {
            take: 1,
            orderBy: { createdAt: "desc" },
            include: {
              user: {
                select: {
                  id: true,
                  nickname: true,
                  avatarUrl: true,
                  role: true,
                },
              },
              photos: { orderBy: { sortOrder: "asc" } },
            },
          },
        },
      },
    },
  });

  const serialized = serializeOrder(order);
  broadcastOrderCreated(order.userId, order.id);
  res.status(201).json(serialized);
}

export async function updateOrderStatus(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const { status } = req.body;
  const validStatuses = ["PENDING", "PREPARING", "DELIVERED", "CANCELLED"];
  if (!validStatuses.includes(status)) {
    res.status(400).json({ error: "无效的订单状态" });
    return;
  }

  const existing = await prisma.order.findUnique({ where: { id } });
  if (!existing) {
    res.status(404).json({ error: "订单不存在" });
    return;
  }

  const allowedTransitions: Record<string, string[]> = {
    PENDING: ["PREPARING", "CANCELLED"],
    PREPARING: ["DELIVERED"],
    DELIVERED: [],
    CANCELLED: [],
  };

  if (!allowedTransitions[existing.status]?.includes(status)) {
    res.status(400).json({ error: "当前订单状态不支持此操作" });
    return;
  }

  const order = await prisma.order.update({
    where: { id },
    data: { status },
    include: {
      user: { select: { id: true, nickname: true, avatarUrl: true } },
      items: {
        include: {
          drink: { select: { id: true, name: true, photoUrl: true } },
          reviews: {
            take: 1,
            orderBy: { createdAt: "desc" },
            include: {
              user: {
                select: {
                  id: true,
                  nickname: true,
                  avatarUrl: true,
                  role: true,
                },
              },
              photos: { orderBy: { sortOrder: "asc" } },
            },
          },
        },
      },
    },
  });

  const serialized = serializeOrder(order);
  broadcastOrderUpdated(order.userId, order.id);
  res.json(serialized);
}

export async function cancelOrder(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const order = await prisma.order.findUnique({ where: { id } });
  if (!order) {
    res.status(404).json({ error: "订单不存在" });
    return;
  }
  const isAdmin = req.user?.role === "ADMIN";
  if (!isAdmin && order.userId !== req.user!.userId) {
    res.status(403).json({ error: "无权操作此订单" });
    return;
  }
  if (!["PENDING", "CONFIRMED"].includes(order.status)) {
    res.status(400).json({ error: "仅待接单订单可取消" });
    return;
  }
  await prisma.order.update({ where: { id }, data: { status: "CANCELLED" } });
  broadcastOrderUpdated(order.userId, id);
  res.status(204).send();
}

export async function deleteOrder(
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> {
  const { id } = req.params;
  const order = await prisma.order.findUnique({ where: { id } });
  if (!order) {
    res.status(404).json({ error: "订单不存在" });
    return;
  }
  await prisma.review.deleteMany({
    where: { orderItem: { orderId: id } },
  });
  await prisma.order.delete({ where: { id } });
  broadcastOrderUpdated(order.userId, id);
  res.status(204).send();
}
