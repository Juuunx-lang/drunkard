import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../inventory/data/ingredient_model.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/drinks_repository.dart';
import '../data/models/drink_model.dart';

class DrinkEditorSheet extends ConsumerStatefulWidget {
  const DrinkEditorSheet({
    super.key,
    this.drink,
  });

  final Drink? drink;

  @override
  ConsumerState<DrinkEditorSheet> createState() => _DrinkEditorSheetState();
}

class _DrinkEditorSheetState extends ConsumerState<DrinkEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _recipeController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _abvController;
  late final TextEditingController _sortOrderController;
  late bool _isAvailable;
  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _selectedCategory;
  late final Map<String, _SelectedIngredientState> _selectedIngredients;

  bool get _isEditing => widget.drink != null;

  @override
  void initState() {
    super.initState();
    final drink = widget.drink;
    _nameController = TextEditingController(text: drink?.name ?? '');
    _nameEnController = TextEditingController(text: drink?.nameEn ?? '');
    _descriptionController =
        TextEditingController(text: drink?.description ?? '');
    _recipeController = TextEditingController(text: drink?.recipe ?? '');
    _selectedCategory =
        drink?.category?.trim().isEmpty == true ? null : drink?.category;
    _photoUrlController = TextEditingController(text: drink?.photoUrl ?? '');
    _abvController = TextEditingController(text: drink?.abv?.toString() ?? '');
    _sortOrderController = TextEditingController(text: '0');
    _isAvailable = drink?.isAvailable ?? true;
    _selectedIngredients = {
      for (final ingredient in drink?.ingredients ?? <DrinkIngredient>[])
        ingredient.id: _SelectedIngredientState(
          amount: ingredient.amount ?? '',
          isOptional: ingredient.isOptional,
        ),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _recipeController.dispose();
    _photoUrlController.dispose();
    _abvController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final categoriesState = ref.watch(drinkCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? '编辑酒品' : '新增酒品',
              style: const TextStyle(
                color: BarColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildTextField(_nameController, '酒名 *'),
                  const SizedBox(height: 12),
                  _buildTextField(_nameEnController, '英文名'),
                  const SizedBox(height: 12),
                  categoriesState.when(
                    data: (categories) => _buildCategoryPicker(
                      categories.map((category) => category.name).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(
                      '分类加载失败：$error',
                      style: const TextStyle(color: BarColors.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _descriptionController,
                    '描述 *',
                    minLines: 3,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _recipeController,
                    '配方步骤',
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  _buildPhotoSection(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _abvController,
                          'ABV',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          _sortOrderController,
                          '展示顺序',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isAvailable,
                    onChanged: (value) => setState(() => _isAvailable = value),
                    activeThumbColor: BarColors.neonGreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '上架可点单',
                      style: TextStyle(color: BarColors.textPrimary),
                    ),
                    subtitle: const Text(
                      '关闭后酒品会显示为缺货',
                      style: TextStyle(color: BarColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '配料',
                    style: TextStyle(
                      color: BarColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  inventoryState.when(
                    data: (group) => Column(
                      children: [
                        _IngredientGroupSection(
                          title: '基酒',
                          items: group.baseSpirit,
                          selectedIngredients: _selectedIngredients,
                          onChanged: () => setState(() {}),
                        ),
                        _IngredientGroupSection(
                          title: '糖浆',
                          items: group.syrup,
                          selectedIngredients: _selectedIngredients,
                          onChanged: () => setState(() {}),
                        ),
                        _IngredientGroupSection(
                          title: '辅料',
                          items: group.mixer,
                          selectedIngredients: _selectedIngredients,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '原料加载失败：$error',
                        style: const TextStyle(color: BarColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                    _submitting ? '保存中...' : (_isEditing ? '保存修改' : '创建酒品')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildCategoryPicker(List<String> categories) {
    final options = [
      ...categories,
      if (_selectedCategory != null && !categories.contains(_selectedCategory))
        _selectedCategory!,
    ];

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      items: options
          .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
      decoration: const InputDecoration(
        labelText: '分类',
        hintText: '请先在数据库 GUI 的酒类分类中维护',
      ),
    );
  }

  Widget _buildPhotoSection() {
    final photoValue = _photoUrlController.text.trim();
    final hasPhoto = photoValue.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BarColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BarColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '酒品图片',
            style: TextStyle(
              color: BarColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '建议按 4:3 裁切；酒单卡片和详情页会自动居中裁切适配显示区域。',
            style: TextStyle(
                color: BarColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.white.withOpacity(0.05),
                child: hasPhoto
                    ? appImage(photoValue, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: BarColors.textSecondary,
                          size: 42,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingPhoto ? null : _pickAndCropPhoto,
                  icon: Icon(_uploadingPhoto
                      ? Icons.hourglass_top
                      : Icons.crop_original),
                  label: Text(_uploadingPhoto ? '上传中...' : '上传并裁切'),
                ),
              ),
              const SizedBox(width: 10),
              if (hasPhoto)
                IconButton(
                  tooltip: '清除图片',
                  onPressed: _uploadingPhoto
                      ? null
                      : () => setState(() => _photoUrlController.clear()),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _photoUrlController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '图片地址（可选，高级）',
              hintText: '上传后会自动填入，也可粘贴图片 URL',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndCropPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DrinkPhotoCropScreen(imageBytes: bytes),
      ),
    );
    if (croppedBytes == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final croppedFile = XFile.fromData(
        croppedBytes,
        name: 'drink_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );
      final url =
          await ref.read(drinksRepositoryProvider).uploadPhoto(croppedFile);
      if (url.isEmpty) {
        throw Exception('上传接口未返回图片地址');
      }
      if (mounted) {
        setState(() => _photoUrlController.text = url);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, '图片上传失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || description.isEmpty) {
      showAppToast(context, '请至少填写酒名和描述');
      return;
    }

    setState(() => _submitting = true);

    try {
      final ingredientPayload = _selectedIngredients.entries
          .map(
            (entry) => {
              'id': entry.key,
              if (entry.value.amount.trim().isNotEmpty)
                'amount': entry.value.amount.trim(),
              'isOptional': entry.value.isOptional,
            },
          )
          .toList();

      final abv = double.tryParse(_abvController.text.trim());
      final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
      final repository = ref.read(drinksRepositoryProvider);

      if (_isEditing) {
        await repository.updateDrink(
          id: widget.drink!.id,
          name: name,
          nameEn: _nameEnController.text,
          description: description,
          recipe: _recipeController.text,
          photoUrl: _photoUrlController.text,
          category: _selectedCategory,
          abv: abv,
          isAvailable: _isAvailable,
          sortOrder: sortOrder,
          ingredientIds: ingredientPayload,
        );
      } else {
        await repository.createDrink(
          name: name,
          nameEn: _nameEnController.text,
          description: description,
          recipe: _recipeController.text,
          photoUrl: _photoUrlController.text,
          category: _selectedCategory,
          abv: abv,
          isAvailable: _isAvailable,
          sortOrder: sortOrder,
          ingredientIds: ingredientPayload,
        );
      }

      ref.invalidate(drinksListProvider);
      if (widget.drink != null) {
        ref.invalidate(drinkDetailProvider(widget.drink!.id));
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, '保存酒品失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _IngredientGroupSection extends StatelessWidget {
  const _IngredientGroupSection({
    required this.title,
    required this.items,
    required this.selectedIngredients,
    required this.onChanged,
  });

  final String title;
  final List<Ingredient> items;
  final Map<String, _SelectedIngredientState> selectedIngredients;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BarColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BarColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BarColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (ingredient) => _IngredientSelectionTile(
              ingredient: ingredient,
              selection: selectedIngredients[ingredient.id],
              onSelectionChanged: (selected) {
                if (selected) {
                  selectedIngredients.putIfAbsent(
                    ingredient.id,
                    () => _SelectedIngredientState(),
                  );
                } else {
                  selectedIngredients.remove(ingredient.id);
                }
                onChanged();
              },
              onAmountChanged: (value) {
                selectedIngredients[ingredient.id]?.amount = value;
                onChanged();
              },
              onOptionalChanged: (value) {
                selectedIngredients[ingredient.id]?.isOptional = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientSelectionTile extends StatelessWidget {
  const _IngredientSelectionTile({
    required this.ingredient,
    required this.selection,
    required this.onSelectionChanged,
    required this.onAmountChanged,
    required this.onOptionalChanged,
  });

  final Ingredient ingredient;
  final _SelectedIngredientState? selection;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<bool> onOptionalChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selection != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (value) => onSelectionChanged(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              ingredient.name,
              style: const TextStyle(color: BarColors.textPrimary),
            ),
            subtitle: Text(
              ingredient.inStock ? '库存可用' : '当前缺货',
              style: TextStyle(
                color:
                    ingredient.inStock ? BarColors.neonGreen : BarColors.error,
                fontSize: 12,
              ),
            ),
          ),
          if (selected)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: selection!.amount,
                    onChanged: onAmountChanged,
                    decoration: const InputDecoration(
                      labelText: '用量',
                      hintText: '例如 45ml / 1片',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    value: selection!.isOptional,
                    onChanged: onOptionalChanged,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '可选',
                      style:
                          TextStyle(color: BarColors.textPrimary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SelectedIngredientState {
  _SelectedIngredientState({
    this.amount = '',
    this.isOptional = false,
  });

  String amount;
  bool isOptional;
}

class _DrinkPhotoCropScreen extends StatefulWidget {
  const _DrinkPhotoCropScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_DrinkPhotoCropScreen> createState() => _DrinkPhotoCropScreenState();
}

class _DrinkPhotoCropScreenState extends State<_DrinkPhotoCropScreen> {
  static const _cropAspectRatio = 4 / 3;
  static const _maxUploadBytes = 8 * 1024 * 1024;

  ui.Image? _sourceImage;
  Size? _viewportSize;
  double _scale = 1;
  double _baseScale = 1;
  double _gestureStartScale = 1;
  Offset _gestureStartFocalPoint = Offset.zero;
  Offset _offset = Offset.zero;
  Offset _gestureStartOffset = Offset.zero;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _decodeSourceImage();
  }

  Future<void> _decodeSourceImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _sourceImage = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('裁切酒品图片'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: _cropping ? null : _finishCrop,
            child: Text(_cropping ? '处理中...' : '使用图片'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '拖动或缩放图片，让主体落在裁切框内',
                style: TextStyle(
                  color: BarColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '裁切比例：4:3。酒单卡片会取中心区域，详情页会按头图高度自适应显示。',
                style: TextStyle(color: BarColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              Expanded(child: Center(child: _buildCropViewport())),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed:
                        _sourceImage == null ? null : () => _adjustScale(0.9),
                    icon: const Icon(Icons.remove),
                    tooltip: '缩小',
                  ),
                  Expanded(
                    child: Slider(
                      value: _sliderValue,
                      min: _sliderMin,
                      max: _sliderMax,
                      onChanged: _sourceImage == null
                          ? null
                          : (value) => setState(() => _setScale(value)),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed:
                        _sourceImage == null ? null : () => _adjustScale(1.12),
                    icon: const Icon(Icons.add),
                    tooltip: '放大',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cropping ? null : _finishCrop,
                  icon: const Icon(Icons.check),
                  label: Text(_cropping ? '裁切中...' : '确认裁切并上传'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _adjustScale(double factor) {
    _setScale(_scale * factor);
    setState(() {});
  }

  double get _sliderMin => _baseScale <= 0 ? 1 : _baseScale;
  double get _sliderMax => _baseScale <= 0 ? 5 : _baseScale * 5;
  double get _sliderValue => _scale.clamp(_sliderMin, _sliderMax);

  Size? get _containSize {
    final image = _sourceImage;
    final viewport = _viewportSize;
    if (image == null || viewport == null) return null;

    final imageAspect = image.width / image.height;
    final viewportAspect = viewport.width / viewport.height;
    return imageAspect >= viewportAspect
        ? Size(viewport.width, viewport.width / imageAspect)
        : Size(viewport.height * imageAspect, viewport.height);
  }

  void _setScale(double value) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final minScale = _baseScale;
    final maxScale = _baseScale * 5;
    _scale = value.clamp(minScale, maxScale);
    _offset = _clampOffset(_offset, viewport, _scale);
  }

  Widget _buildCropViewport() {
    if (_sourceImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / _cropAspectRatio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * _cropAspectRatio;
        }
        final viewportSize = Size(width, height);
        if (_viewportSize != viewportSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _ensureViewport(viewportSize));
          });
        }

        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onScaleStart: (details) {
                _gestureStartScale = _scale;
                _gestureStartOffset = _offset;
                _gestureStartFocalPoint = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                setState(() {
                  final minScale = _baseScale;
                  final maxScale = _baseScale * 5;
                  _scale = (_gestureStartScale * details.scale).clamp(
                    minScale,
                    maxScale,
                  );
                  final focalDelta =
                      details.localFocalPoint - _gestureStartFocalPoint;
                  _offset = _clampOffset(
                    _gestureStartOffset + focalDelta,
                    viewportSize,
                    _scale,
                  );
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: BarColors.background),
                  Transform.translate(
                    offset: _offset,
                    child: Center(
                      child: Transform.scale(
                        scale: _scale,
                        child: SizedBox(
                          width: _containSize?.width ?? width,
                          height: _containSize?.height ?? height,
                          child: RawImage(
                            image: _sourceImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: BarColors.neonGold.withOpacity(0.95),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureViewport(Size viewportSize) {
    if (_sourceImage == null) return;
    if (_viewportSize == viewportSize) return;

    _viewportSize = viewportSize;
    _baseScale = _coverScale(viewportSize);
    _scale = _baseScale * 1.06;
    _offset = Offset.zero;
  }

  double _containWidth() {
    return _containSize?.width ?? 0;
  }

  double _containHeight() {
    return _containSize?.height ?? 0;
  }

  double _coverScale(Size viewport) {
    final image = _sourceImage;
    if (image == null) return 1;
    final containWidth =
        image.width / image.height >= viewport.width / viewport.height
            ? viewport.width
            : viewport.height * image.width / image.height;
    final containHeight =
        image.width / image.height >= viewport.width / viewport.height
            ? viewport.width / (image.width / image.height)
            : viewport.height;
    return math.max(
        viewport.width / containWidth, viewport.height / containHeight);
  }

  Offset _clampOffset(Offset offset, Size viewport, double scale) {
    if (_sourceImage == null) return Offset.zero;
    final displayWidth = _containWidth() * scale;
    final displayHeight = _containHeight() * scale;
    if (displayWidth <= 0 || displayHeight <= 0) return Offset.zero;
    final maxX = math.max(0.0, (displayWidth - viewport.width) / 2);
    final maxY = math.max(0.0, (displayHeight - viewport.height) / 2);
    return Offset(
      offset.dx.clamp(-maxX, maxX),
      offset.dy.clamp(-maxY, maxY),
    );
  }

  Future<void> _finishCrop() async {
    setState(() => _cropping = true);
    try {
      final source = _sourceImage;
      final viewport = _viewportSize;
      if (source == null || viewport == null) {
        throw Exception('图片还没准备好');
      }

      final containWidth = _containWidth();
      final containHeight = _containHeight();
      if (containWidth <= 0 || containHeight <= 0 || _scale <= 0) {
        throw Exception('图片裁切区域还没准备好');
      }
      final displayWidth = containWidth * _scale;
      final displayHeight = containHeight * _scale;
      final displayLeft = (viewport.width - displayWidth) / 2 + _offset.dx;
      final displayTop = (viewport.height - displayHeight) / 2 + _offset.dy;
      final sourceRect = Rect.fromLTWH(
        (-displayLeft / displayWidth * source.width)
            .clamp(0.0, source.width.toDouble()),
        (-displayTop / displayHeight * source.height)
            .clamp(0.0, source.height.toDouble()),
        (viewport.width / displayWidth * source.width)
            .clamp(1.0, source.width.toDouble()),
        (viewport.height / displayHeight * source.height)
            .clamp(1.0, source.height.toDouble()),
      );
      final safeRect = Rect.fromLTWH(
        sourceRect.left.clamp(0.0, source.width - 1.0),
        sourceRect.top.clamp(0.0, source.height - 1.0),
        math.min(sourceRect.width, source.width - sourceRect.left),
        math.min(sourceRect.height, source.height - sourceRect.top),
      );

      Uint8List? bytes;
      for (final width in const [1200, 960, 720, 540]) {
        final height = (width / _cropAspectRatio).round();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final outputSize = Size(width.toDouble(), height.toDouble());
        canvas.drawImageRect(
          source,
          safeRect,
          Offset.zero & outputSize,
          Paint()..filterQuality = FilterQuality.high,
        );
        final picture = recorder.endRecording();
        final cropped = await picture.toImage(width, height);
        final byteData =
            await cropped.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData?.buffer.asUint8List();
        if (bytes != null && bytes.lengthInBytes <= _maxUploadBytes) {
          break;
        }
      }
      if (bytes == null) throw Exception('图片裁切失败');
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (error) {
      if (mounted) {
        showAppToast(context, '裁切失败：$error');
      }
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }
}
