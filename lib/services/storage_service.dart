    import 'package:hive_flutter/hive_flutter.dart';
    import '../models/evaluation.dart';

    class StorageService {
    static Box<Evaluation> get _box => Hive.box<Evaluation>('evaluations');
    static Box get _settings => Hive.box('settings');

    static List<Evaluation> getAll() =>
        _box.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    static void save(Evaluation e) => _box.put(e.id, e);
    static void delete(String id) => _box.delete(id);
    static Evaluation? getById(String id) => _box.get(id);

    // NOTA DE SEGURIDAD: la clave de API ya NO se guarda en texto plano acá.
    // El almacenamiento canónico es `SecureStorageService` (Keystore/Keychain).
    // Se deja `clearLegacyApiKey()` solo para limpiar instalaciones viejas
    // que pudieran tener la clave persistida en Hive sin cifrar.
    static void clearLegacyApiKey() {
      if (_settings.containsKey('apiKey')) _settings.delete('apiKey');
    }

    static int get hoursPerDay =>
        _settings.get('hoursPerDay', defaultValue: 2) as int;
    static void setHoursPerDay(int h) => _settings.put('hoursPerDay', h);
    }