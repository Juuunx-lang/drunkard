import { PrismaClient } from '@prisma/client';
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();
const editableTables = [
  'users',
  'drinks',
  'drinkCategories',
  'ingredients',
  'orders',
  'reviews',
  'favorites',
  'communityPosts',
] as const;

type EditableTable = (typeof editableTables)[number];
type FieldType = 'text' | 'textarea' | 'number' | 'boolean' | 'select' | 'multiselect' | 'password';

type AdminField = {
  key: string;
  label: string;
  type: FieldType;
  required?: boolean;
  editable?: boolean;
  creatable?: boolean;
  options?: Array<{ value: string; label: string }>;
};

const tableLabels: Record<EditableTable, { label: string; description: string }> = {
  users: { label: '用户账号', description: '管理手机号、昵称、角色和微信展示名' },
  drinks: { label: '酒品酒单', description: '管理酒名、简介、分类、酒精度和上下架' },
  drinkCategories: { label: '酒类分类', description: '增删改酒类分类，并选择分类下包含哪些酒品' },
  ingredients: { label: '备货原料', description: '管理原料名称、类别、库存状态和备注' },
  orders: { label: '订单记录', description: '查看或维护顾客订单状态与备注' },
  reviews: { label: '酒品评论', description: '维护顾客评论、评分和关联酒品' },
  favorites: { label: '喜欢记录', description: '维护用户收藏的酒品关系' },
  communityPosts: { label: '社区内容', description: '管理生活、本店和官方社区帖子' },
};

const orderStatusOptions = [
  { value: 'PENDING', label: '待接单' },
  { value: 'PREPARING', label: '制作中' },
  { value: 'DELIVERED', label: '已完成' },
  { value: 'CANCELLED', label: '已取消' },
];

const roleOptions = [
  { value: 'GUEST', label: '顾客' },
  { value: 'ADMIN', label: '管理员' },
];

const ingredientCategoryOptions = [
  { value: 'BASE_SPIRIT', label: '基酒' },
  { value: 'SYRUP', label: '糖浆/风味' },
  { value: 'MIXER', label: '调和饮料' },
];

const communityCategoryOptions = [
  { value: 'BAR', label: '本店' },
  { value: 'OFFICIAL', label: '官方' },
  { value: 'LIFE', label: '生活' },
];

function ensureTable(table: string): EditableTable {
  if (!editableTables.includes(table as EditableTable)) {
    throw new Error('不支持的数据表');
  }
  return table as EditableTable;
}

function paramValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return value ?? '';
}

function formatDate(value?: Date | string | null): string {
  if (!value) return '-';
  return new Date(value).toLocaleString('zh-CN', { hour12: false });
}

function optionLabel(
  options: Array<{ value: string; label: string }>,
  value?: string | null,
): string {
  return options.find((option) => option.value === value)?.label ?? value ?? '-';
}

function textValue(value: unknown): string | undefined {
  if (value === undefined) return undefined;
  const text = String(value).trim();
  return text.length === 0 ? undefined : text;
}

function nullableTextValue(value: unknown): string | null | undefined {
  if (value === undefined) return undefined;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function numberValue(value: unknown): number | null | undefined {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    throw new Error('数字格式不正确');
  }
  return parsed;
}

function booleanValue(value: unknown): boolean | undefined {
  if (value === undefined) return undefined;
  return value === true || value === 'true';
}

function multiStringValue(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).trim()).filter(Boolean);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    return value.split(',').map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

async function drinkCategoryOptions(): Promise<Array<{ value: string; label: string }>> {
  const [managedCategories, legacyCategories] = await Promise.all([
    prisma.drinkCategory.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      select: { name: true },
    }),
    prisma.drink.findMany({
      where: { category: { not: null } },
      distinct: ['category'],
      select: { category: true },
      orderBy: { category: 'asc' },
    }),
  ]);
  const names = new Set<string>();
  for (const category of managedCategories) {
    if (category.name.trim()) names.add(category.name.trim());
  }
  for (const category of legacyCategories) {
    const name = category.category?.trim();
    if (name) names.add(name);
  }
  return [
    { value: '', label: '未分类' },
    ...[...names].map((name) => ({ value: name, label: name })),
  ];
}

async function ensureDrinkCategoryForAdmin(category: string | null | undefined): Promise<void> {
  const name = category?.trim();
  if (!name) return;
  await prisma.drinkCategory.upsert({
    where: { name },
    update: {},
    create: { name },
  });
}

async function assignDrinksToCategory(category: string, drinkIds: string[]): Promise<void> {
  await prisma.drink.updateMany({
    where: { category },
    data: { category: null },
  });
  if (drinkIds.length === 0) return;
  await prisma.drink.updateMany({
    where: { id: { in: drinkIds } },
    data: { category },
  });
}

async function getAdminOptions() {
  const [users, drinks, orders, orderItems] = await Promise.all([
    prisma.user.findMany({
      orderBy: { createdAt: 'asc' },
      select: { id: true, nickname: true, phone: true, role: true },
    }),
    prisma.drink.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    select: { id: true, name: true, category: true },
    }),
    prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        createdAt: true,
        user: { select: { nickname: true, phone: true } },
      },
    }),
    prisma.orderItem.findMany({
      orderBy: { id: 'asc' },
      select: {
        id: true,
        drink: { select: { name: true } },
        order: {
          select: {
            createdAt: true,
            user: { select: { nickname: true, phone: true } },
          },
        },
      },
    }),
  ]);

  return {
    users: users.map((user) => ({
      value: user.id,
      label: `${user.nickname}${user.phone ? ` · ${user.phone}` : ''}${
        user.role === 'ADMIN' ? ' · 管理员' : ''
      }`,
    })),
    drinks: drinks.map((drink) => ({ value: drink.id, label: drink.name })),
    orders: orders.map((order) => ({
      value: order.id,
      label: `${order.user.nickname} · ${formatDate(order.createdAt)}`,
    })),
    orderItems: orderItems.map((item) => ({
      value: item.id,
      label: `${item.order.user.nickname} · ${item.drink.name} · ${formatDate(
        item.order.createdAt,
      )}`,
    })),
  };
}

async function fieldsFor(table: EditableTable): Promise<AdminField[]> {
  const options = await getAdminOptions();
  const readonlyTime = (key: string, label: string): AdminField => ({
    key,
    label,
    type: 'text',
    editable: false,
    creatable: false,
  });

  switch (table) {
    case 'users':
      return [
        { key: 'phone', label: '手机号', type: 'text' },
        { key: 'nickname', label: '昵称', type: 'text', required: true },
        { key: 'role', label: '身份', type: 'select', options: roleOptions, required: true },
        { key: 'password', label: '登录密码', type: 'password', creatable: true },
        { key: 'wechatName', label: '微信显示名', type: 'text' },
        { key: 'avatarUrl', label: '头像地址', type: 'text' },
        readonlyTime('createdAtText', '注册时间'),
      ];
    case 'drinks':
      return [
        { key: 'name', label: '酒名', type: 'text', required: true },
        { key: 'nameEn', label: '英文名', type: 'text' },
        { key: 'description', label: '简介', type: 'textarea', required: true },
        { key: 'abv', label: '酒精度', type: 'number' },
        { key: 'photoUrl', label: '图片地址', type: 'text' },
        { key: 'isAvailable', label: '是否上架', type: 'boolean' },
        { key: 'sortOrder', label: '展示顺序', type: 'number' },
      ];
    case 'drinkCategories':
      return [
        { key: 'name', label: '分类名', type: 'text', required: true },
        { key: 'description', label: '说明', type: 'textarea' },
        { key: 'sortOrder', label: '展示顺序', type: 'number' },
        { key: 'drinkIds', label: '包含酒品', type: 'multiselect', options: options.drinks },
        readonlyTime('createdAtText', '创建时间'),
      ];
    case 'ingredients':
      return [
        { key: 'name', label: '原料名', type: 'text', required: true },
        {
          key: 'category',
          label: '原料类别',
          type: 'select',
          options: ingredientCategoryOptions,
          required: true,
        },
        { key: 'inStock', label: '库存充足', type: 'boolean' },
        { key: 'notes', label: '备注', type: 'textarea' },
      ];
    case 'orders':
      return [
        {
          key: 'userId',
          label: '下单顾客',
          type: 'select',
          options: options.users,
          required: true,
        },
        { key: 'status', label: '订单状态', type: 'select', options: orderStatusOptions },
        { key: 'notes', label: '订单备注', type: 'textarea' },
        readonlyTime('createdAtText', '下单时间'),
      ];
    case 'reviews':
      return [
        { key: 'userId', label: '评论用户', type: 'select', options: options.users, required: true },
        { key: 'drinkId', label: '评论酒品', type: 'select', options: options.drinks, required: true },
        {
          key: 'orderItemId',
          label: '关联订单酒品',
          type: 'select',
          options: [{ value: '', label: '不关联订单' }, ...options.orderItems],
        },
        { key: 'content', label: '评论内容', type: 'textarea', required: true },
        { key: 'rating', label: '评分', type: 'number' },
      ];
    case 'favorites':
      return [
        { key: 'userId', label: '喜欢用户', type: 'select', options: options.users, required: true },
        { key: 'drinkId', label: '喜欢酒品', type: 'select', options: options.drinks, required: true },
        readonlyTime('createdAtText', '点亮时间'),
      ];
    case 'communityPosts':
      return [
        { key: 'userId', label: '发布用户', type: 'select', options: options.users, required: true },
        {
          key: 'category',
          label: '栏目',
          type: 'select',
          options: communityCategoryOptions,
          required: true,
        },
        { key: 'title', label: '标题', type: 'text', required: true },
        { key: 'content', label: '内容', type: 'textarea', required: true },
        readonlyTime('createdAtText', '发布时间'),
      ];
  }
}

export async function listUsers(_req: Request, res: Response): Promise<void> {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'asc' },
    select: {
      id: true,
      nickname: true,
      phone: true,
      avatarUrl: true,
      role: true,
      wechatName: true,
      createdAt: true,
    },
  });
  res.json(users);
}

export async function databaseOverview(_req: Request, res: Response): Promise<void> {
  const [users, drinks, ingredients, orders, reviews, favorites, communityPosts] =
    await Promise.all([
      prisma.user.count(),
      prisma.drink.count(),
      prisma.ingredient.count(),
      prisma.order.count(),
      prisma.review.count(),
      prisma.favorite.count(),
      prisma.communityPost.count(),
    ]);
  res.json({ users, drinks, ingredients, orders, reviews, favorites, communityPosts });
}

export async function databaseTables(_req: Request, res: Response): Promise<void> {
  const counts = await Promise.all(
    editableTables.map(async (table) => {
      const count = await tableCount(table);
      return [table, count] as const;
    }),
  );

  res.json({
    tables: editableTables.map((key) => ({
      key,
      ...tableLabels[key],
      count: counts.find(([table]) => table === key)?.[1] ?? 0,
    })),
  });
}

export async function databaseTableRecords(req: Request, res: Response): Promise<void> {
  try {
    const table = ensureTable(paramValue(req.params.table));
    const fields = await fieldsFor(table);
    const records = await getRecords(table);
    res.json({ table: { key: table, ...tableLabels[table] }, fields, records });
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : '读取失败' });
  }
}

export async function createDatabaseRecord(req: Request, res: Response): Promise<void> {
  try {
    const table = ensureTable(paramValue(req.params.table));
    const record = await createRecord(table, req.body ?? {});
    res.status(201).json(record);
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : '创建失败' });
  }
}

export async function updateDatabaseRecord(req: Request, res: Response): Promise<void> {
  try {
    const table = ensureTable(paramValue(req.params.table));
    const record = await updateRecord(table, paramValue(req.params.id), req.body ?? {});
    res.json(record);
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : '更新失败' });
  }
}

export async function deleteDatabaseRecord(req: Request, res: Response): Promise<void> {
  try {
    const table = ensureTable(paramValue(req.params.table));
    await deleteRecord(table, paramValue(req.params.id));
    res.status(204).send();
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : '删除失败' });
  }
}

async function tableCount(table: EditableTable): Promise<number> {
  switch (table) {
    case 'users':
      return prisma.user.count();
    case 'drinks':
      return prisma.drink.count();
    case 'drinkCategories':
      return prisma.drinkCategory.count();
    case 'ingredients':
      return prisma.ingredient.count();
    case 'orders':
      return prisma.order.count();
    case 'reviews':
      return prisma.review.count();
    case 'favorites':
      return prisma.favorite.count();
    case 'communityPosts':
      return prisma.communityPost.count();
  }
}

async function getRecords(table: EditableTable) {
  switch (table) {
    case 'users': {
      const users = await prisma.user.findMany({ orderBy: { createdAt: 'desc' } });
      return users.map((user) => ({
        id: user.id,
        values: {
          phone: user.phone,
          nickname: user.nickname,
          role: user.role,
          password: user.passwordHash ? '__password_set__' : '',
          wechatName: user.wechatName,
          avatarUrl: user.avatarUrl,
          createdAtText: formatDate(user.createdAt),
        },
        summary: user.nickname,
        subtitle: `${user.phone ?? '未绑定手机号'} · ${optionLabel(roleOptions, user.role)}`,
      }));
    }
    case 'drinks': {
      const drinks = await prisma.drink.findMany({
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      });
      return drinks.map((drink) => ({
        id: drink.id,
        values: {
          name: drink.name,
          nameEn: drink.nameEn,
          description: drink.description,
          category: drink.category,
          abv: drink.abv,
          photoUrl: drink.photoUrl,
          isAvailable: drink.isAvailable,
          sortOrder: drink.sortOrder,
        },
        summary: drink.name,
        subtitle: `${drink.category ?? '未分类'} · ${drink.isAvailable ? '已上架' : '已下架'}`,
      }));
    }
    case 'drinkCategories': {
      const categories = await prisma.drinkCategory.findMany({
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      });
      const drinks = await prisma.drink.findMany({
        select: { id: true, name: true, category: true },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      });
      return categories.map((category) => {
        const categoryDrinks = drinks.filter((drink) => drink.category === category.name);
        return {
          id: category.id,
          values: {
            name: category.name,
            description: category.description,
            sortOrder: category.sortOrder,
            drinkIds: categoryDrinks.map((drink) => drink.id),
            createdAtText: formatDate(category.createdAt),
          },
          summary: category.name,
          subtitle: `${categoryDrinks.length} 款酒 · 展示顺序 ${category.sortOrder}`,
        };
      });
    }
    case 'ingredients': {
      const ingredients = await prisma.ingredient.findMany({
        orderBy: [{ category: 'asc' }, { createdAt: 'desc' }],
      });
      return ingredients.map((ingredient) => ({
        id: ingredient.id,
        values: {
          name: ingredient.name,
          category: ingredient.category,
          inStock: ingredient.inStock,
          notes: ingredient.notes,
        },
        summary: ingredient.name,
        subtitle: `${optionLabel(ingredientCategoryOptions, ingredient.category)} · ${
          ingredient.inStock ? '有货' : '缺货'
        }`,
      }));
    }
    case 'orders': {
      const orders = await prisma.order.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { nickname: true, phone: true } },
          items: { include: { drink: { select: { name: true } } } },
        },
      });
      return orders.map((order) => ({
        id: order.id,
        values: {
          userId: order.userId,
          status: order.status,
          notes: order.notes,
          createdAtText: formatDate(order.createdAt),
        },
        summary: order.items.map((item) => `${item.drink.name} x${item.quantity}`).join('、') || '空订单',
        subtitle: `${order.user.nickname} · ${optionLabel(orderStatusOptions, order.status)} · ${formatDate(
          order.createdAt,
        )}`,
      }));
    }
    case 'reviews': {
      const reviews = await prisma.review.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { nickname: true, phone: true } },
          drink: { select: { name: true } },
        },
      });
      return reviews.map((review) => ({
        id: review.id,
        values: {
          userId: review.userId,
          drinkId: review.drinkId,
          orderItemId: review.orderItemId ?? '',
          content: review.content,
          rating: review.rating,
        },
        summary: review.content,
        subtitle: `${review.user.nickname} · ${review.drink.name} · ${
          review.rating == null ? '未评分' : `${review.rating} 分`
        }`,
      }));
    }
    case 'favorites': {
      const favorites = await prisma.favorite.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { nickname: true, phone: true } },
          drink: { select: { name: true } },
        },
      });
      return favorites.map((favorite) => ({
        id: favorite.id,
        values: {
          userId: favorite.userId,
          drinkId: favorite.drinkId,
          createdAtText: formatDate(favorite.createdAt),
        },
        summary: `${favorite.user.nickname} 喜欢 ${favorite.drink.name}`,
        subtitle: formatDate(favorite.createdAt),
      }));
    }
    case 'communityPosts': {
      const posts = await prisma.communityPost.findMany({
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { nickname: true, phone: true } } },
      });
      return posts.map((post) => ({
        id: post.id,
        values: {
          userId: post.userId,
          category: post.category === 'SHARE' ? 'LIFE' : post.category,
          title: post.title,
          content: post.content,
          createdAtText: formatDate(post.createdAt),
        },
        summary: post.title,
        subtitle: `${post.user.nickname} · ${optionLabel(communityCategoryOptions, post.category)}`,
      }));
    }
  }
}

async function createRecord(table: EditableTable, body: Record<string, unknown>) {
  switch (table) {
    case 'users': {
      const password = textValue(body.password) ?? 'drunkard';
      if (password.length < 6) {
        throw new Error('密码至少 6 位');
      }
      return prisma.user.create({
        data: {
          phone: nullableTextValue(body.phone),
          nickname: textValue(body.nickname) ?? 'Drunkard',
          role: (textValue(body.role) ?? 'GUEST') as 'ADMIN' | 'GUEST',
          passwordHash: await bcrypt.hash(password, 10),
          wechatName: nullableTextValue(body.wechatName),
          avatarUrl: nullableTextValue(body.avatarUrl),
        },
      });
    }
    case 'drinks':
      await ensureDrinkCategoryForAdmin(nullableTextValue(body.category));
      return prisma.drink.create({
        data: {
          name: textValue(body.name) ?? '未命名酒品',
          nameEn: nullableTextValue(body.nameEn),
          description: textValue(body.description) ?? '等待补充简介',
          category: nullableTextValue(body.category),
          abv: numberValue(body.abv),
          photoUrl: nullableTextValue(body.photoUrl),
          isAvailable: booleanValue(body.isAvailable) ?? true,
          sortOrder: numberValue(body.sortOrder) ?? 0,
        },
      });
    case 'drinkCategories': {
      const name = textValue(body.name) ?? '未命名分类';
      const category = await prisma.drinkCategory.create({
        data: {
          name,
          description: nullableTextValue(body.description),
          sortOrder: numberValue(body.sortOrder) ?? 0,
        },
      });
      await assignDrinksToCategory(category.name, multiStringValue(body.drinkIds));
      return category;
    }
    case 'ingredients':
      return prisma.ingredient.create({
        data: {
          name: textValue(body.name) ?? '未命名原料',
          category: (textValue(body.category) ?? 'MIXER') as 'BASE_SPIRIT' | 'SYRUP' | 'MIXER',
          inStock: booleanValue(body.inStock) ?? true,
          notes: nullableTextValue(body.notes),
        },
      });
    case 'orders':
      return prisma.order.create({
        data: {
          userId: textValue(body.userId) ?? '',
          status: (textValue(body.status) ?? 'PENDING') as 'PENDING',
          notes: nullableTextValue(body.notes),
        },
      });
    case 'reviews':
      return prisma.review.create({
        data: {
          userId: textValue(body.userId) ?? '',
          drinkId: textValue(body.drinkId) ?? '',
          orderItemId: nullableTextValue(body.orderItemId),
          content: textValue(body.content) ?? '管理员补录评论',
          rating: numberValue(body.rating),
        },
      });
    case 'favorites':
      return prisma.favorite.create({
        data: {
          userId: textValue(body.userId) ?? '',
          drinkId: textValue(body.drinkId) ?? '',
        },
      });
    case 'communityPosts':
      return prisma.communityPost.create({
        data: {
          userId: textValue(body.userId) ?? '',
          category: (textValue(body.category) ?? 'LIFE') as 'LIFE' | 'BAR' | 'OFFICIAL',
          title: textValue(body.title) ?? '未命名帖子',
          content: textValue(body.content) ?? '等待补充内容',
        },
      });
  }
}

async function updateRecord(table: EditableTable, id: string, body: Record<string, unknown>) {
  switch (table) {
    case 'users': {
      const password = textValue(body.password);
      if (password !== undefined && password.length < 6) {
        throw new Error('密码至少 6 位');
      }
      return prisma.user.update({
        where: { id },
        data: {
          phone: nullableTextValue(body.phone),
          nickname: textValue(body.nickname),
          role: textValue(body.role) as 'ADMIN' | 'GUEST' | undefined,
          wechatName: nullableTextValue(body.wechatName),
          avatarUrl: nullableTextValue(body.avatarUrl),
          ...(password ? { passwordHash: await bcrypt.hash(password, 10) } : {}),
        },
      });
    }
    case 'drinks':
      await ensureDrinkCategoryForAdmin(nullableTextValue(body.category));
      return prisma.drink.update({
        where: { id },
        data: {
          name: textValue(body.name),
          nameEn: nullableTextValue(body.nameEn),
          description: textValue(body.description),
          category: nullableTextValue(body.category),
          abv: numberValue(body.abv),
          photoUrl: nullableTextValue(body.photoUrl),
          isAvailable: booleanValue(body.isAvailable),
          sortOrder: numberValue(body.sortOrder) ?? undefined,
        },
      });
    case 'drinkCategories': {
      const current = await prisma.drinkCategory.findUnique({ where: { id } });
      if (!current) throw new Error('分类不存在');
      const nextName = textValue(body.name) ?? current.name;
      const category = await prisma.drinkCategory.update({
        where: { id },
        data: {
          name: nextName,
          description: nullableTextValue(body.description),
          sortOrder: numberValue(body.sortOrder) ?? undefined,
        },
      });
      await prisma.drink.updateMany({
        where: { category: current.name },
        data: { category: nextName },
      });
      if (body.drinkIds !== undefined) {
        await assignDrinksToCategory(nextName, multiStringValue(body.drinkIds));
      }
      return category;
    }
    case 'ingredients':
      return prisma.ingredient.update({
        where: { id },
        data: {
          name: textValue(body.name),
          category: textValue(body.category) as 'BASE_SPIRIT' | 'SYRUP' | 'MIXER' | undefined,
          inStock: booleanValue(body.inStock),
          notes: nullableTextValue(body.notes),
        },
      });
    case 'orders':
      return prisma.order.update({
        where: { id },
        data: {
          userId: textValue(body.userId),
          status: textValue(body.status) as
            | 'PENDING'
            | 'CONFIRMED'
            | 'PREPARING'
            | 'READY'
            | 'DELIVERED'
            | 'CANCELLED'
            | undefined,
          notes: nullableTextValue(body.notes),
        },
      });
    case 'reviews':
      return prisma.review.update({
        where: { id },
        data: {
          userId: textValue(body.userId),
          drinkId: textValue(body.drinkId),
          orderItemId: nullableTextValue(body.orderItemId),
          content: textValue(body.content),
          rating: numberValue(body.rating),
        },
      });
    case 'favorites':
      return prisma.favorite.update({
        where: { id },
        data: {
          userId: textValue(body.userId),
          drinkId: textValue(body.drinkId),
        },
      });
    case 'communityPosts':
      return prisma.communityPost.update({
        where: { id },
        data: {
          userId: textValue(body.userId),
          category: textValue(body.category) as 'LIFE' | 'BAR' | 'OFFICIAL' | undefined,
          title: textValue(body.title),
          content: textValue(body.content),
        },
      });
  }
}

async function deleteRecord(table: EditableTable, id: string): Promise<void> {
  switch (table) {
    case 'users':
      await prisma.user.delete({ where: { id } });
      return;
    case 'drinks':
      await prisma.drink.delete({ where: { id } });
      return;
    case 'drinkCategories': {
      const category = await prisma.drinkCategory.findUnique({ where: { id } });
      if (!category) return;
      await prisma.drink.updateMany({
        where: { category: category.name },
        data: { category: null },
      });
      await prisma.drinkCategory.delete({ where: { id } });
      return;
    }
    case 'ingredients':
      await prisma.ingredient.delete({ where: { id } });
      return;
    case 'orders':
      await prisma.order.delete({ where: { id } });
      return;
    case 'reviews':
      await prisma.review.delete({ where: { id } });
      return;
    case 'favorites':
      await prisma.favorite.delete({ where: { id } });
      return;
    case 'communityPosts':
      await prisma.communityPost.delete({ where: { id } });
      return;
  }
}
