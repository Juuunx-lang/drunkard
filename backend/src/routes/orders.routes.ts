import { Router } from 'express';
import { listOrders, getOrder, createOrder, updateOrderStatus, cancelOrder, deleteOrder } from '../controllers/orders.controller';
import { authMiddleware, adminMiddleware } from '../middleware/auth';

const router = Router();

router.get('/', authMiddleware, listOrders);
router.get('/:id', authMiddleware, getOrder);
router.post('/', authMiddleware, createOrder);
router.patch('/:id/status', authMiddleware, adminMiddleware, updateOrderStatus);
router.delete('/:id', authMiddleware, cancelOrder);
router.delete('/:id/hard', authMiddleware, adminMiddleware, deleteOrder);

export default router;
