import { PrismaClient } from '@prisma/client';
import { signToken } from '../utils/jwt';
import {
  getWechatAccessToken,
  getWechatUserInfo,
  getWechatH5AuthUrl,
  isWechatConfigured,
} from '../utils/wechat';
import { config } from '../config';
import { Request, Response } from 'express';

const prisma = new PrismaClient();

async function nextNickname() {
  const count = await prisma.user.count();
  return `Drunkard_${String(count + 1).padStart(3, '0')}`;
}

function serializeUser(user: any) {
  return {
    id: user.id,
    nickname: user.nickname,
    avatarUrl: user.avatarUrl,
    backgroundUrl: user.backgroundUrl,
    signature: user.signature,
    role: user.role,
    phone: user.phone,
    wechatOpenId: user.wechatOpenId,
    wechatName: user.wechatName,
  };
}

function cleanWechatValue(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim();
  if (!normalized || normalized.toLowerCase() === 'null') return undefined;
  return normalized;
}

async function upsertWechatUser(openid: string, unionid: string | undefined, userInfo: any, phone?: string) {
  const safePhone = typeof phone === 'string' && /^\d{11}$/.test(phone) ? phone : undefined;
  const safeUnionId = cleanWechatValue(unionid || userInfo.unionid);
  const safeWechatName = cleanWechatValue(userInfo.nickname);
  const safeAvatarUrl = cleanWechatValue(userInfo.headimgurl);
  const existing = await prisma.user.findFirst({
    where: {
      OR: [
        { wechatOpenId: openid },
        ...(safeUnionId ? [{ wechatUnionId: safeUnionId }] : []),
        ...(safePhone ? [{ phone: safePhone }] : []),
      ],
    },
  });

  if (existing) {
    return prisma.user.update({
      where: { id: existing.id },
      data: {
        wechatOpenId: openid,
        wechatUnionId: safeUnionId,
        wechatName: safeWechatName || existing.wechatName,
        avatarUrl: safeAvatarUrl || existing.avatarUrl,
        phone: existing.phone ?? safePhone,
      },
    });
  }

  return prisma.user.create({
    data: {
      phone: safePhone,
      wechatOpenId: openid,
      wechatUnionId: safeUnionId,
      wechatName: safeWechatName,
      nickname: await nextNickname(),
      avatarUrl: safeAvatarUrl,
    },
  });
}

export async function wechatRedirect(req: Request, res: Response): Promise<void> {
  const frontendUrl = req.query.redirect as string || config.frontendUrl;
  if (!isWechatConfigured()) {
    res.status(503).send(`
      <!doctype html>
      <html lang="zh-CN">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>微信快捷登录暂不可用</title>
          <style>
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              background: radial-gradient(circle at top, #34204a, #0d0d0d 62%);
              color: #f8f1ff;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            .card {
              width: min(88vw, 420px);
              padding: 28px;
              border: 1px solid rgba(255,255,255,.14);
              border-radius: 24px;
              background: rgba(20,20,30,.72);
              box-shadow: 0 24px 80px rgba(0,0,0,.36);
              text-align: center;
            }
            h1 { margin: 0 0 12px; font-size: 24px; }
            p { margin: 0 0 20px; color: rgba(248,241,255,.72); line-height: 1.7; }
            a {
              display: inline-flex;
              padding: 12px 18px;
              border-radius: 999px;
              color: #0d0d0d;
              background: linear-gradient(135deg, #ff5cc8, #ffd166);
              text-decoration: none;
              font-weight: 800;
            }
          </style>
        </head>
        <body>
          <main class="card">
            <h1>微信快捷登录暂不可用</h1>
            <p>当前服务器还没有配置真实的微信公众号 AppID / AppSecret，所以不能发起微信授权。请先返回使用账号密码登录。</p>
            <a href="${frontendUrl}/#/login">返回登录页</a>
          </main>
        </body>
      </html>
    `);
    return;
  }
  const callbackUrl = `${config.serverUrl}/api/auth/wechat/callback`;
  const state = Buffer.from(frontendUrl).toString('base64url');
  const authUrl = getWechatH5AuthUrl(callbackUrl, state);
  res.redirect(authUrl);
}

export async function wechatCallback(req: Request, res: Response): Promise<void> {
  const { code, state } = req.query;
  if (!code) {
    res.status(400).json({ error: '缺少微信授权码' });
    return;
  }
  if (!isWechatConfigured()) {
    res.status(503).json({ error: '微信快捷登录暂未配置，请使用账号密码登录' });
    return;
  }

  try {
    const tokenRes = await getWechatAccessToken(code as string);
    if (tokenRes.errcode) {
      res.status(400).json({ error: '微信授权失败', detail: tokenRes.errmsg });
      return;
    }

    const userInfo = await getWechatUserInfo(tokenRes.access_token, tokenRes.openid);

    const user = await upsertWechatUser(tokenRes.openid, tokenRes.unionid, userInfo);

    const token = signToken({ userId: user.id, role: user.role });

    const frontendUrl = state
      ? Buffer.from(state as string, 'base64url').toString()
      : config.frontendUrl;

    res.redirect(`${frontendUrl}/#/auth-callback?token=${token}`);
  } catch (err) {
    console.error('WeChat login error:', err);
    res.status(500).json({ error: '登录失败' });
  }
}

export async function wechatLogin(req: Request, res: Response): Promise<void> {
  const { code } = req.body;
  if (!code) {
    res.status(400).json({ error: '缺少微信授权码' });
    return;
  }
  if (!isWechatConfigured()) {
    res.status(503).json({ error: '微信快捷登录暂未配置，请使用账号密码登录' });
    return;
  }

  try {
    const tokenRes = await getWechatAccessToken(code);
    if (tokenRes.errcode) {
      res.status(400).json({ error: '微信授权失败', detail: tokenRes.errmsg });
      return;
    }

    const userInfo = await getWechatUserInfo(tokenRes.access_token, tokenRes.openid);

    const user = await upsertWechatUser(tokenRes.openid, tokenRes.unionid, userInfo, req.body.phone);

    const token = signToken({ userId: user.id, role: user.role });
    res.json({ token, user: serializeUser(user) });
  } catch (err) {
    console.error('WeChat login error:', err);
    res.status(500).json({ error: '登录失败' });
  }
}
