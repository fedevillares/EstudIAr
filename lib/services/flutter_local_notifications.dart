// Este archivo quedó como implementación alternativa/abandonada de
// notificaciones (envolvía directamente flutter_local_notifications).
// El servicio activo y usado en toda la app es `notification_service.dart`
// (NotificationService con scheduleReminder()/cancelAll() como TODO).
//
// Se vacía el contenido para eliminar la clase `NotificationService`
// duplicada (mismo nombre que en notification_service.dart), lo cual
// rompería la compilación si algún archivo llegara a importar ambos.
// Nadie importa este archivo actualmente (verificado), así que no hace
// falta mantener un re-export.
//
// TODO: si se decide implementar notificaciones reales con el plugin
// flutter_local_notifications, integrar esa lógica DENTRO de
// notification_service.dart en vez de reactivar este archivo.
