# Eventos Uniandes - Documentación

## 📋 Descripción General

Esta funcionalidad permite a los usuarios de AceUp ver, filtrar, guardar y gestionar eventos de la Universidad de los Andes obtenidos de https://eventos.uniandes.edu.co/

## 🎯 Características Principales

### 1. **Visualización de Eventos**
- Lista completa de eventos universitarios
- Categorización por tipo: Académico, Institucional, Cultural, Deportivo, Social
- Vista detallada con toda la información del evento
- Diseño nativo iOS (no es un WebView)

### 2. **Filtros y Búsqueda**
- **Búsqueda por texto**: Busca en título, descripción y organizador
- **Filtro por categoría**: Filtra eventos por tipo
- **Filtro por fecha**: Próximos, Hoy, Pasados, Todos
- **Filtros especiales**: Solo favoritos, Solo guardados

### 3. **Gestión Personal**
- **⭐ Favoritos**: Marca eventos como favoritos
- **🔖 Guardar para después**: Guarda eventos sin inscribirte aún
- **✅ Inscripción**: Registro en eventos (abre navegador SSO)
- **📅 Agregar al calendario**: Integración con Calendar.app de iOS

### 4. **Modo Offline**
- **Caché inteligente**: Los eventos se guardan localmente por 1 hora
- **Funcionamiento offline**: Muestra eventos del caché cuando no hay internet
- **Sincronización automática**: Actualiza eventos cuando hay conexión

### 5. **Detalles de Eventos**
- Fecha y hora de inicio/fin
- Ubicación del evento
- Descripción completa
- Organizador
- Capacidad (cuando aplica)
- Etiquetas relacionadas
- Indicadores de estado (inscrito, hoy, próximo)

## 🏗️ Arquitectura

### Archivos Principales

```
Models/
  └── UniandesEvent.swift          # Modelos de datos

Services/
  └── UniandesEventsService.swift  # Lógica de negocio y caché

ViewModels/
  └── UniandesEventsViewModel.swift # Estado y lógica de UI

Views/
  ├── UniandesEventsView.swift     # Vista principal de lista
  └── EventDetailView.swift        # Vista de detalle
```

### Flujo de Datos

```
Web (eventos.uniandes.edu.co)
    ↓
UniandesEventsService
    ├── Scraping/Parsing
    ├── Caché Local (UserDefaults)
    └── Preferencias de Usuario
    ↓
UniandesEventsViewModel
    ├── Filtros
    ├── Búsqueda
    └── Estado UI
    ↓
UniandesEventsView / EventDetailView
```

## 🔧 Implementación Técnica

### Caché de Datos
- **Duración**: 1 hora por defecto
- **Almacenamiento**: UserDefaults con JSONEncoder
- **Estrategia**: Cache-first con fallback a datos expirados
- **Claves**:
  - `uniandes_events_cache` - Eventos
  - `uniandes_events_preferences` - Preferencias de usuario

### Caché de Imágenes
- **Sistema de caché de dos niveles**:
  - **Memoria (NSCache)**: Límite de 100 imágenes / 50 MB
  - **Disco**: Almacenamiento persistente en `Caches/EventImages/`
- **Descarga asíncrona**: No bloquea la UI
- **Fallback automático**: Muestra gradiente si falla la descarga
- **Componente**: `CachedAsyncImage` para uso en SwiftUI
- **Limpieza**: Método `clearCache()` disponible

### Modelos de Datos

```swift
struct UniandesEvent {
    let id: String
    let title: String
    let category: EventCategory
    let startDate: Date
    let endDate: Date
    let location: String?
    var isFavorite: Bool
    var savedForLater: Bool
    var isRegistered: Bool
    // ... más campos
}

enum EventCategory {
    case academic, institutional, cultural, sports, social, other
}
```

### Preferencias de Usuario

```swift
struct EventUserPreferences {
    var favoriteEventIds: Set<String>
    var savedEventIds: Set<String>
    var registeredEventIds: Set<String>
    var notificationSettings: EventNotificationSettings
}
```

## 📱 Uso

### Navegación
1. Abre el menú lateral (☰)
2. En la sección "Universidad", selecciona "Eventos Uniandes"

### Acciones Disponibles

#### Vista de Lista
- **Buscar**: Escribe en la barra de búsqueda
- **Filtrar**: Toca el icono de filtros o las categorías
- **Cambiar pestaña**: Próximos / Hoy / Favoritos / Guardados
- **Pull to refresh**: Desliza hacia abajo para actualizar
- **Favorito**: Toca la estrella ⭐
- **Guardar**: Toca el marcador 🔖

#### Vista de Detalle
- **⭐ Marcar favorito**: Guarda en favoritos
- **🔖 Guardar**: Guarda para ver después
- **📅 Agregar al calendario**: Agrega evento a Calendar.app
- **📤 Compartir**: Comparte el enlace del evento
- **✅ Inscribirse**: Abre navegador para inscripción SSO
- **🌐 Ver en navegador**: Abre página completa del evento

## 🔄 Sincronización y Caché

### Estrategia de Caché
1. **Primera carga**: Obtiene eventos del servidor
2. **Cargas subsecuentes**: Usa caché si está vigente (< 1 hora)
3. **Force refresh**: Pull-to-refresh ignora el caché
4. **Sin conexión**: Usa caché expirado si no hay internet

### Actualización de Datos
```swift
// Automática
await viewModel.loadEvents()  // Usa caché si está vigente

// Forzada
await viewModel.refreshEvents()  // Ignora caché
```

## 🎨 UI/UX

### Componentes Personalizados
- **EventCard**: Tarjeta de evento con acciones rápidas
- **CategoryChip**: Filtro de categoría visual
- **TabButton**: Pestañas con contador
- **InfoRow**: Fila de información con icono
- **FlowLayout**: Layout flexible para etiquetas

### Colores por Categoría
- 🟢 Académico: `#4ECDC4`
- 🟡 Institucional: `#FFE66D`
- 🔴 Cultural: `#FF6B6B`
- 🟦 Deportivo: `#95E1D3`
- 🟩 Social: `#A8E6CF`
- ⚪ Otro: `#B8B8B8`

## 🚀 Mejoras Futuras

### Corto Plazo
- [ ] Mejorar parser HTML (usar librería como SwiftSoup)
- [ ] Notificaciones push para eventos favoritos
- [ ] Sincronización con Firebase para compartir entre dispositivos
- [ ] Widget de eventos próximos

### Mediano Plazo
- [ ] Integración con Google Calendar / Outlook
- [ ] Recordatorios personalizados
- [ ] Mapa de ubicaciones de eventos
- [ ] Filtro por facultad/departamento
- [ ] Compartir eventos con grupos del calendario compartido

### Largo Plazo
- [ ] Machine Learning para recomendaciones
- [ ] Integración con sistema de inscripción automatizado
- [ ] QR codes para check-in en eventos
- [ ] Analytics de asistencia y participación

## 🐛 Limitaciones Conocidas

1. **Web Scraping**: 
   - La página usa Eventtia que carga contenido dinámicamente
   - Por ahora se usan datos mock para desarrollo
   - Se necesita implementar un parser HTML más robusto

2. **Inscripción**:
   - Solo marca localmente como "inscrito"
   - La inscripción real requiere SSO de Uniandes
   - Se abre navegador externo para completar registro

3. **Imágenes**:
   - Las imágenes de eventos no se están descargando
   - Se usa gradient de color según categoría

4. **Sincronización**:
   - Los favoritos/guardados solo se guardan localmente
   - No hay sincronización entre dispositivos (todavía)

## 📝 Notas de Desarrollo

### Dependencias
- **EventKit**: Para agregar eventos al calendario
- **SafariServices**: Para abrir URLs en navegador in-app

### Permisos Requeridos
```xml
<key>NSCalendarsUsageDescription</key>
<string>AceUp necesita acceso a tu calendario para agregar eventos de la universidad.</string>
```

### Testing
```swift
// Mock Service para testing
let mockService = UniandesEventsService()
await mockService.fetchEvents() // Retorna datos mock
```

## 🤝 Contribuir

Para mejorar el scraping de eventos:

1. Inspecciona la estructura HTML de https://eventos.uniandes.edu.co/
2. Actualiza `parseEvents(from:)` en `UniandesEventsService.swift`
3. Considera usar una librería como SwiftSoup para parsing más robusto
4. Testea con diferentes tipos de eventos

## 📚 Referencias

- [Eventos Uniandes](https://eventos.uniandes.edu.co/)
- [Eventtia Platform](https://www.eventtia.com/)
- [Apple EventKit Documentation](https://developer.apple.com/documentation/eventkit)
- [SwiftUI Layout Documentation](https://developer.apple.com/documentation/swiftui/layout)
