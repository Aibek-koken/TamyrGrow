# Техническая спецификация: Tamyr Frontend (Flutter Mobile App)

Этот документ описывает **полную и актуальную реализацию** мобильного клиента Tamyr в `frontend/`. Описывает архитектуру, состояние компонентов, интеграцию с API, и контракт с бэкендом.

---

## 1. Назначение и границы

### 1.1. Назначение

**Tamyr Frontend** — мобильное приложение на Flutter для управления гидропонной установкой через UI.

Функциональность:

- 📊 **Dashboard**: дашборд со статусами всех полок (traffic-light view)
- 🎮 **Control**: ручное управление устройствами полки (свет, вентилятор, температура) или включение AI автопилота
- 📈 **Analytics**: историческая аналитика (графики температуры, влажности, CO₂, TVOC, VPD gauge)
- 🤖 **AI Assistant**: чат-интерфейс с агрономом-AI по текущей полке

### 1.2. В зоне ответственности (реализовано)

- ✅ **UI/UX**: 4 экрана с bottom navigation
- ✅ **State management**: Provider-based (in-memory)
- ✅ **Network layer**: Dio HTTP client + WebSocket support
- ✅ **Обработка ошибок**: loading / error / empty states
- ✅ **Real-time интеграция**: WebSocket подписка на live сенсор-логи
- ✅ **Валидация**: базовая валидация пользовательского ввода

### 1.3. Вне зоны ответственности (не реализовано)

- ❌ **Аутентификация** (нет login, все полки доступны)
- ❌ **Локальное хранилище** (нет SharedPreferences для сохранения конфига/токенов)
- ❌ **Offline-first** (требуется интернет)
- ❌ **Push уведомления** (нет Firebase Cloud Messaging)
- ❌ **Мульти-инстанс** (нельзя переключаться между API сервисами из UI)

---

## 2. Технологический стек

| Компонент | Назначение | Версия |
|-----------|-----------|--------|
| **Flutter SDK** | Mobile framework | >=3.4.0 <4.0.0 |
| **Dart** | Язык программирования | Встроен в Flutter |
| **dio** | HTTP клиент | ^5.7.0 |
| **provider** | State management | ^6.1.2 |
| **web_socket_channel** | WebSocket клиент | ^3.0.3 |
| **google_fonts** | Типографика | ^6.2.1 |
| **intl** | Форматирование времени/locales | ^0.19.0 |
| **fl_chart** | Графики (Line, Bar) | ^0.68.0 |
| **syncfusion_flutter_gauges** | VPD gauge (radial) | ^26.2.14 |

---

---

## 3. Архитектура и структура кода (факт)

**Декомпозиция**: по фичам (features) + общий слой (core).

```text
frontend/lib/
  main.dart                          # Entry point, MultiProvider setup
  app.dart                           # Главное приложение (MaterialApp)
  
  core/
    network/
      api_service.dart               # Dio-based HTTP + WS client
    theme/
      app_theme.dart                 # Material Theme (colors, typography)
  
  features/
    shell/
      presentation/
        app_shell.dart               # IndexedStack + BottomNavigationBar
        
    dashboard/
      models/
        dashboard_summary.dart       # DTO: { shelves: [...] }
        shelf.dart                   # DTO: { id, name, status }
        shelf_current.dart           # DTO: { shelf, latest_sensor, device_state, vpd }
        device_state.dart            # DTO: { shelf_id, light_brightness, ... }
        sensor_log.dart              # DTO: { id, shelf_id, temp, humidity, co2, ... }
      presentation/
        dashboard_screen.dart        # UI: ShelfStatusCard list
        widgets/                     # Reusable dashboard widgets
      state/
        dashboard_provider.dart      # ChangeNotifier: load(), selectShelf()
        
    control/
      presentation/
        control_screen.dart          # UI: слайдеры, toggle AI mode, кнопки
      state/
        control_provider.dart        # ChangeNotifier: updateDevice()
        
    analytics/
      presentation/
        analytics_screen.dart        # UI: VPD gauge, графики T/H/CO2/TVOC
      state/
        live_analytics_provider.dart # ChangeNotifier: load logs, start WS listener
        
    assistant/
      models/
        chat_message.dart            # DTO: { role, content }
      presentation/
        assistant_screen.dart        # UI: chat bubbles, text input
      state/
        assistant_provider.dart      # ChangeNotifier: sendMessage(), messages list
```

### Принципы

1. **Features-first**: каждая фича (dashboard, control, etc.) инкапсулирует:
   - UI (`presentation/`)
   - State (`state/` с ChangeNotifier)
   - Data models (`models/`)
   
2. **Shared core**: common сетевой слой, тема в `core/`

3. **Provider DI**: все провайдеры регистрируются в `main.dart`

---

## 3. Архитектура и структура кода (факт)

```text
frontend/lib/
  main.dart                          # Entry point, MultiProvider setup
  app.dart                           # Главное приложение (MaterialApp)
  
  core/
    network/
      api_service.dart               # Dio-based HTTP + WS client
    theme/
      app_theme.dart                 # Material Theme (colors, typography)
  
  features/
    shell/
      presentation/
        app_shell.dart               # IndexedStack + BottomNavigationBar
        
    dashboard/
      models/
        dashboard_summary.dart       # DTO: { shelves: [...] }
        shelf.dart                   # DTO: { id, name, status }
        shelf_current.dart           # DTO: { shelf, latest_sensor, device_state, vpd }
        device_state.dart            # DTO: { shelf_id, light_brightness, ... }
        sensor_log.dart              # DTO: { id, shelf_id, temp, humidity, co2, ... }
      presentation/
        dashboard_screen.dart        # UI: ShelfStatusCard list
        widgets/                     # Reusable dashboard widgets
      state/
        dashboard_provider.dart      # ChangeNotifier: load(), selectShelf()
        
    control/
      presentation/
        control_screen.dart          # UI: слайдеры, toggle AI mode, кнопки
      state/
        control_provider.dart        # ChangeNotifier: updateDevice()
        
    analytics/
      presentation/
        analytics_screen.dart        # UI: VPD gauge, графики T/H/CO2/TVOC
      state/
        live_analytics_provider.dart # ChangeNotifier: load logs, start WS listener
        
    assistant/
      models/
        chat_message.dart            # DTO: { role, content }
      presentation/
        assistant_screen.dart        # UI: chat bubbles, text input
      state/
        assistant_provider.dart      # ChangeNotifier: sendMessage(), messages list
```

### Принципы

1. **Features-first**: каждая фича (dashboard, control, etc.) инкапсулирует:
   - UI (`presentation/`)
   - State (`state/` с ChangeNotifier)
   - Data models (`models/`)
   
2. **Shared core**: common сетевой слой, тема в `core/`

3. **Provider DI**: все провайдеры регистрируются в `main.dart`

---

## 4. Состояние и управление (Provider)

### 4.1. MultiProvider в main.dart

```dart
MultiProvider(
  providers: [
    // Синглтон API
    Provider<ApiService>.value(value: api),
    
    // Dashboard: загружает summary и кеширует current по каждой полке
    ChangeNotifierProvider<DashboardProvider>(
      create: (context) => DashboardProvider(
        api: context.read<ApiService>(),
      )..load(),
    ),
    
    // LiveAnalytics: параллельно загружает logs и подписывается на WS
    ChangeNotifierProvider<LiveAnalyticsProvider>(
      create: (context) => LiveAnalyticsProvider(
        api: context.read<ApiService>(),
        dashboard: context.read<DashboardProvider>(),
      )..start(),
    ),
    
    // Control: управление выбранной полкой
    ChangeNotifierProvider<ControlProvider>(
      create: (context) => ControlProvider(
        api: context.read<ApiService>(),
        shelfId: 1,  // можно сделать dynamic
      )..load(),
    ),
    
    // Assistant: чат-сессия
    ChangeNotifierProvider<AssistantProvider>(
      create: (context) => AssistantProvider(
        api: context.read<ApiService>(),
      ),
    ),
  ],
  child: const SmartHydroponicsApp(),
)
```

### 4.2. Основные провайдеры

#### DashboardProvider (sync point)

```dart
class DashboardProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  DashboardSummary? summary;
  Map<int, ShelfCurrent> currentByShelfId = {};
  int? selectedShelfId;  // ← глобально выбранная полка
  
  Future<void> load() async { /* GET /dashboard/summary */ }
  void selectShelf(int shelfId) { /* notifyListeners */ }
  void applyLiveSensorLog(SensorLog log) { /* обновить currentByShelfId */ }
}
```

**Роль**: главный hub; все остальные провайдеры следят за `selectedShelfId`.

#### ControlProvider

```dart
class ControlProvider extends ChangeNotifier {
  int shelfId;
  DeviceState? deviceState;
  bool isLoading = false;
  String? error;
  
  Future<void> load() async { /* GET /shelves/{shelfId}/current */ }
  Future<void> updateDeviceState({
    int? lightBrightness,
    int? fanSpeed,
    bool? isAiMode,
    // ...
  }) async { /* PATCH /shelves/{shelfId}/control */ }
}
```

#### LiveAnalyticsProvider

```dart
class LiveAnalyticsProvider extends ChangeNotifier {
  List<SensorLog> sensorLogs = [];
  bool isLoading = false;
  String? error;
  WebSocketChannel? wsChannel;
  
  Future<void> load() async { /* GET /shelves/{shelfId}/logs */ }
  void start() { /* подписаться на WS */ }
  void _onWsMessage(dynamic message) { /* парсить JSON */ }
}
```

#### AssistantProvider

```dart
class AssistantProvider extends ChangeNotifier {
  List<ChatMessage> messages = [];
  bool isLoading = false;
  String? error;
  
  Future<void> sendMessage(int shelfId, String text) async {
    /* POST /assistant/chat */
  }
}
```

---

## 5. Навигация и экраны

### 5.1. AppShell (Bottom Navigation)

**Файл**: `features/shell/presentation/app_shell.dart`

Главная навигация через `IndexedStack` + `BottomNavigationBar`:

```
┌─────────────────────────────┐
│      IndexedStack           │
│   (4 экрана в памяти)       │
├─────────────────────────────┤
│   [📊] [🎮] [📈] [🤖]      │
│  Dashboard Control Analytics Assistant │
└─────────────────────────────┘
```

- Переключение вкладок — индекс в IndexedStack
- Все экраны остаются в памяти (не перестраиваются)

### 5.2. Dashboard Screen

**Файл**: `features/dashboard/presentation/dashboard_screen.dart`

UI:
- **Header**: "Tamyr - Hydroponics Control"
- **Body**: ScrollableListView карточек `ShelfStatusCard`
- **Карточка**:
  - Имя полки, статус (OK/WARNING/CRITICAL)
  - Текущие показания T/H (если загружены)
  - OnTap → `selectShelf()` и перейти на Control/Assistant

Состояния:
- Loading: `CircularProgressIndicator`
- Error: Text + Retry кнопка
- Empty: "No shelves found"
- Success: список полок

### 5.3. Control Screen

**Файл**: `features/control/presentation/control_screen.dart`

Управление выбранной полкой:

```
┌─────────────────────────────┐
│ Shelf A - Manual Control    │
├─────────────────────────────┤
│ 🤖 AI Autopilot             │
│    [Disabled] → [Enabled]   │
│                             │
│ Light (0-100%)              │
│ ▰▱▱▱ 30% 🕯               │
│                             │
│ Fan (Low/Med/High)          │
│ [Low] [Med] [High]         │
│                             │
│ Temperature (16-30°C)       │
│ ▰▱▱▱ 22°C 🌡              │
│                             │
│ 🚨 Emergency Stop           │
├─────────────────────────────┤
│ Live: T=24.5°C H=65%       │
└─────────────────────────────┘
```

Логика:
- **Manual mode** (`is_ai_mode=false`): слайдеры активны
- **AI mode** (`is_ai_mode=true`): слайдеры заблокированы (`AbsorbPointer`), только переключатель AI работает
- Ошибка 409 → snackbar "AI mode blocks manual control"

### 5.4. Analytics Screen

**Файл**: `features/analytics/presentation/analytics_screen.dart`

```
┌─────────────────────────────┐
│ Select Shelf: [Shelf A ▼]  │
├─────────────────────────────┤
│ VPD Status                  │
│  ╭─────────╮                │
│  │  1.23   │ kPa           │
│  │ (Ideal) │  🟢            │
│  ╰─────────╯                │
│ (RadialGauge via Syncfusion) │
│                             │
│ Temperature & Humidity      │
│ (LineChart: 2 lines, 240pts) │
│                             │
│ CO₂ & TVOC                  │
│ (LineChart: 2 lines, 240pts) │
└─────────────────────────────┘
```

Логика:
- Параллельная загрузка: `current` + `logs` (limit=240)
- VPD на клиенте (gauge с color zones)
- Графики от старых к новым (по временной метке)

### 5.5. Assistant Screen

**Файл**: `features/assistant/presentation/assistant_screen.dart`

```
┌─────────────────────────────┐
│ AI Agronomist - Shelf A     │
├─────────────────────────────┤
│ Assistantавт: Hello!        │
│                             │
│ You: Why is VPD high?       │
│                             │
│ Assistant: ... [full reply] │
│ (typing bubble if loading) │
│                             │
├─────────────────────────────┤
│ [TextField input] [Send]   │
└─────────────────────────────┘
```

Логика:
- Если полка не выбрана → "Load Dashboard first"
- TextInput + Send button
- Отправка → POST /assistant/chat
- Сообщения добавляются в `messages` list
- Typing bubble во время загрузки

---

## 6. Сетевой слой и API контракт

### 6.1. ApiService

**Файл**: `core/network/api_service.dart`

| Метод | HTTP | URL | DTO |
|-------|------|-----|-----|
| `getDashboardSummary()` | GET | /dashboard/summary | DashboardSummary |
| `getShelfCurrent(id)` | GET | /shelves/{id}/current | ShelfCurrent |
| `getShelfSensorLogs(id, limit)` | GET | /shelves/{id}/logs?limit=X | List<SensorLog> |
| `updateDeviceState(id, ...)` | PATCH | /shelves/{id}/control | DeviceState |
| `chatWithAi(id, message)` | POST | /assistant/chat | String |
| `buildWsUri(path)` | - | Конвертер HTTP→WS | Uri |

### 6.2. WebSocket

**Метод**: `buildWsUri(path)` + `web_socket_channel`

```dart
// "http://10.0.2.2:8000" + "/ws/shelves/1/sensors"
// → "ws://10.0.2.2:8000/ws/shelves/1/sensors"

final uri = api.buildWsUri('/ws/shelves/$shelfId/sensors');
final channel = WebSocketChannel.connect(uri);
channel.stream.listen((msg) {
  // Handle incoming SensorLog
});
```

### 6.3. Base URL конфигурация

**Default**: `http://10.0.2.2:8000` (Android emulator localhost)

Для реального устройства нужно изменить на IP машины с бэкендом.

**TODO**: конфигурируемый URL через `--dart-define` или Settings экран.

### 6.4. Обработка ошибок API

Фронтенд ожидает FastAPI стандартный формат:

```json
{ "detail": "Shelf 1 not found." }
```

Специальная обработка:
- **503** (Groq не настроен): show dialog "GROQ_API_KEY not set"
- **401** (неверный ключ): show dialog с ссылкой на Groq console
- **409** (AI mode): snackbar "Manual control disabled"

---

## 7. Data Models (DTOs)

Все модели находятся в `features/*/models/` и deserialize из JSON:

### Shelf

```dart
class Shelf {
  final int id;
  final String name;
  final String status;  // "OK", "WARNING", "CRITICAL"
  
  factory Shelf.fromJson(Map<String, dynamic> json) => Shelf(
    id: json['id'],
    name: json['name'],
    status: json['status'],
  );
}
```

### SensorLog

```dart
class SensorLog {
  final int id;
  final int shelfId;
  final double temperature;      // °C
  final double humidity;         // %
  final int co2;                 // ppm
  final int tvoc;                // ppb или индекс
  final DateTime timestamp;
  
  factory SensorLog.fromJson(Map<String, dynamic> json) => SensorLog(
    id: json['id'],
    shelfId: json['shelf_id'],
    temperature: (json['temperature'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    co2: json['co2'] as int,
    tvoc: json['tvoc'] as int,
    timestamp: DateTime.parse(json['timestamp']),
  );
}
```

### DeviceState

```dart
class DeviceState {
  final int shelfId;
  final int lightBrightness;      // 0-100 %
  final int fanSpeed;             // 0-100 %
  final double targetTemperature; // °C
  final bool heaterOn;
  final bool humidifierOn;
  final bool isAiMode;
  
  factory DeviceState.fromJson(Map<String, dynamic> json) => DeviceState(
    shelfId: json['shelf_id'],
    lightBrightness: json['light_brightness'] as int,
    fanSpeed: json['fan_speed'] as int,
    targetTemperature: (json['target_temperature'] as num).toDouble(),
    heaterOn: json['heater_on'] as bool,
    humidifierOn: json['humidifier_on'] as bool,
    isAiMode: json['is_ai_mode'] as bool,
  );
}
```

### ShelfCurrent

```dart
class ShelfCurrent {
  final Shelf shelf;
  final SensorLog? latestSensor;
  final DeviceState? deviceState;
  final double? vpd;              // kPa
  
  factory ShelfCurrent.fromJson(Map<String, dynamic> json) => ShelfCurrent(
    shelf: Shelf.fromJson(json['shelf']),
    latestSensor: json['latest_sensor'] != null
      ? SensorLog.fromJson(json['latest_sensor'])
      : null,
    deviceState: json['device_state'] != null
      ? DeviceState.fromJson(json['device_state'])
      : null,
    vpd: (json['vpd'] as num?)?.toDouble(),
  );
}
```

### DashboardSummary

```dart
class DashboardSummary {
  final List<Shelf> shelves;
  
  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
    shelves: (json['shelves'] as List)
      .map((e) => Shelf.fromJson(e))
      .toList(),
  );
}
```

---

## 8. Helper Functions и Utilities

Фронтенд ожидает типичный формат FastAPI:

- ошибки приходят как JSON с полем `detail` (строка) или списком ошибок валидации.

Для AI ассистента `AssistantProvider` имеет отдельную обработку:

- **503**: отсутствие `GROQ_API_KEY` на сервере — показывается подсказка, как настроить ключ.
- **401**: неверный ключ Groq — показывается подсказка, где создать правильный ключ (`gsk_...`).
- **429/502**: показываются дружелюбные сообщения.

---

## 8. Helper Functions и Utilities

### VPD Gauge Colors

```dart
Color getVpdGaugeColor(double vpd) {
  if (vpd < 0.8) return Colors.orange;      // Low
  if (vpd <= 1.3) return Colors.green;      // Ideal
  if (vpd <= 1.5) return Colors.yellow;     // High
  return Colors.red;                        // Critical
}
```

### Date Formatting

```dart
import 'package:intl/intl.dart';

// "2026-04-28T10:30:00Z" → "Apr 28, 10:30 AM"
String formatSensorTimestamp(DateTime dt) {
  return DateFormat('MMM dd, hh:mm a').format(dt);
}
```

---

## 9. Обработка ошибок и UX-состояния

Текущие паттерны (по экранным реализациям):

- **Loading**: `CircularProgressIndicator` / typing bubble
- **Error**: строка ошибки в UI + Retry (Dashboard, Analytics); в Control показ ошибки под переключателем
- **Empty**: отдельное состояние на Dashboard/Analytics при отсутствии данных
- **409 Conflict** (AI mode): snackbar "Manual control blocked by AI mode"
- **503/401** (Groq): контекстная подсказка с инструкциями

---

## 10. Сборка и запуск

### 10.1. Предусловия

- Flutter SDK: >=3.4.0 <4.0.0
- Android SDK (для Android) или Xcode (для iOS)
- Бэкенд доступен по сети (порт `8000`)

### 10.2. Development

```bash
cd frontend
flutter pub get
flutter run

# Для Android emulator (10.0.2.2:8000 — special address for localhost)
# Для реального устройства — измени baseUrl в ApiService
```

### 10.3. Build

```bash
# Android debug APK
flutter build apk --debug

# Android release APK
flutter build apk --release

# iOS (если поддержка добавлена)
flutter build ios --release
```

---

## 11. Нефункциональные требования

- **Производительность**: 
  - IndexedStack держит все экраны в памяти (нет rebuild при переключении)
  - Графики ограничены 240 логами
  
- **Надёжность**:
  - Graceful error handling для сетевых ошибок
  - Retry механизм на Dashboard/Analytics
  
- **Пользовательский опыт**:
  - Loading states (spinner, typing bubble)
  - Snackbars для ошибок/успехов
  - Сообщения при отсутствии данных

---

## 12. Roadmap (рекомендованные улучшения)

### Высокий приоритет

- [ ] **Конфигурируемый Base URL**
  - Через `--dart-define` для CI/CD
  - Settings экран для выбора окружения (dev/stage/prod)
  
- [ ] **Аутентификация**
  - User login/register (или OAuth через Google)
  - JWT токены, secure storage
  
- [ ] **Улучшение обработки ошибок**
  - Единая модель ошибок (маппинг DioException → дружелюбные сообщения)
  - Retry logic с exponential backoff
  
- [ ] **Real-time обновления**
  - Live графики через WebSocket (не только полинг)
  - Live statuses на Dashboard при получении новых сенсор-логов

### Средний приоритет

- [ ] **Кеширование**
  - in-memory TTL для `current` (1 минута)
  - LocalStorage для summary (с invalidation)
  
- [ ] **Offline-first**
  - Persist данные на диск (Hive, SQLite)
  - Sync при восстановлении соединения
  
- [ ] **Локализация (i18n)**
  - Поддержка RU/EN/KK
  - Использовать `intl` артефакты
  
- [ ] **Тесты**
  - Unit тесты для моделей
  - Widget тесты для экранов (loading/error/empty)
  - Integration тесты с real API

### Низкий приоритет

- [ ] **Push уведомления** (Firebase Cloud Messaging)
- [ ] **Темная тема** (Material Dark theme)
- [ ] **Доступность** (A11y: screen reader, text scaling)
- [ ] **Web версия** (Flutter Web на той же кодовой базе)

---

## Глоссарий (Frontend)

| Термин | Определение |
|--------|-----------|
| **Provider** | State management solution для Flutter (ChangeNotifier, Consumer) |
| **IndexedStack** | Widget который держит все детей в памяти, показывая по индексу |
| **BottomNavigationBar** | Bottom tab bar для навигации между экранами |
| **Dio** | HTTP клиент для Flutter/Dart с удобным API |
| **WebSocket** | Bidirectional communication для real-time updates |
| **DTO** | Data Transfer Object — JSON модель для сетевого обмена |
| **Gauge** | Радиальный «спидометр» для отображения VPD |
| **LineChart** | Графики с линиями для временных рядов |

