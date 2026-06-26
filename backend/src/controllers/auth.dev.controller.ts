import { PrismaClient } from '@prisma/client';
import { signToken } from '../utils/jwt';
import { config } from '../config';
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

function selectUser(user: {
  id: string;
  nickname: string;
  avatarUrl: string | null;
  role: string;
  phone: string | null;
  wechatOpenId: string | null;
  wechatName: string | null;
  backgroundUrl?: string | null;
  signature?: string | null;
  createdAt?: Date;
}) {
  return {
    id: user.id,
    nickname: user.nickname,
    avatarUrl: user.avatarUrl,
    role: user.role,
    phone: user.phone,
    wechatOpenId: user.wechatOpenId,
    wechatName: user.wechatName,
    backgroundUrl: user.backgroundUrl,
    signature: user.signature,
    createdAt: user.createdAt,
  };
}

async function nextNickname() {
  const count = await prisma.user.count();
  return `Drunkard_${String(count + 1).padStart(3, '0')}`;
}

function isPhone(value: unknown): value is string {
  return typeof value === 'string' && /^\d{11}$/.test(value);
}

async function respondWithSession(res: Response, user: any) {
  const token = signToken({ userId: user.id, role: user.role });
  res.json({ token, user: selectUser(user) });
}

export async function devLogin(req: Request, res: Response): Promise<void> {
  if (!config.isDev) {
    res.status(404).json({ error: 'Not found' });
    return;
  }

  const { nickname, role } = req.body;
  const safeNickname =
    typeof nickname === 'string' && nickname.trim().length > 0
      ? nickname.trim()
      : '测试用户';
  const openId = `dev_${safeNickname.toLowerCase()}`;
  const phone = role === 'ADMIN' ? config.admin.phone : '18800000000';

  const user = await prisma.user.upsert({
    where: { phone },
    update: {
      nickname: safeNickname,
      role: role === 'ADMIN' ? 'ADMIN' : 'GUEST',
      wechatOpenId: openId,
      passwordHash: await bcrypt.hash(role === 'ADMIN' ? config.admin.password : 'drunkard', 10),
    },
    create: {
      phone,
      passwordHash: await bcrypt.hash(role === 'ADMIN' ? config.admin.password : 'drunkard', 10),
      wechatOpenId: openId,
      nickname: safeNickname,
      role: role === 'ADMIN' ? 'ADMIN' : 'GUEST',
    },
  });

  await respondWithSession(res, user);
}

export async function register(req: Request, res: Response): Promise<void> {
  const { phone, nickname, inviteCode, password, confirmPassword } = req.body;
  const normalizedNickname =
    typeof nickname === 'string' ? nickname.trim() : '';

  if (!isPhone(phone)) {
    res.status(400).json({ error: '手机号必须是 11 位数字' });
    return;
  }
  if (normalizedNickname.length < 1 || normalizedNickname.length > 16) {
    res.status(400).json({ error: '顾客名需填写 1 到 16 个字' });
    return;
  }
  if (inviteCode !== config.inviteCode) {
    res.status(400).json({ error: '邀请码不正确' });
    return;
  }
  if (typeof password !== 'string' || password.length < 6) {
    res.status(400).json({ error: '密码至少 6 位' });
    return;
  }
  if (password !== confirmPassword) {
    res.status(400).json({ error: '两次密码不一致' });
    return;
  }

  const existing = await prisma.user.findUnique({ where: { phone } });
  if (existing) {
    if (!existing.passwordHash && existing.wechatOpenId) {
      res.status(409).json({
        error: '该手机号已通过微信绑定，请用微信快捷登录或联系管理员修改密码',
      });
      return;
    }
    res.status(409).json({ error: '手机号已注册，请直接登录' });
    return;
  }

  const user = await prisma.user.create({
    data: {
      phone,
      passwordHash: await bcrypt.hash(password, 10),
      nickname: phone === config.admin.phone ? '调酒师' : normalizedNickname,
      role: phone === config.admin.phone ? 'ADMIN' : 'GUEST',
    },
  });

  res.status(201);
  await respondWithSession(res, user);
}

export async function passwordLogin(req: Request, res: Response): Promise<void> {
  const { phone, password } = req.body;
  if (!isPhone(phone) || typeof password !== 'string') {
    res.status(400).json({ error: '请输入正确的手机号和密码' });
    return;
  }

  let user = await prisma.user.findUnique({ where: { phone } });
  if (!user && phone === config.admin.phone && password === config.admin.password) {
    user = await prisma.user.create({
      data: {
        phone: config.admin.phone,
        passwordHash: await bcrypt.hash(config.admin.password, 10),
        nickname: '调酒师',
        role: 'ADMIN',
        wechatOpenId: 'dev_admin',
      },
    });
  }

  if (user && !user.passwordHash && user.wechatOpenId) {
    res.status(401).json({
      error: '该手机号已通过微信绑定，请用微信快捷登录或联系管理员修改密码',
    });
    return;
  }

  if (!user?.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) {
    res.status(401).json({ error: '手机号或密码错误' });
    return;
  }

  await respondWithSession(res, user);
}

export async function updateMe(req: Request, res: Response): Promise<void> {
  const { nickname, password, confirmPassword, wechatName, avatarUrl, backgroundUrl, signature } =
    req.body;
  const current = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!current) {
    res.status(404).json({ error: '用户不存在' });
    return;
  }

  if (password !== undefined) {
    if (typeof password !== 'string' || password.length < 6) {
      res.status(400).json({ error: '新密码至少 6 位' });
      return;
    }
    if (password !== confirmPassword) {
      res.status(400).json({ error: '两次密码不一致' });
      return;
    }
  }

  const data: any = {};
  if (typeof nickname === 'string' && nickname.trim().length > 0) {
    data.nickname = nickname.trim();
  }
  if (typeof password === 'string' && password.length >= 6) {
    data.passwordHash = await bcrypt.hash(password, 10);
  }
  if (!current.wechatOpenId && typeof wechatName === 'string' && wechatName.trim().length > 0) {
    data.wechatName = wechatName.trim();
  }
  if (avatarUrl === null || typeof avatarUrl === 'string') {
    data.avatarUrl = typeof avatarUrl === 'string' && avatarUrl.trim().length > 0
      ? avatarUrl.trim()
      : null;
  }
  if (backgroundUrl === null || typeof backgroundUrl === 'string') {
    data.backgroundUrl = typeof backgroundUrl === 'string' && backgroundUrl.trim().length > 0
      ? backgroundUrl.trim()
      : null;
  }
  if (signature === null || typeof signature === 'string') {
    data.signature = typeof signature === 'string' && signature.trim().length > 0
      ? signature.trim()
      : null;
  }

  const user = await prisma.user.update({
    where: { id: current.id },
    data,
  });
  res.json(selectUser(user));
}

export async function bindPhone(req: Request, res: Response): Promise<void> {
  const { phone } = req.body;
  if (!isPhone(phone)) {
    res.status(400).json({ error: '手机号必须是 11 位数字' });
    return;
  }

  const current = await prisma.user.findUnique({
    where: { id: req.user!.userId },
  });
  if (!current) {
    res.status(404).json({ error: '用户不存在' });
    return;
  }
  if (current.phone) {
    res.status(400).json({ error: '当前账号已绑定手机号' });
    return;
  }
  if (!current.wechatOpenId) {
    res.status(400).json({ error: '请先通过微信快捷登录后再绑定手机号' });
    return;
  }

  const existing = await prisma.user.findUnique({ where: { phone } });
  if (!existing) {
    const user = await prisma.user.update({
      where: { id: current.id },
      data: { phone },
    });
    await respondWithSession(res, user);
    return;
  }

  if (existing.id === current.id) {
    await respondWithSession(res, existing);
    return;
  }

  if (existing.wechatOpenId && existing.wechatOpenId !== current.wechatOpenId) {
    res.status(409).json({ error: '该手机号已绑定其他微信账号' });
    return;
  }

  const merged = await prisma.$transaction(async (tx) => {
    const [existingFavorites, currentFavorites, existingLikes, currentLikes] =
      await Promise.all([
        tx.favorite.findMany({ where: { userId: existing.id }, select: { drinkId: true } }),
        tx.favorite.findMany({ where: { userId: current.id }, select: { drinkId: true } }),
        tx.communityPostLike.findMany({ where: { userId: existing.id }, select: { postId: true } }),
        tx.communityPostLike.findMany({ where: { userId: current.id }, select: { postId: true } }),
      ]);
    const existingFavoriteDrinkIds = new Set(existingFavorites.map((item) => item.drinkId));
    const duplicateFavoriteDrinkIds = currentFavorites
      .map((item) => item.drinkId)
      .filter((drinkId) => existingFavoriteDrinkIds.has(drinkId));
    const existingLikedPostIds = new Set(existingLikes.map((item) => item.postId));
    const duplicateLikedPostIds = currentLikes
      .map((item) => item.postId)
      .filter((postId) => existingLikedPostIds.has(postId));

    const updated = await tx.user.update({
      where: { id: existing.id },
      data: {
        wechatOpenId: current.wechatOpenId,
        wechatUnionId: current.wechatUnionId ?? existing.wechatUnionId,
        wechatName: current.wechatName ?? existing.wechatName,
        avatarUrl: existing.avatarUrl ?? current.avatarUrl,
        backgroundUrl: existing.backgroundUrl ?? current.backgroundUrl,
        signature: existing.signature ?? current.signature,
      },
    });

    if (duplicateFavoriteDrinkIds.length > 0) {
      await tx.favorite.deleteMany({
        where: { userId: current.id, drinkId: { in: duplicateFavoriteDrinkIds } },
      });
    }
    if (duplicateLikedPostIds.length > 0) {
      await tx.communityPostLike.deleteMany({
        where: { userId: current.id, postId: { in: duplicateLikedPostIds } },
      });
    }
    await tx.favorite.updateMany({
      where: { userId: current.id },
      data: { userId: existing.id },
    });
    await tx.order.updateMany({
      where: { userId: current.id },
      data: { userId: existing.id },
    });
    await tx.review.updateMany({
      where: { userId: current.id },
      data: { userId: existing.id },
    });
    await tx.communityPost.updateMany({
      where: { userId: current.id },
      data: { userId: existing.id },
    });
    await tx.communityPostLike.updateMany({
      where: { userId: current.id },
      data: { userId: existing.id },
    });
    await tx.user.delete({ where: { id: current.id } });

    return updated;
  });

  await respondWithSession(res, merged);
}

export async function getMe(req: Request, res: Response): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    select: {
      id: true,
      nickname: true,
      avatarUrl: true,
      backgroundUrl: true,
      signature: true,
      role: true,
      phone: true,
      wechatOpenId: true,
      wechatName: true,
      createdAt: true,
    },
  });

  if (!user) {
    res.status(404).json({ error: '用户不存在' });
    return;
  }
  res.json(user);
}

export async function getPublicProfile(req: Request<{ id: string }>, res: Response): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { id: req.params.id },
    select: {
      id: true,
      nickname: true,
      avatarUrl: true,
      backgroundUrl: true,
      signature: true,
      role: true,
      createdAt: true,
      _count: {
        select: {
          communityPosts: true,
          reviews: true,
          favorites: true,
        },
      },
    },
  });

  if (!user) {
    res.status(404).json({ error: '用户不存在' });
    return;
  }

  res.json({
    id: user.id,
    nickname: user.nickname,
    avatarUrl: user.avatarUrl,
    backgroundUrl: user.backgroundUrl,
    signature: user.signature,
    role: user.role,
    createdAt: user.createdAt,
    stats: {
      communityPosts: user._count.communityPosts,
      reviews: user._count.reviews,
      favorites: user._count.favorites,
    },
  });
}
