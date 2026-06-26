import { Router } from 'express';
import { getBarStatus, updateBarStatus } from '../controllers/bar.controller';
import { adminMiddleware, authMiddleware } from '../middleware/auth';

const router = Router();

router.get('/status', getBarStatus);
router.patch('/status', authMiddleware, adminMiddleware, updateBarStatus);

export default router;
