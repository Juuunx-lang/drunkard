import { Router } from 'express';
import { listReviews, createReview, updateReview, deleteReview, uploadReviewPhotos } from '../controllers/reviews.controller';
import { authMiddleware } from '../middleware/auth';
import { upload } from '../middleware/upload';

const router = Router();

router.get('/drinks/:drinkId/reviews', authMiddleware, listReviews);
router.post('/drinks/:drinkId/reviews', authMiddleware, createReview);
router.post('/reviews/upload', authMiddleware, upload.array('photos', 9), uploadReviewPhotos);
router.put('/reviews/:id', authMiddleware, updateReview);
router.delete('/reviews/:id', authMiddleware, deleteReview);

export default router;
