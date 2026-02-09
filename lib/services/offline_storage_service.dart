import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_media.dart';

class OfflineStorageService {
  static const String _storageKey = 'pending_media_items';
  
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PendingMedia>> getAllPendingMedia() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> list = _prefs!.getStringList(_storageKey) ?? [];
    
    return list
        .map((item) => PendingMedia.fromJson(json.decode(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  Future<void> savePendingMedia(PendingMedia media) async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> list = _prefs!.getStringList(_storageKey) ?? [];
    
    list.add(json.encode(media.toJson()));
    await _prefs!.setStringList(_storageKey, list);
  }

  Future<void> deletePendingMedia(String id) async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> list = _prefs!.getStringList(_storageKey) ?? [];
    
    final updatedList = list.where((item) {
      final media = PendingMedia.fromJson(json.decode(item));
      return media.id != id;
    }).toList();

    await _prefs!.setStringList(_storageKey, updatedList);
    
    // Note: In a real app, we should also delete the actual file from disk here
    // But since we might mock file paths or use cache, we'll keep it simple for now
  }

  Future<int> getPendingCount() async {
    final items = await getAllPendingMedia();
    return items.length;
  }
}

final offlineStorageService = OfflineStorageService();
