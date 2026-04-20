# Техническая спецификация: Tamyr Frontend (Flutter Mobile App)

Этот документ описывает **фактическую реализацию** мобильного клиента Tamyr в `frontend/` и задаёт единый контракт по архитектуре, экранам, данным, сетевому слою и сборке.

---

## 1. Назначение и границы

### 1.1. Назначение

**Tamyr Frontend** — мобильное приложение на Flutter, которое:

- показывает **дашборд** со статусами полок,
- отображает **текущий срез** по выбранной полке (через подгрузку `current`),
- позволяет управлять устройствами полки в режиме **manual**, а в режиме **AI** — блокирует ручные элементы,
- визуализирует **аналитику** (история логов, VPD gauge, графики),
- предоставляет **AI-чат агронома** по выбранной полке.

### 1.2. В зоне ответственности

- UI/UX и навигация внутри приложения.
- Хранение состояния на клиенте (in-memory через Provider).
- Интеграция с HTTP API бэкенда.
- Базовая обработка ошибок сети/сервера и отображение состояний loading/error/empty.

### 1.3. Вне зоны ответственности (на текущем этапе)

- Offline-first / кеширование на диск.
- Авторизация пользователя, хранение токенов, secure storage.
- Push уведомления, background sync.
- Мульти-аккаунт / мульти-инстанс (несколько API окружений из UI).

---

## 2. Технологический стек

См. `frontend/pubspec.yaml` (факт):

- **Flutter SDK**: `>=3.4.0 <4.0.0`
- **dio**: HTTP клиент
- **provider**: state management
- **google_fonts**: типографика (Inter / Poppins)
- **intl**: форматирование времени
- **fl_chart**: графики трендов
- **syncfusion_flutter_gauges**: радиальный gauge (VPD)

---

## 3. Архитектура и структура кода (факт)

Декомпозиция по фичам, плюс общий слой:

```text
frontend/lib/
  core/
    network/api_service.dart
    theme/app_theme.dart
  features/
    shell/presentation/app_shell.dart
    dashboard/
      models/
      presentation/
      state/
    control/
      presentation/
      state/
    analytics/
      presentation/
    assistant/
      models/
      presentation/
      state/
  app.dart
  main.dart
```

Принципы:

- **UI** живёт в `features/*/presentation`.
- **Состояние** (load/error/данные) в `features/*/state` как `ChangeNotifier`.
- **DTO/модели** для JSON в `features/*/models`.
- Сетевой слой единый: `core/network/api_service.dart`.

---

## 4. Навигация и экраны

### 4.1. AppShell

Главная навигация реализована через `IndexedStack` и `BottomNavigationBar`:

- **Dashboard** (`DashboardScreen`)
- **Control** (`ControlScreen`)
- **Analytics** (`AnalyticsScreen`)
- **AI-Assistant** (`AssistantScreen`)

Файл: `features/shell/presentation/app_shell.dart`.

### 4.2. Dashboard

Файл: `features/dashboard/presentation/dashboard_screen.dart`.

Поведение:

- При старте `DashboardProvider.load()` загружает `GET /dashboard/summary`.
- Для каждой полки карточка `ShelfStatusCard` показывает:
  - имя, статус,
  - (если подгружено) последнюю температуру/влажность.
- Выбор полки сохраняется в `DashboardProvider.selectedShelfId` и влияет на Control/Assistant.

Состояния:

- loading (спиннер)
- error (кнопка Retry)
- empty (подсказка про сидинг БД/подключение API)

### 4.3. Control

Файл: `features/control/presentation/control_screen.dart`.

Поведение:

- Управление относится к **выбранной полке** (синхронизация с `DashboardProvider.selectedShelfId`).
- Есть переключатель **AI-Agronomist Autopilot**:
  - при включенном AI режимe UI ручного управления **заблокирован** (overlay + `AbsorbPointer`).
- Ручное управление включает:
  - яркость света (0..100)
  - скорость вентиляции (segmented Low/Med/High)
  - целевую температуру (16..30)
  - Emergency Stop (как клиентская команда в `ControlProvider`)

Важно: бэкенд применяет доменное правило `is_ai_mode` и может вернуть **409 Conflict** при попытке менять параметры при включенном AI.

### 4.4. Analytics

Файл: `features/analytics/presentation/analytics_screen.dart`.

Поведение:

- Выбор полки через dropdown.
- Загрузка данных: параллельно
  - `GET /shelves/{id}/current`
  - `GET /shelves/{id}/logs?limit=240`
- На клиенте рассчитывается VPD через `calculateVpd(...)` для gauge и подсказки.
- Графики:
  - Temperature & Humidity (две линии)
  - CO₂ & TVOC (две линии)

### 4.5. Assistant

Файл: `features/assistant/presentation/assistant_screen.dart`.

Поведение:

- Экран привязан к текущей выбранной полке (из `DashboardProvider`).
- Сообщения хранятся в `AssistantProvider.messages`.
- Отправка сообщения вызывает `ApiService.chatWithAi(...)` → `POST /assistant/chat`.
- Отображается typing bubble при ожидании ответа.
- При отсутствии выбранной полки — подсказка «Load the dashboard first…».

---

## 5. Управление состоянием (Provider)

В `main.dart` создаются провайдеры:

- `Provider<ApiService>` — единый API клиент.
- `ChangeNotifierProvider<DashboardProvider>` — summary + currentByShelfId + выбор полки.
- `ChangeNotifierProvider<ControlProvider>` — состояние управления для выбранной полки.
- `ChangeNotifierProvider<AssistantProvider>` — чат-сессия и ошибки AI.

---

## 6. Сетевой слой и контракт API

### 6.1. ApiService

Файл: `core/network/api_service.dart`.

Методы (факт):

- `getDashboardSummary()` → `GET /dashboard/summary`
- `getShelfCurrent(shelfId)` → `GET /shelves/{shelfId}/current`
- `getShelfSensorLogs(shelfId, {limit})` → `GET /shelves/{shelfId}/logs?limit=...`
- `updateDeviceState(...)` → `PATCH /shelves/{shelfId}/control`
- `chatWithAi(shelfId, message)` → `POST /assistant/chat`

### 6.2. Base URL

Сейчас baseUrl зашит дефолтом в `ApiService`:

- `http://192.168.1.113:8000`

Практические заметки:

- Для Android emulator обычно нужен `http://10.0.2.2:8000`.
- Для реального устройства в LAN — IP машины, где запущен бэкенд.

Целевое улучшение (не реализовано): вынести baseUrl в конфиг окружения (flavors / `--dart-define`) или экран настроек.

---

## 6.3. Контракты ошибок (на основе фактического UI)

Фронтенд ожидает типичный формат FastAPI:

- ошибки приходят как JSON с полем `detail` (строка) или списком ошибок валидации.

Для AI ассистента `AssistantProvider` имеет отдельную обработку:

- **503**: отсутствие `GROQ_API_KEY` на сервере — показывается подсказка, как настроить ключ.
- **401**: неверный ключ Groq — показывается подсказка, где создать правильный ключ (`gsk_...`).
- **429/502**: показываются дружелюбные сообщения.

---

## 7. Обработка ошибок и UX-состояния

Текущие паттерны (по экранным реализациям):

- **Loading**: `CircularProgressIndicator` / typing bubble.
- **Error**: строка ошибки в UI + Retry (Dashboard, Analytics); в Control показ ошибки под переключателем.
- **Empty**: отдельное состояние на Dashboard/Analytics при отсутствии данных.

---

## 8. Сборка и запуск

### 8.1. Предусловия

- Flutter SDK установлен (совместимый с `sdk: ">=3.4.0 <4.0.0"`).
- Бэкенд доступен по сети (порт `8000`).

### 8.2. Запуск

- `flutter pub get`
- `flutter run`

Перед запуском убедиться, что `ApiService.baseUrl` указывает на доступный адрес.

---

## 9. Roadmap (рекомендованные улучшения)

- **Конфиг baseUrl** через flavors / `--dart-define` + UI для выбора окружения (dev/stage/prod).
- **Единая модель ошибок** (маппинг DioException → дружелюбные сообщения).
- **Кеширование**:
  - in-memory TTL для `current`,
  - опционально persist на диск для summary/logs.
- **Real-time** (после появления WS/MQTT на бэкенде): live графики и статусы без ручного refresh.
- **Тесты**:
  - unit для парсинга моделей,
  - widget tests для экранов (loading/error/empty).
