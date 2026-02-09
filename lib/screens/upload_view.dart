import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/translation_service.dart';

/// Upload View - Upload images from gallery for diagnosis
/// Matches React's Upload component in CropDiagnosisApp.jsx
class UploadView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(List<String> imagePaths) onUpload;

  const UploadView({
    super.key,
    required this.onBack,
    required this.onUpload,
  });

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  List<String> _selectedImages = [];
  bool _isDragging = false;

  void _selectImages() async {
    // In real implementation, would use image_picker
    setState(() {
      _selectedImages = ['image1.jpg', 'image2.jpg'];
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _uploadImages() {
    if (_selectedImages.isNotEmpty) {
      widget.onUpload(_selectedImages);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          color: AppColors.gray700,
        ),
        title: Text(
          context.t('uploadView.title'),
          style: const TextStyle(color: AppColors.gray800),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.nature50, Color(0xFFD1FAE5)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Upload Zone
                Expanded(
                  child: GestureDetector(
                    onTap: _selectImages,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _isDragging 
                            ? AppColors.nature100 
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isDragging
                              ? AppColors.nature500
                              : AppColors.gray200,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedImages.isEmpty
                          ? _buildEmptyState()
                          : _buildImageGrid(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(context.t('uploadView.addMore')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.nature500),
                          foregroundColor: AppColors.nature600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _selectedImages.isEmpty ? null : _uploadImages,
                        icon: const Icon(Icons.upload),
                        label: Text(
                          _selectedImages.isEmpty 
                              ? context.t('uploadView.selectImages') 
                              : '${context.t('uploadView.analyze')} ${_selectedImages.length}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.nature600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.nature100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_upload_outlined,
            size: 64,
            color: AppColors.nature500,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.t('uploadView.uploadTitle'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('uploadView.tapToSelect'),
          style: TextStyle(
            fontSize: 16,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: AppColors.blue500, size: 20),
              const SizedBox(width: 8),
              Text(
                context.t('uploadView.supportedFormats'),
                style: TextStyle(
                  color: AppColors.blue600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 40, color: AppColors.gray400),
                    const SizedBox(height: 8),
                    Text(
                      'Image ${index + 1}',
                      style: TextStyle(color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.red500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
