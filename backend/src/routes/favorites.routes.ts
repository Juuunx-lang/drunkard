import { Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import { addFavorite, getFavoriteStatus, listFavorites, removeFavorite } from '../controllers/favorites.controller';

const router = Router();

router.get('/', authMiddleware, listFavorites);
router.get('/:drinkId', authMiddleware, getFavoriteStatus);
router.put('/:drinkId', authMiddleware, addFavorite);
router.delete('/:drinkId', authMiddleware, removeFavorite);

export default router;
