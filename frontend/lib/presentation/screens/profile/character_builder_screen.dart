import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';

class CharacterBuilderScreen extends ConsumerStatefulWidget {
  const CharacterBuilderScreen({super.key});

  @override
  ConsumerState<CharacterBuilderScreen> createState() =>
      _CharacterBuilderScreenState();
}

class _CharacterBuilderScreenState
    extends ConsumerState<CharacterBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _appearanceController = TextEditingController();
  final _traitInputController = TextEditingController();

  final List<String> _traits = [];
  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _backgroundController.dispose();
    _appearanceController.dispose();
    _traitInputController.dispose();
    super.dispose();
  }

  void _addTrait(String trait) {
    if (trait.trim().isNotEmpty && !_traits.contains(trait.trim())) {
      setState(() {
        _traits.add(trait.trim());
        _traitInputController.clear();
      });
    }
  }

  void _removeTrait(String trait) {
    setState(() {
      _traits.remove(trait);
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("이미지 선택 오류: $e"),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    }
  }

  Future<void> _saveCharacter() async {
    if (!_formKey.currentState!.validate()) return;

    // We should allow saving even without traits, but let's encourage at least one
    if (_traits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("최소 1개의 성격(키워드)을 추가해주세요."),
          backgroundColor: context.palette.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider).value;
      if (user == null) {
        throw Exception("로그인이 필요합니다.");
      }

      final response = await ApiService().createCharacter(
        _nameController.text.trim(),
        _descController.text.trim(),
        _traits,
        userId: user.id,
        backgroundStory: _backgroundController.text.trim(),
        appearanceDescription: _appearanceController.text.trim(),
      );

      final characterId = response['id'];

      // Upload image if selected
      if (_selectedImageBytes != null) {
        await ApiService().uploadCharacterImage(
          characterId,
          _selectedImageBytes!,
          fileName: 'character_${characterId.substring(0, 8)}.jpg',
        );
      }

      ref.invalidate(charactersProvider);

      if (mounted) {
        Navigator.pop(context); // Go back to profile tabs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("캐릭터가 성공적으로 생성되었습니다!"),
            backgroundColor: context.palette.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("생성 실패: $e"),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final palette = context.palette;
    final style = context.appStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: style.title(
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    final palette = context.palette;
    final style = context.appStyle;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: palette.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: palette.faint),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.radius),
          borderSide: BorderSide(
            color: style.edge(palette),
            width: style.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.radius),
          borderSide: BorderSide(
            color: style.edge(palette),
            width: style.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.radius),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
      ),
      validator: isRequired
          ? (value) =>
                value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        title: const Text("새 페르소나 설계"),
        backgroundColor: palette.ground,
        elevation: 0,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _saveCharacter,
                  icon: Icon(Icons.check, color: palette.accent),
                  label: Text(
                    "저장",
                    style: TextStyle(
                      color: palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar Picture Upload UI
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    image: _selectedImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_selectedImageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: palette.accent.withValues(alpha: 0.8),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "사진 추가",
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1, delay: 100.ms),
            const SizedBox(height: 32),

            // Core Info
            _buildSectionTitle("기본 정보", Icons.badge_outlined),
            _buildTextField(
              controller: _nameController,
              label: "이름",
              hint: "예: 아서 펜드래곤",
              isRequired: true,
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descController,
              label: "한 줄 소개 (역할)",
              hint: "예: 마탄을 쏘는 떠돌이 사냥꾼",
              isRequired: true,
            ).animate().fadeIn().slideX(delay: 50.ms),
            const SizedBox(height: 32),

            // Personality Traits
            _buildSectionTitle(
              "성격 및 특징",
              Icons.psychology_outlined,
            ).animate().fadeIn().slideX(delay: 100.ms),
            Text(
              "엔터(↵)를 눌러 키워드를 추가하세요.",
              style: TextStyle(color: palette.muted, fontSize: 13),
            ).animate().fadeIn().slideX(delay: 100.ms),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: style.card(palette),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _traits.map((trait) {
                      return Chip(
                        label: Text(trait),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeTrait(trait),
                        backgroundColor: style
                            .control(palette, selected: true)
                            .color,
                        labelStyle: TextStyle(
                          color: style.onControl(palette, selected: true),
                        ),
                        deleteIconColor: style.onControl(
                          palette,
                          selected: true,
                        ),
                        side: BorderSide(
                          color: style.isNight
                              ? palette.accent.withValues(alpha: 0.5)
                              : style.edge(palette),
                          width: style.borderWidth,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_traits.isNotEmpty) const SizedBox(height: 12),
                  TextField(
                    controller: _traitInputController,
                    style: TextStyle(color: palette.text),
                    decoration: InputDecoration(
                      hintText: "새 키워드 입력...",
                      hintStyle: TextStyle(color: palette.faint),
                      // The box around the field is its fill and outline: none of the theme's.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _addTrait,
                  ),
                ],
              ),
            ).animate().fadeIn().slideX(delay: 150.ms),
            const SizedBox(height: 32),

            // Context & Background
            _buildSectionTitle(
              "배경 및 히스토리",
              Icons.history_edu_outlined,
            ).animate().fadeIn().slideX(delay: 200.ms),
            _buildTextField(
              controller: _backgroundController,
              label: "상세 배경 스토리 (선택)",
              hint: "이 캐릭터는 어떤 과거를 가지고 있나요?\n어떤 목적을 위해 여행을 하나요?",
              maxLines: 4,
            ).animate().fadeIn().slideX(delay: 250.ms),
            const SizedBox(height: 32),

            // Appearance (Image Gen Prompt context)
            _buildSectionTitle(
              "외향 및 묘사",
              Icons.face_retouching_natural,
            ).animate().fadeIn().slideX(delay: 300.ms),
            _buildTextField(
              controller: _appearanceController,
              label: "외모 특징 (선택)",
              hint: "예: 긴 은발, 붉은 눈동자, 검은색 롱코트\n(이 묘사는 이미지 생성 시 활용됩니다)",
              maxLines: 2,
            ).animate().fadeIn().slideX(delay: 350.ms),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
