import { config } from '../config';

interface WechatTokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  openid: string;
  scope: string;
  unionid?: string;
  errcode?: number;
  errmsg?: string;
}

interface WechatUserInfo {
  openid: string;
  nickname: string;
  sex: number;
  province: string;
  city: string;
  country: string;
  headimgurl: string;
  unionid?: string;
}

export function getWechatH5AuthUrl(redirectUri: string, state: string): string {
  const encodedUri = encodeURIComponent(redirectUri);
  return `https://open.weixin.qq.com/connect/oauth2/authorize?appid=${config.wechat.appId}&redirect_uri=${encodedUri}&response_type=code&scope=snsapi_userinfo&state=${state}#wechat_redirect`;
}

export function isWechatConfigured(): boolean {
  const appId = config.wechat.appId.trim();
  const appSecret = config.wechat.appSecret.trim();
  return /^wx[a-fA-F0-9]{16}$/.test(appId) && appSecret.length >= 16;
}

export async function getWechatAccessToken(code: string): Promise<WechatTokenResponse> {
  const url = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=${config.wechat.appId}&secret=${config.wechat.appSecret}&code=${code}&grant_type=authorization_code`;
  const res = await fetch(url);
  return res.json() as Promise<WechatTokenResponse>;
}

export async function getWechatUserInfo(accessToken: string, openid: string): Promise<WechatUserInfo> {
  const url = `https://api.weixin.qq.com/sns/userinfo?access_token=${accessToken}&openid=${openid}&lang=zh_CN`;
  const res = await fetch(url);
  return res.json() as Promise<WechatUserInfo>;
}
