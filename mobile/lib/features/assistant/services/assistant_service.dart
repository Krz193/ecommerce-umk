import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/assistant/models/assistance_log_model.dart';
import 'package:mobile/features/assistant/models/assistant_profile_model.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';

class AssistantService {
  Future<void> becomeAssistant() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Pengguna belum terautentikasi');
    await supabase.rpc('become_assistant');
  }

  Future<List<AssignedStoreInfo>> getAssignedStores() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('store_assistants')
        .select('''
          store_id,
          assigned_at,
          stores (
            id,
            name,
            logo_url,
            address
          )
        ''')
        .eq('user_id', userId)
        .order('assigned_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => AssignedStoreInfo.fromMap(json)).toList();
  }

  Future<AssistantProfileModel?> getAssistantProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final userRes = await supabase
        .from('users')
        .select('id, full_name, phone, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();

    if (userRes == null) return null;

    final assignedStores = await getAssignedStores();
    final Map<String, dynamic> userMap = Map<String, dynamic>.from(userRes);
    userMap['email'] = supabase.auth.currentUser?.email ?? '';

    return AssistantProfileModel.fromMap(userMap, assignedStores);
  }

  Future<List<AssistanceLogModel>> getAssistanceLogs({String? storeId}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = supabase.from('assistance_logs').select('''
          *,
          stores (
            name
          )
        ''');

    if (storeId != null && storeId.isNotEmpty) {
      query = query.eq('store_id', storeId);
    } else {
      query = query.eq('assistant_id', userId);
    }

    final response = await query.order('created_at', ascending: false);
    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => AssistanceLogModel.fromMap(json)).toList();
  }

  Future<void> logActivity({
    required String storeId,
    required String actionType,
    required String title,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await supabase.rpc(
        'log_assistance_activity',
        params: {
          'p_store_id': storeId,
          'p_action_type': actionType,
          'p_title': title,
          'p_description': description,
          'p_metadata': metadata ?? {},
        },
      );
    } catch (_) {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('assistance_logs').insert({
          'assistant_id': userId,
          'store_id': storeId,
          'action_type': actionType,
          'title': title,
          'description': description,
          'metadata': metadata ?? {},
        });
      }
    }
  }

  Future<Map<String, dynamic>> getStoreDonationsSummary(String storeId) async {
    final rows = await supabase
        .from('donations')
        .select(
          'id, donor_name, amount, distributed_amount, distributed_at, status, note, created_at',
        )
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    int totalCollected = 0;
    int totalDistributed = 0;
    int donorCount = 0;

    for (final raw in list) {
      final map = raw as Map<String, dynamic>;
      final status = map['status'] as String? ?? 'paid';
      final amount = (map['amount'] as num?)?.round() ?? 0;
      final distAmount = (map['distributed_amount'] as num?)?.round() ?? amount;

      if (status == 'paid' || status == 'distributed') {
        totalCollected += amount;
        donorCount += 1;
      }
      if (status == 'distributed') {
        totalDistributed += distAmount;
      }
    }

    return {
      'total_collected': totalCollected,
      'total_distributed': totalDistributed,
      'pending_distribution': (totalCollected - totalDistributed).clamp(
        0,
        totalCollected,
      ),
      'donor_count': donorCount,
      'recent_donations': list.take(5).toList(),
    };
  }

  Future<List<StoreContentModel>> getStoreContents({
    required String storeId,
  }) async {
    if (storeId.trim().isEmpty) return [];

    dynamic response;
    try {
      response = await supabase
          .from('store_contents')
          .select('''
            *,
            stores (
              name
            ),
            products (
              id,
              name,
              price,
              thumbnail_url
            ),
            users:created_by (
              full_name
            )
          ''')
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Waktu memuat konten habis. Periksa koneksi internet.',
            ),
          );
    } catch (_) {
      response = await supabase
          .from('store_contents')
          .select('''
            *,
            stores (
              name
            ),
            products (
              id,
              name,
              price,
              thumbnail_url
            )
          ''')
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Waktu memuat konten habis. Periksa koneksi internet.',
            ),
          );
    }

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => StoreContentModel.fromMap(json)).toList();
  }

  Future<StoreContentModel> createStoreContent({
    required String storeId,
    required String title,
    required String contentType,
    required String socialPlatform,
    String mediaFormat = 'image',
    required String externalUrl,
    String? body,
    String? productId,
    int reachCount = 0,
    int likesCount = 0,
    int commentsCount = 0,
    int sharesCount = 0,
    int inquiriesCount = 0,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Pengguna belum terautentikasi');

    final response = await supabase
        .from('store_contents')
        .insert({
          'store_id': storeId,
          'created_by': userId,
          'title': title,
          'content_type': contentType,
          'social_platform': socialPlatform,
          'media_format': mediaFormat,
          'external_url': externalUrl,
          'body': body,
          'media_urls': <String>[],
          'product_id': productId,
          'is_active': true,
          'reach_count': reachCount,
          'likes_count': likesCount,
          'comments_count': commentsCount,
          'shares_count': sharesCount,
          'inquiries_count': inquiriesCount,
        })
        .select()
        .single();

    final newContent = StoreContentModel.fromMap(response);

    await logActivity(
      storeId: storeId,
      actionType: 'create_content',
      title: 'Membuat Konten: $title',
      description:
          'Asisten UMK mencatat konten ${newContent.contentTypeLabel} (${newContent.mediaFormatLabel}) di ${newContent.socialPlatformLabel}',
      metadata: {
        'content_id': newContent.id,
        'content_type': contentType,
        'media_format': mediaFormat,
        'social_platform': socialPlatform,
        'external_url': externalUrl,
        'reach_count': reachCount,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'shares_count': sharesCount,
        'inquiries_count': inquiriesCount,
      },
    );

    return newContent;
  }

  Future<void> updateStoreContent({
    required String contentId,
    required String storeId,
    required String title,
    required String contentType,
    required String socialPlatform,
    String mediaFormat = 'image',
    required String externalUrl,
    String? body,
    String? productId,
    int reachCount = 0,
    int likesCount = 0,
    int commentsCount = 0,
    int sharesCount = 0,
    int inquiriesCount = 0,
  }) async {
    await supabase
        .from('store_contents')
        .update({
          'title': title,
          'content_type': contentType,
          'social_platform': socialPlatform,
          'media_format': mediaFormat,
          'external_url': externalUrl,
          'body': body,
          'product_id': productId,
          'is_active': true,
          'reach_count': reachCount,
          'likes_count': likesCount,
          'comments_count': commentsCount,
          'shares_count': sharesCount,
          'inquiries_count': inquiriesCount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', contentId);

    await logActivity(
      storeId: storeId,
      actionType: 'update_content',
      title: 'Memperbarui Konten: $title',
      description:
          'Asisten UMK memperbarui konten & engagement di $socialPlatform ($mediaFormat)',
      metadata: {
        'content_id': contentId,
        'media_format': mediaFormat,
        'social_platform': socialPlatform,
        'external_url': externalUrl,
        'reach_count': reachCount,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'shares_count': sharesCount,
        'inquiries_count': inquiriesCount,
      },
    );
  }

  Future<void> deleteStoreContent({
    required String contentId,
    required String storeId,
    required String title,
  }) async {
    await supabase.from('store_contents').delete().eq('id', contentId);

    await logActivity(
      storeId: storeId,
      actionType: 'update_content',
      title: 'Menghapus Konten: $title',
      description: 'Asisten UMK menghapus konten toko',
      metadata: {'content_id': contentId},
    );
  }
}
