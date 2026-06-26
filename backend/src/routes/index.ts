import { Router } from 'express';
import authRoutes from './auth.routes';
import drinksRoutes from './drinks.routes';
import inventoryRoutes from './inventory.routes';
import ordersRoutes from './orders.routes';
import reviewsRoutes from './reviews.routes';
import favoritesRoutes from './favorites.routes';
import communityRoutes from './community.routes';
import adminRoutes from './admin.routes';
import barRoutes from './bar.routes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/drinks', drinksRoutes);
router.use('/ingredients', inventoryRoutes);
router.use('/orders', ordersRoutes);
router.use('/favorites', favoritesRoutes);
router.use('/community', communityRoutes);
router.use('/admin', adminRoutes);
router.use('/bar', barRoutes);
router.use('/', reviewsRoutes);

export default router;
