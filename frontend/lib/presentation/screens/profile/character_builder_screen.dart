import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../data/services/api_service.dart';
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

  Future<void> _saveCharacter() async {
    if (!_formKey.currentState!.validate()) return;

    // We should allow saving even without traits, but let's encourage at least one
    if (_traits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("최소 1개의 성격(키워드)을 추가해주세요."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final additionalPayload = {
        'background_story': _backgroundController.text.trim(),
        'image_url': _appearanceController.text.trim().isNotEmpty
            ? 'generate:${_appearanceController.text.trim()}'
            : null,
      };

      // ApiService doesn't accept full payload for character yet in the current sig:
      // Assuming createCharacter(name, desc, traits) is the current signature.
      // We will update ApiService to handle these if we want, but for now we just use standard.
      // ACTUALLY, checking ApiService.createCharacter, it only takes 3 positional args. Let's stick to them first.
      await ApiService().createCharacter(
        _nameController.text.trim(),
        "${_descController.text.trim()}\n[배경]: ${_backgroundController.text.trim()}\n[외양]: ${_appearanceController.text.trim()}",
        _traits,
      );

      ref.invalidate(charactersProvider);

      if (mounted) {
        Navigator.pop(context); // Go back to profile tabs
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("캐릭터가 성공적으로 생성되었습니다!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("생성 실패: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("새 페르소나 설계"),
        backgroundColor: const Color(0xFF121212),
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
                  icon: const Icon(Icons.check, color: Color(0xFF7C3AED)),
                  label: const Text(
                    "저장",
                    style: TextStyle(
                      color: Color(0xFF7C3AED),
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
            const Text(
              "엔터(↵)를 눌러 키워드를 추가하세요.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ).animate().fadeIn().slideX(delay: 100.ms),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
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
                        backgroundColor: const Color(
                          0xFF7C3AED,
                        ).withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide(
                          color: const Color(0xFF7C3AED).withOpacity(0.5),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_traits.isNotEmpty) const SizedBox(height: 12),
                  TextField(
                    controller: _traitInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "새 키워드 입력...",
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
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
              hint: "이 캐릭터는 어떤 과거를 가지고 있나요?\\n어떤 목적을 위해 여행을 하나요?",
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
              hint: "예: 긴 은발, 붉은 눈동자, 검은색 롱코트\\n(이 묘사는 이미지 생성 시 활용됩니다)",
              maxLines: 2,
            ).animate().fadeIn().slideX(delay: 350.ms),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
