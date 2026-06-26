import { Router } from 'express';
import { wechatLogin, wechatRedirect, wechatCallback } from '../controllers/auth.controller';
import {
  devLogin,
  getMe,
  getPublicProfile,
  bindPhone,
  passwordLogin,
  register,
  updateMe,
} from '../controllers/auth.dev.controller';
import { authMiddleware } from '../middleware/auth';

const router = Router();

router.get('/wechat', wechatRedirect);
router.get('/wechat/callback', wechatCallback);
router.post('/wechat', wechatLogin);
router.post('/dev-login', devLogin);
router.post('/register', register);
router.post('/login', passwordLogin);
router.get('/profiles/:id', authMiddleware, getPublicProfile);
router.get('/me', authMiddleware, getMe);
router.patch('/me', authMiddleware, updateMe);
router.post('/bind-phone', authMiddleware, bindPhone);

export default router;
