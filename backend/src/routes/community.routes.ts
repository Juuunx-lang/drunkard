import { Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import {
  createCommunityPost,
  deleteCommunityPost,
  getCommunityPost,
  listCommunityPosts,
  toggleCommunityLike,
  updateCommunityPost,
  uploadCommunityPhotos,
} from '../controllers/community.controller';
import { upload } from '../middleware/upload';

const router = Router();

router.get('/', authMiddleware, listCommunityPosts);
router.get('/:id', authMiddleware, getCommunityPost);
router.post('/', authMiddleware, createCommunityPost);
router.post('/upload/photos', authMiddleware, upload.array('photos', 3), uploadCommunityPhotos);
router.post('/:id/like', authMiddleware, toggleCommunityLike);
router.put('/:id', authMiddleware, updateCommunityPost);
router.delete('/:id', authMiddleware, deleteCommunityPost);

export default router;
