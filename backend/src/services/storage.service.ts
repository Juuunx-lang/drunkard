import sharp from 'sharp';
import path from 'path';
import fs from 'fs/promises';
import { config } from '../config';

export async function processAndSaveImage(
  tempPath: string,
  targetDir: string,
  filename: string
): Promise<{ url: string; thumbnailUrl: string }> {
  const outputDir = path.join(config.upload.dir, targetDir);
  await fs.mkdir(outputDir, { recursive: true });

  const baseName = path.parse(filename).name;
  const mainFile = `${baseName}.webp`;
  const thumbFile = `${baseName}_thumb.webp`;

  await sharp(tempPath)
    .resize(1200, null, { withoutEnlargement: true })
    .webp({ quality: 80 })
    .toFile(path.join(outputDir, mainFile));

  await sharp(tempPath)
    .resize(400, null, { withoutEnlargement: true })
    .webp({ quality: 70 })
    .toFile(path.join(outputDir, thumbFile));

  await fs.unlink(tempPath);

  return {
    url: `/uploads/${targetDir}/${mainFile}`,
    thumbnailUrl: `/uploads/${targetDir}/${thumbFile}`,
  };
}
