import { PrismaClient } from '@prisma/client';
import { Request, Response } from 'express';
import { processAndSaveImage } from '../services/storage.service';

const prisma = new PrismaClient();

export async function listReviews(req: Request<{ drinkId: string }>, res: Response): Promise<void> {
  const { drinkId } = req.params;
  const reviews = await prisma.review.findMany({
    where: { drinkId },
    orderBy: { createdAt: 'desc' },
    include: {
      user: {
        select: {
          id: true,
          nickname: true,
          avatarUrl: true,
          backgroundUrl: true,
          signature: true,
          role: true,
        },
      },
      photos: { orderBy: { sortOrder: 'asc' } },
    },
  });

  res.json(reviews.map((r) => ({
    id: r.id,
    content: r.content,
    rating: r.rating,
    user: r.user,
    photos: r.photos.map((p) => p.url),
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  })));
}

export async function createReview(req: Request<{ drinkId: string }>, res: Response): Promise<void> {
  const { drinkId } = req.params;
  const { content, rating, photoUrls, orderItemId } = req.body;
  const normalizedContent = typeof content === 'string' ? content.trim() : '';
  const normalizedRating = rating == null || rating === '' ? null : parseInt(rating, 10);

  if (!normalizedContent) {
    res.status(400).json({ error: '评价内容不能为空' });
    return;
  }
  if (normalizedRating != null && (!Number.isInteger(normalizedRating) || normalizedRating < 1 || normalizedRating > 5)) {
    res.status(400).json({ error: '评分必须是 1 到 5 分' });
    return;
  }

  if (!orderItemId) {
    res.status(400).json({ error: '缺少订单项信息，无法提交评价' });
    return;
  }

  const orderItem = await prisma.orderItem.findUnique({
    where: { id: orderItemId },
    include: {
      order: true,
      reviews: {
        where: { userId: req.user!.userId },
        take: 1,
      },
    },
  });

  if (!orderItem || orderItem.drinkId !== drinkId) {
    res.status(404).json({ error: '订单项不存在' });
    return;
  }

  if (orderItem.order.userId !== req.user!.userId) {
    res.status(403).json({ error: '无权评价此订单' });
    return;
  }

  if (orderItem.order.status !== 'DELIVERED') {
    res.status(400).json({ error: '订单完成后才能评价' });
    return;
  }

  if (orderItem.reviews.length > 0) {
    res.status(409).json({ error: '该订单已评价' });
    return;
  }

  const review = await prisma.review.create({
    data: {
      userId: req.user!.userId,
      drinkId,
      orderItemId,
      content: normalizedContent,
      rating: normalizedRating,
      photos: photoUrls?.length
        ? { create: photoUrls.map((url: string, i: number) => ({ url, sortOrder: i })) }
        : undefined,
    },
    include: {
      user: {
        select: {
          id: true,
          nickname: true,
          avatarUrl: true,
          backgroundUrl: true,
          signature: true,
          role: true,
        },
      },
      photos: { orderBy: { sortOrder: 'asc' } },
    },
  });

  res.status(201).json({
    id: review.id,
    content: review.content,
    rating: review.rating,
    user: review.user,
    photos: review.photos.map((photo) => photo.url),
    createdAt: review.createdAt,
    updatedAt: review.updatedAt,
  });
}

export async function updateReview(req: Request<{ id: string }>, res: Response): Promise<void> {
  const { id } = req.params;
  const { content, rating } = req.body;
  const normalizedContent = typeof content === 'string' ? content.trim() : '';
  const normalizedRating = rating == null || rating === '' ? null : parseInt(rating, 10);

  if (!normalizedContent) {
    res.status(400).json({ error: '评价内容不能为空' });
    return;
  }
  if (normalizedRating != null && (!Number.isInteger(normalizedRating) || normalizedRating < 1 || normalizedRating > 5)) {
    res.status(400).json({ error: '评分必须是 1 到 5 分' });
    return;
  }

  const review = await prisma.review.findUnique({ where: { id } });
  if (!review) {
    res.status(404).json({ error: '评价不存在' });
    return;
  }

  const isAdmin = req.user?.role === 'ADMIN';
  if (!isAdmin && review.userId !== req.user!.userId) {
    res.status(403).json({ error: '无权编辑此评价' });
    return;
  }

  const updated = await prisma.review.update({
    where: { id },
    data: { content: normalizedContent, rating: normalizedRating },
  });
  res.json(updated);
}

export async function deleteReview(req: Request<{ id: string }>, res: Response): Promise<void> {
  const { id } = req.params;
  const review = await prisma.review.findUnique({ where: { id } });
  if (!review) {
    res.status(404).json({ error: '评价不存在' });
    return;
  }

  const isAdmin = req.user?.role === 'ADMIN';
  if (!isAdmin && review.userId !== req.user!.userId) {
    res.status(403).json({ error: '无权删除此评价' });
    return;
  }

  await prisma.review.delete({ where: { id } });
  res.status(204).send();
}

export async function uploadReviewPhotos(req: Request, res: Response): Promise<void> {
  const files = Array.isArray(req.files) ? req.files : [];

  if (!files.length) {
    res.status(400).json({ error: '请至少上传一张图片' });
    return;
  }

  const uploaded = await Promise.all(
    files.map(async (file) => {
      const saved = await processAndSaveImage(file.path, 'reviews', file.filename);
      return saved.url;
    })
  );

  res.status(201).json({ photoUrls: uploaded });
}
