import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/address/models/address_model.dart';

class AddressService {
  Future<List<AddressModel>> getAddresses() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await supabase
        .from('addresses')
        .select('id, recipient_name, recipient_phone, full_address, is_default')
        .eq('user_id', user.id)
        .order('is_default', ascending: false);

    return response
        .map<AddressModel>((item) => AddressModel.fromMap(item))
        .toList();
  }
}
