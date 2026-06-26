import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const adminPhone = process.env.ADMIN_PHONE || '18800000001';
  const adminPassword = process.env.ADMIN_PASSWORD || 'change_me_admin';
  const guestPhone = process.env.SEED_GUEST_PHONE || '18800000000';
  const guestPassword = process.env.SEED_GUEST_PASSWORD || 'drunkard';

  const adminHash = await bcrypt.hash(adminPassword, 10);
  const oldAdmin = await prisma.user.findFirst({
    where: { wechatOpenId: 'dev_admin' },
  });
  const admin = oldAdmin
    ? await prisma.user.update({
        where: { id: oldAdmin.id },
        data: {
          phone: oldAdmin.phone ?? adminPhone,
          passwordHash: adminHash,
          role: 'ADMIN',
          nickname: '调酒师',
        },
      })
    : await prisma.user.upsert({
        where: { phone: adminPhone },
        update: {
          passwordHash: adminHash,
          role: 'ADMIN',
          nickname: '调酒师',
          wechatOpenId: 'dev_admin',
        },
        create: {
          phone: adminPhone,
          passwordHash: adminHash,
          wechatOpenId: 'dev_admin',
          nickname: '调酒师',
          role: 'ADMIN',
        },
      });
  console.log('Admin user created:', admin.nickname);

  const guestHash = await bcrypt.hash(guestPassword, 10);
  const oldGuest = await prisma.user.findFirst({
    where: { wechatOpenId: 'dev_测试用户' },
  });
  const guest = oldGuest
    ? await prisma.user.update({
        where: { id: oldGuest.id },
        data: {
          phone: oldGuest.phone ?? guestPhone,
          passwordHash: guestHash,
          role: 'GUEST',
          nickname: oldGuest.nickname || '测试用户',
        },
      })
    : await prisma.user.upsert({
        where: { phone: guestPhone },
        update: {
          passwordHash: guestHash,
          role: 'GUEST',
          nickname: '测试用户',
          wechatOpenId: 'dev_测试用户',
        },
        create: {
          phone: guestPhone,
          passwordHash: guestHash,
          wechatOpenId: 'dev_测试用户',
          nickname: '测试用户',
          role: 'GUEST',
        },
      });
  if (oldGuest && oldGuest.id !== guest.id) {
    await prisma.order.updateMany({
      where: { userId: oldGuest.id },
      data: { userId: guest.id },
    });
    await prisma.review.updateMany({
      where: { userId: oldGuest.id },
      data: { userId: guest.id },
    });
    await prisma.favorite.updateMany({
      where: { userId: oldGuest.id },
      data: { userId: guest.id },
    });
    await prisma.communityPost.updateMany({
      where: { userId: oldGuest.id },
      data: { userId: guest.id },
    });
  }
  console.log('Guest user prepared:', guest.nickname);

  const ingredientSeeds = [
    { name: '伏特加', category: 'BASE_SPIRIT', inStock: true },
    { name: '金酒', category: 'BASE_SPIRIT', inStock: true },
    { name: '朗姆酒', category: 'BASE_SPIRIT', inStock: true },
    { name: '龙舌兰', category: 'BASE_SPIRIT', inStock: false },
    { name: '威士忌', category: 'BASE_SPIRIT', inStock: true },
    { name: '白兰地', category: 'BASE_SPIRIT', inStock: true },
    { name: '简易糖浆', category: 'SYRUP', inStock: true },
    { name: '蜂蜜糖浆', category: 'SYRUP', inStock: true },
    { name: '石榴糖浆', category: 'SYRUP', inStock: false },
    { name: '青柠汁', category: 'MIXER', inStock: true },
    { name: '柠檬汁', category: 'MIXER', inStock: true },
    { name: '苏打水', category: 'MIXER', inStock: true },
    { name: '汤力水', category: 'MIXER', inStock: true },
    { name: '安格斯苦精', category: 'MIXER', inStock: true },
    { name: '薄荷叶', category: 'MIXER', inStock: true },
  ] as const;

  const ingredientMap = new Map<string, string>();

  for (const ingredientSeed of ingredientSeeds) {
    const existing = await prisma.ingredient.findFirst({
      where: { name: ingredientSeed.name },
    });

    const ingredient = existing
      ? await prisma.ingredient.update({
          where: { id: existing.id },
          data: ingredientSeed,
        })
      : await prisma.ingredient.create({ data: ingredientSeed });

    ingredientMap.set(ingredient.name, ingredient.id);
  }

  console.log(`Prepared ${ingredientMap.size} ingredients`);

  await prisma.drinkCategory.upsert({
    where: { name: '经典鸡尾酒' },
    update: {},
    create: {
      name: '经典鸡尾酒',
      description: '经典与基础款调酒',
      sortOrder: 0,
    },
  });

  const drinkSeeds = [
    {
      name: '莫吉托',
      nameEn: 'Mojito',
      description: '清爽的古巴经典鸡尾酒，薄荷与青柠的完美融合',
      recipe:
        '1. 杯中放入8片薄荷叶和半个青柠切块\n2. 加入15ml简易糖浆，轻捣\n3. 加入60ml朗姆酒\n4. 加满冰块\n5. 倒入苏打水至满\n6. 轻搅，薄荷叶装饰',
      category: '经典鸡尾酒',
      abv: 10,
      sortOrder: 1,
      ingredients: [
        { name: '朗姆酒', amount: '60ml' },
        { name: '薄荷叶', amount: '8片' },
        { name: '青柠汁', amount: '20ml' },
        { name: '简易糖浆', amount: '15ml' },
        { name: '苏打水', amount: '适量' },
      ],
    },
    {
      name: '金汤力',
      nameEn: 'Gin & Tonic',
      description: '简约而不简单的英伦经典，杜松子的芬芳与汤力水的微苦',
      recipe:
        '1. 高球杯加满冰块\n2. 倒入60ml金酒\n3. 加入汤力水至满（约120ml）\n4. 轻搅两圈\n5. 柠檬片装饰',
      category: '经典鸡尾酒',
      abv: 12,
      sortOrder: 2,
      ingredients: [
        { name: '金酒', amount: '60ml' },
        { name: '汤力水', amount: '120ml' },
        { name: '柠檬汁', amount: '10ml', isOptional: true },
      ],
    },
  ] as const;

  const preparedDrinks: string[] = [];

  for (const drinkSeed of drinkSeeds) {
    const existing = await prisma.drink.findFirst({
      where: { name: drinkSeed.name },
    });

    const drink = existing
      ? await prisma.drink.update({
          where: { id: existing.id },
          data: {
            nameEn: drinkSeed.nameEn,
            description: drinkSeed.description,
            category: drinkSeed.category,
            abv: drinkSeed.abv,
            sortOrder: drinkSeed.sortOrder,
            isAvailable: true,
          },
        })
      : await prisma.drink.create({
          data: {
            name: drinkSeed.name,
            nameEn: drinkSeed.nameEn,
            description: drinkSeed.description,
            recipe: drinkSeed.recipe,
            category: drinkSeed.category,
            abv: drinkSeed.abv,
            sortOrder: drinkSeed.sortOrder,
            isAvailable: true,
          },
        });

    await prisma.drinkIngredient.deleteMany({
      where: { drinkId: drink.id },
    });

    await prisma.drinkIngredient.createMany({
      data: drinkSeed.ingredients.map((ingredient) => ({
        drinkId: drink.id,
        ingredientId: ingredientMap.get(ingredient.name)!,
        amount: ingredient.amount,
        isOptional: ingredient.isOptional ?? false,
      })),
    });

    preparedDrinks.push(drink.name);
  }

  console.log('Prepared drinks:', preparedDrinks.join(', '));
  console.log('Seed completed!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
