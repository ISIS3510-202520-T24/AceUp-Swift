# 🎉 Eventos Uniandes - Guía Rápida

## ✅ ¿Qué se implementó?

Se creó una **nueva pestaña completa** para ver eventos de la Universidad de los Andes con las siguientes características:

### 📱 Funcionalidades Principales

1. **Vista de Eventos**
   - Lista de eventos universitarios con diseño nativo
   - Categorías: Académico, Institucional, Cultural, Deportivo, Social
   - Filtros por categoría, fecha y búsqueda
   - Pestañas: Próximos, Hoy, Favoritos, Guardados

2. **Acciones Disponibles**
   - ⭐ **Favoritos**: Marca eventos importantes
   - 🔖 **Guardar**: Guarda para revisar después
   - 📅 **Calendario**: Agrega al calendario de iOS
   - ✅ **Inscripción**: Abre navegador para inscribirte
   - 📤 **Compartir**: Comparte el evento

3. **Modo Offline**
   - Caché de 1 hora
   - Funciona sin internet con datos guardados
   - Actualización automática cuando hay conexión

4. **Vista de Detalle**
   - Información completa del evento
   - Fecha, hora, ubicación, descripción
   - Organizador y capacidad
   - Etiquetas y categorización

## 🚀 Cómo Usar

### Acceder a Eventos
1. Abre la app AceUp
2. Toca el menú (☰) arriba a la izquierda
3. En la sección **"Universidad"**, selecciona **"Eventos Uniandes"**

### Buscar Eventos
- Usa la barra de búsqueda en la parte superior
- Filtra por categoría tocando los chips de colores
- Cambia entre las pestañas (Próximos, Hoy, Favoritos, Guardados)

### Gestionar Eventos
- **Marcar como favorito**: Toca la ⭐ en la tarjeta del evento
- **Guardar para después**: Toca el 🔖
- **Ver detalle**: Toca cualquier evento para ver más información
- **Agregar al calendario**: En el detalle, toca 📅
- **Inscribirse**: En el detalle, toca el botón "Inscribirse"

### Actualizar Eventos
- Desliza hacia abajo (pull to refresh) en la lista de eventos
- Se actualizarán automáticamente cada hora

## 🎨 Interfaz

### Colores por Categoría
- 🟢 **Académico**: Turquesa
- 🟡 **Institucional**: Amarillo
- 🔴 **Cultural**: Rojo
- 🟦 **Deportivo**: Verde agua
- 🟩 **Social**: Verde claro

### Indicadores de Estado
- **⚪ Inscrito**: Badge verde con checkmark
- **🟠 Hoy**: Badge naranja con reloj
- **⏰ Próximo**: Muestra días restantes

## ⚙️ Configuración

### Permisos
La app solicitará permiso para acceder al calendario la primera vez que intentes agregar un evento.

### Datos
- Los eventos se actualizan del servidor cada hora
- Los favoritos y guardados se almacenan localmente
- Funciona offline con datos en caché

## 📝 Notas Importantes

### Datos Mock (Por Ahora)
**IMPORTANTE**: Actualmente la app muestra **datos de ejemplo** porque la página web de eventos de Uniandes usa JavaScript dinámico que es complejo de parsear.

Para implementar scraping real, tienes 3 opciones:

1. **Implementar parser HTML** (complejo)
   - Usa la librería SwiftSoup
   - Actualiza el método `scrapeEvents()` en `UniandesEventsService.swift`

2. **Crear un backend** (recomendado)
   - Backend simple en Node.js/Python/Go
   - Hace el scraping y expone API REST
   - La app consume la API
   - Más confiable y mantenible

3. **API oficial de Eventtia**
   - Contacta a Uniandes IT
   - Pregunta si hay acceso a API de Eventtia
   - Mejor opción si existe

### Archivos para Modificar

Para implementar scraping real, edita:
```
AceUP-Swift/Services/UniandesEventsService.swift
  → Método: scrapeEvents()
  → Método: parseEvents(from:)
```

Consulta `WebScrapingHelper.swift` para ejemplos y guías.

## 🐛 Limitaciones Actuales

1. **Datos Mock**: Los eventos son de ejemplo, no reales
2. **Imágenes**: No se muestran imágenes de eventos (usa gradients de color)
3. **Inscripción**: Solo marca como inscrito localmente (no hace registro real)
4. **Sincronización**: Favoritos no se sincronizan entre dispositivos

## 🔮 Próximos Pasos Sugeridos

### Corto Plazo (1-2 semanas)
- [ ] Implementar scraping real o backend proxy
- [ ] Descargar y mostrar imágenes de eventos
- [ ] Mejorar parser de fechas y horas

### Mediano Plazo (1 mes)
- [ ] Notificaciones para eventos favoritos
- [ ] Sincronización con Firebase
- [ ] Widget de eventos próximos
- [ ] Integración con calendario compartido

### Largo Plazo (2-3 meses)
- [ ] Recomendaciones con ML
- [ ] Mapa de ubicaciones
- [ ] Check-in con QR codes
- [ ] Analytics de participación

## 📚 Documentación

- **Documentación completa**: Ver `EVENTOS_README.md`
- **Web scraping helpers**: Ver `Services/WebScrapingHelper.swift`
- **Código fuente**:
  - Modelos: `Models/UniandesEvent.swift`
  - Servicio: `Services/UniandesEventsService.swift`
  - ViewModel: `ViewModels/UniandesEventsViewModel.swift`
  - Vistas: `Views/UniandesEventsView.swift`, `Views/EventDetailView.swift`

## 🤝 Soporte

Para preguntas o problemas:
1. Revisa la documentación completa en `EVENTOS_README.md`
2. Inspecciona los comentarios en el código
3. Consulta `WebScrapingHelper.swift` para guías de implementación

## 🎯 Resumen

Has implementado exitosamente una funcionalidad completa de eventos con:
- ✅ UI nativa hermosa
- ✅ Filtros y búsqueda
- ✅ Favoritos y guardados
- ✅ Integración con calendario iOS
- ✅ Modo offline con caché
- ✅ Vista de detalle completa
- ✅ Categorización por colores
- ✅ Pull to refresh

**Lo único que falta es conectar con datos reales**, lo cual puedes hacer siguiendo las guías en `EVENTOS_README.md` y `WebScrapingHelper.swift`.

¡Disfruta tu nueva funcionalidad de eventos! 🎊
