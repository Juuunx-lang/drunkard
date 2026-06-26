import { Router } from 'express';
import { listIngredients, createIngredient, updateIngredient, toggleStock, deleteIngredient } from '../controllers/inventory.controller';
import { authMiddleware, adminMiddleware } from '../middleware/auth';

const router = Router();

router.get('/', authMiddleware, listIngredients);
router.post('/', authMiddleware, adminMiddleware, createIngredient);
router.put('/:id', authMiddleware, adminMiddleware, updateIngredient);
router.patch('/:id/stock', authMiddleware, adminMiddleware, toggleStock);
router.delete('/:id', authMiddleware, adminMiddleware, deleteIngredient);

export default router;
