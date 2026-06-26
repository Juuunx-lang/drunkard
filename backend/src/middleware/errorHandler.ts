import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';

export function errorHandler(err: Error, req: Request, res: Response, _next: NextFunction): void {
  console.error(`[Error] ${req.method} ${req.path}:`, err.message);
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2025') {
      res.status(404).json({ error: '记录不存在' });
      return;
    }
    if (err.code === 'P2002') {
      res.status(409).json({ error: '记录已存在或唯一字段重复' });
      return;
    }
    if (err.code === 'P2003') {
      res.status(400).json({ error: '记录存在关联数据，无法完成操作' });
      return;
    }
  }
  res.status(500).json({ error: '服务器内部错误' });
}
