import { CommunityCategory, PrismaClient } from '@prisma/client';
import { Request, Response } from 'express';
import { processAndSaveImage } from '../services/storage.service';

const prisma = new PrismaClient();
const categories = ['LIFE', 'BAR', 'OFFICIAL'];

function serializePost(post: any) {
  const likes = post.likes ?? [];
  const likedByMe = post.likedByMe ?? false;
  return {
    id: post.id,
    category: post.category,
    title: post.title,
    content: post.content,
    photos: (post.photos ?? []).map((photo: any) => photo.url),
    likeCount: typeof post._count?.likes === 'number' ? post._count.likes : likes.length,
    likedByMe,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    user: post.user,
  };
}

export async function listCommunityPosts(req: Request, res: Response): Promise<void> {
  const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  const category = typeof req.query.category === 'string' ? req.query.category : '';
  const mine = req.query.mine === 'true';
  const where: any = {};
  if (mine) {
    where.userId = req.user!.userId;
  }
  if (categories.includes(category)) {
    where.category = category === 'LIFE' ? { in: ['LIFE', 'SHARE'] } : category;
  }
  if (query) {
    where.OR = [
      { title: { contains: query, mode: 'insensitive' } },
      { user: { nickname: { contains: query, mode: 'insensitive' } } },
    ];
  }

  const posts = await prisma.communityPost.findMany({
    where,
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
      likes: { where: { userId: req.user!.userId }, select: { id: true } },
      _count: { select: { likes: true } },
    },
  });
  res.json(posts.map((post) => serializePost({ ...post, likedByMe: post.likes.length > 0 })));
}

export async function getCommunityPost(req: Request<{ id: string }>, res: Response): Promise<void> {
  const post = await prisma.communityPost.findUnique({
    where: { id: req.params.id },
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
      likes: { where: { userId: req.user!.userId }, select: { id: true } },
      _count: { select: { likes: true } },
    },
  });
  if (!post) {
    res.status(404).json({ error: '内容不存在' });
    return;
  }
  res.json(serializePost({ ...post, likedByMe: post.likes.length > 0 }));
}

export async function createCommunityPost(req: Request, res: Response): Promise<void> {
  const { category, title, content, photoUrls } = req.body;
  if (!categories.includes(category)) {
    res.status(400).json({ error: '请选择正确的栏目' });
    return;
  }
  if (category === 'OFFICIAL' && req.user?.role !== 'ADMIN') {
    res.status(403).json({ error: '只有管理员可以发布官方通知' });
    return;
  }
  if (typeof title !== 'string' || title.trim().length < 2) {
    res.status(400).json({ error: '标题至少 2 个字' });
    return;
  }
  if (typeof content !== 'string' || content.trim().length < 2) {
    res.status(400).json({ error: '内容至少 2 个字' });
    return;
  }

  const post = await prisma.communityPost.create({
    data: {
      userId: req.user!.userId,
      category: category as CommunityCategory,
      title: title.trim(),
      content: content.trim(),
      photos: Array.isArray(photoUrls) && photoUrls.length
        ? {
            create: photoUrls.slice(0, 3).map((url: string, index: number) => ({
              url,
              sortOrder: index,
            })),
          }
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
      likes: { where: { userId: req.user!.userId }, select: { id: true } },
      _count: { select: { likes: true } },
    },
  });
  res.status(201).json(serializePost(post));
}

export async function updateCommunityPost(req: Request<{ id: string }>, res: Response): Promise<void> {
  const { category, title, content, photoUrls } = req.body;
  const existing = await prisma.communityPost.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    res.status(404).json({ error: '内容不存在' });
    return;
  }
  if (existing.userId !== req.user!.userId) {
    res.status(403).json({ error: '只能修改自己发布的内容' });
    return;
  }
  if (!categories.includes(category)) {
    res.status(400).json({ error: '请选择正确的栏目' });
    return;
  }
  if (category === 'OFFICIAL' && req.user?.role !== 'ADMIN') {
    res.status(403).json({ error: '只有管理员可以发布官方通知' });
    return;
  }
  if (typeof title !== 'string' || title.trim().length < 2) {
    res.status(400).json({ error: '标题至少 2 个字' });
    return;
  }
  if (typeof content !== 'string' || content.trim().length < 2) {
    res.status(400).json({ error: '内容至少 2 个字' });
    return;
  }

  await prisma.communityPostPhoto.deleteMany({ where: { postId: existing.id } });
  const post = await prisma.communityPost.update({
    where: { id: existing.id },
    data: {
      category: category as CommunityCategory,
      title: title.trim(),
      content: content.trim(),
      photos: Array.isArray(photoUrls) && photoUrls.length
        ? {
            create: photoUrls.slice(0, 3).map((url: string, index: number) => ({
              url,
              sortOrder: index,
            })),
          }
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
      likes: { where: { userId: req.user!.userId }, select: { id: true } },
      _count: { select: { likes: true } },
    },
  });
  res.json(serializePost({ ...post, likedByMe: post.likes.length > 0 }));
}

export async function uploadCommunityPhotos(req: Request, res: Response): Promise<void> {
  const files = Array.isArray(req.files) ? req.files.slice(0, 3) : [];
  if (!files.length) {
    res.status(400).json({ error: '请至少上传一张图片' });
    return;
  }

  const uploaded = await Promise.all(
    files.map(async (file) => {
      const saved = await processAndSaveImage(file.path, 'community', file.filename);
      return saved.url;
    })
  );

  res.status(201).json({ photoUrls: uploaded });
}

export async function toggleCommunityLike(req: Request<{ id: string }>, res: Response): Promise<void> {
  const post = await prisma.communityPost.findUnique({ where: { id: req.params.id } });
  if (!post) {
    res.status(404).json({ error: '内容不存在' });
    return;
  }

  const existing = await prisma.communityPostLike.findUnique({
    where: {
      userId_postId: {
        userId: req.user!.userId,
        postId: req.params.id,
      },
    },
  });

  if (existing) {
    await prisma.communityPostLike.delete({ where: { id: existing.id } });
  } else {
    await prisma.communityPostLike.create({
      data: { userId: req.user!.userId, postId: req.params.id },
    });
  }

  const likeCount = await prisma.communityPostLike.count({ where: { postId: req.params.id } });
  res.json({ liked: !existing, likeCount });
}

export async function deleteCommunityPost(req: Request<{ id: string }>, res: Response): Promise<void> {
  const post = await prisma.communityPost.findUnique({ where: { id: req.params.id } });
  if (!post) {
    res.status(404).json({ error: '内容不存在' });
    return;
  }
  if (req.user?.role !== 'ADMIN' && post.userId !== req.user!.userId) {
    res.status(403).json({ error: '无权删除此内容' });
    return;
  }
  await prisma.communityPost.delete({ where: { id: post.id } });
  res.status(204).send();
}
