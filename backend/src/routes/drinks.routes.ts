import { Router } from 'express';
import {
  listDrinks,
  getDrink,
  createDrink,
  updateDrink,
  deleteDrink,
  uploadDrinkPhoto,
  listDrinkCategories,
} from '../controllers/drinks.controller';
import { authMiddleware, adminMiddleware, optionalAuthMiddleware } from '../middleware/auth';
import { upload } from '../middleware/upload';

const router = Router();

router.get('/', optionalAuthMiddleware, listDrinks);
router.get('/categories', optionalAuthMiddleware, listDrinkCategories);
router.post('/upload/photo', authMiddleware, adminMiddleware, upload.single('photo'), uploadDrinkPhoto);
router.get('/:id', optionalAuthMiddleware, getDrink);
router.post('/', authMiddleware, adminMiddleware, createDrink);
router.put('/:id', authMiddleware, adminMiddleware, updateDrink);
router.delete('/:id', authMiddleware, adminMiddleware, deleteDrink);

export default router;
