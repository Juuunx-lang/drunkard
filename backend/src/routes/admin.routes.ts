import { Router } from 'express';
import { adminMiddleware, authMiddleware } from '../middleware/auth';
import {
  createDatabaseRecord,
  databaseOverview,
  databaseTableRecords,
  databaseTables,
  deleteDatabaseRecord,
  listUsers,
  updateDatabaseRecord,
} from '../controllers/admin.controller';

const router = Router();

router.use(authMiddleware, adminMiddleware);
router.get('/users', listUsers);
router.get('/database', databaseOverview);
router.get('/database/tables', databaseTables);
router.get('/database/:table', databaseTableRecords);
router.post('/database/:table', createDatabaseRecord);
router.put('/database/:table/:id', updateDatabaseRecord);
router.delete('/database/:table/:id', deleteDatabaseRecord);

export default router;
