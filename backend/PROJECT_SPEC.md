# Техническая спецификация: Tamyr Backend (Smart Hydroponics API)

Этот документ — **полная и актуальная спецификация** бэкенда проекта Tamyr (Smart Hydroponics Digital Twin). Описывает реализованную функциональность, контракты API, модель данных и правила бизнес-логики.

---

## 1. Контекст и границы системы

### 1.1. Назначение

**Tamyr Backend** — многоуровневый HTTP API + real-time WebSocket + MQTT-слушатель для управления «цифровым двойником» гидропонной установки.

- **Инgest**: собирает телеметрию (°C, %, CO₂, TVOC) от ESP32 устройств через MQTT в реальном времени
- **Storage**: хранит измерения (`SensorLog`), состояние управления (`DeviceState`) и метаданные полок (`Shelf`) в PostgreSQL
- **API**: выдаёт краткие срезы (dashboard) и полные данные (аналитика) по HTTP
- **Real-time**: транслирует новые измерения подписчикам через WebSocket (`/ws/shelves/{id}/sensors`)
- **Интеллект**: AI ассистент-агроном контекстно отвечает на вопросы, учитывая текущую телеметрию полки

### 1.2. В зоне ответственности (реализовано)

- ✅ **HTTP API контракты** (8 рабочих эндпоинтов, коды ошибок 4xx/5xx)
- ✅ **MQTT слушатель** с auto-reconnect (экспоненциальный backoff, логирование)
- ✅ **WebSocket realtime** для транляции датчиков (`/ws/shelves/{id}/sensors`)
- ✅ **Модель данных**: Shelf, DeviceState, SensorLog с привязками и каскадным удалением
- ✅ **AI режим**: доменное правило — запрет ручного управления при `is_ai_mode=true` (409 Conflict)
- ✅ **Расчёты**: VPD (vapor pressure deficit) на основе T/H
- ✅ **Валидация**: Pydantic + SQLAlchemy constraints

### 1.3. Вне зоны ответственности (не реализовано)

- ❌ **Аутентификация/авторизация** (нет API токенов, RBAC)
- ❌ **Миграции БД** (используется `create_all` + одноразовые `ALTER TABLE`; Alembic не подключён)
- ❌ **Версионирование API** (нет `/api/v1/`, пути прямые)
- ❌ **Rate limiting, quota** (не ограничиваются запросы)
- ❌ **Caching** (нет Redis, каждый запрос — свежие данные из БД)

---

## 2. Технологический стек

| Компонент | Назначение | Версия/Замечание |
|-----------|-----------|------------------|
| **FastAPI** | HTTP API, DI, OpenAPI docs | (requirements.txt) |
| **Uvicorn** | ASGI сервер | standard extras |
| **SQLAlchemy 2.x (async)** | ORM с async поддержкой | 2.0+ |
| **asyncpg** | async PostgreSQL драйвер | native для asyncio |
| **aiomqtt** | MQTT клиент с async/await | для sensor listener |
| **Pydantic v2** | валидация/сериализация (DTO) | |
| **pydantic-settings** | конфиг из `.env` | CONFIG_FILE |
| **Groq SDK** | LLM провайдер (Llama 3) | `groq` пакет |
| **PostgreSQL 16** | основная БД | в Docker compose |
| **Docker Compose** | локальная инфра | postgres + api сервисы |
| **Python 3.10+** | runtime | |

---

## 3. Структура проекта (факт)

```text
backend/
  app/
    __init__.py
    main.py (lifespan: MQTT listener, schema init)
    api/
      __init__.py
      router.py (подключение всех роутеров)
      deps.py (AsyncSession DI)
      routes/
        __init__.py
        dashboard.py (GET /dashboard/summary)
        shelves.py (GET current, logs; PATCH control)
        sensors.py (POST report)
        assistant.py (POST chat)
        realtime.py (WS /ws/shelves/{id}/sensors)
    core/
      __init__.py
      config.py (pydantic Settings с env vars)
      utils.py (calculate_vpd, другие утилиты)
    db/
      __init__.py
      session.py (AsyncSession factory, engine init)
    models/
      __init__.py
      base.py (declarative Base)
      enums.py (ShelfStatus enum)
      shelf.py (Shelf ORM)
      device_state.py (DeviceState ORM)
      sensor_log.py (SensorLog ORM)
    schemas/
      __init__.py
      common.py (общие типы)
      shelf.py (ShelfSummaryRead)
      device_state.py (DeviceStateRead, DeviceStateControlPatch)
      sensor.py (SensorLogRead, SensorReportCreate)
      current.py (ShelfCurrentResponse)
      dashboard.py (DashboardSummaryResponse)
      assistant.py (ChatRequest, ChatResponse)
    services/
      __init__.py
      mqtt/
        __init__.py
        sensor_listener.py (MQTT async listener с reconnect логикой)
      sensors/
        __init__.py
        ingest.py (persist_sensor_report)
    realtime/
      __init__.py
      hub.py (ConnectionHub для WS broadcast)
  requirements.txt
  seed.py (создание seed данных для dev)
  Dockerfile
```

### Ключевые точки входа и инициализация

1. **`app/main.py`**:
   - `lifespan()`: при старте — создание таблиц, запуск MQTT listener
   - CORS middleware для web/мобильного клиента
   - Подключение API роутера

2. **`app/api/router.py`**:
   - Включает роутеры: dashboard, shelves, sensors, assistant, realtime
   - Экспортирует `api_router`

3. **`app/db/session.py`**:
   - `AsyncSessionLocal` фабрика
   - `engine` с URL из конфига
   - Используется как dependency в `get_session()`

4. **`app/realtime/hub.py`**:
   - `ConnectionHub` — singleton для управления WebSocket соединениями
   - методы: `connect()`, `disconnect()`, `broadcast()`
   - используется в `realtime.py` и `sensor_listener.py`

---

## 4. Конфигурация и окружение

### 4.1. Переменные окружения (`.env`)

Загружаются через `pydantic-settings` в `app/core/config.py`:

| Переменная | Тип | Назначение | Пример/Примечание |
|-----------|-----|-----------|------------------|
| `DATABASE_URL` | str | PostgreSQL async URL | `postgresql+asyncpg://user:pass@localhost/hydroponics` |
| `GROQ_API_KEY` | str | API ключ LLM провайдера | Если пусто — `/assistant/chat` вернёт 503 |
| `MQTT_ENABLED` | bool (default: `false`) | Включать ли MQTT listener | Set to `true` for production |
| `MQTT_HOST` | str | MQTT broker hostname | `193fbce2f2fb461db5e5fea6c8257502.s1.eu.hivemq.cloud` |
| `MQTT_PORT` | int | MQTT broker port | `8883` (обычно TLS) |
| `MQTT_USERNAME` | str | MQTT auth username | esp32user |
| `MQTT_PASSWORD` | str | MQTT auth password | esp32pass |
| `MQTT_TOPIC` | str | Subscribe topic | `sensors/air_quality` или подобное |

### 4.2. База данных

- **СУБД**: PostgreSQL 16 (в docker-compose)
- **Инициализация** (не-миграционный способ, только для dev):
  - При `app.main.lifespan` выполняется `Base.metadata.create_all(...)`
  - + одноразовые `ALTER TABLE` для обратной совместимости
- **Рекомендация для production**: использовать Alembic для миграций

---

## 5. Модель данных (реализовано)

### 5.1. Сущности (ORM модели)

#### Shelf

Представляет одну полку/контур управления гидропонной установки.

| Поле | Тип | Constraints | Примечание |
|------|-----|-----------|-----------|
| `id` | int | PK | |
| `name` | str(100) | UNIQUE, NOT NULL | e.g. "Shelf A", "Нижняя полка" |
| `device_id` | str(100) | UNIQUE, NOT NULL, index | ESP32 ID (MQTT source) |
| `status` | Enum | NOT NULL, default=OK | OK / WARNING / CRITICAL |

#### SensorLog

Хронологическая запись измерений одного датчика на полке.

| Поле | Тип | Constraints | Примечание |
|------|-----|-----------|-----------|
| `id` | int | PK | |
| `shelf_id` | int | FK(Shelf), NOT NULL | Cascade delete |
| `temperature` | float | NOT NULL | °C |
| `humidity` | float | NOT NULL | % |
| `co2` | int | NOT NULL | ppm |
| `tvoc` | int | NOT NULL | ppb или условный индекс |
| `timestamp` | DateTime | NOT NULL, index | UTC, по умолчанию текущее время |

#### DeviceState

Состояние исполнительных устройств и AI режим для полки (1:1 с Shelf).

| Поле | Тип | Constraints | Примечание |
|------|-----|-----------|-----------|
| `shelf_id` | int | PK, FK(Shelf), NOT NULL | |
| `light_brightness` | int | NOT NULL, default=50 | 0..100 % |
| `fan_speed` | int | NOT NULL, default=50 | 0..100 % (или Low/Med/High на уровне клиента) |
| `target_temperature` | float | NOT NULL, default=22 | °C, целевой показатель |
| `heater_on` | bool | NOT NULL, default=false | |
| `humidifier_on` | bool | NOT NULL, default=false | |
| `is_ai_mode` | bool | NOT NULL, default=false | Переключатель автопилота |

### 5.2. Диаграмма связей

```mermaid
erDiagram
    SHELF ||--o{ SENSOR_LOG : "1:N (cascade delete)"
    SHELF ||--|| DEVICE_STATE : "1:1 (cascade delete)"
```

- **Shelf → SensorLog**: одна полка может иметь много логов. При удалении Shelf логи удаляются.
- **Shelf → DeviceState**: одна полка — одно управляемое устройство. При удалении Shelf удаляется и DeviceState.

### 5.3. Доменный инвариант: AI режим

**Правило**: когда `DeviceState.is_ai_mode == true`, система запрещает ручное изменение параметров управления.

```
Если (is_ai_mode == true) И (payload содержит не-is_ai_mode поля):
  → ошибка 409 Conflict
  → detail: "Manual control is disabled while AI mode is enabled."
```

**Исключение**: можно всегда менять сам флаг `is_ai_mode`, даже если он уже включён (отключение AI).

**Реализация**: проверка в `routes/shelves.py` → `patch_shelf_control()`

---

## 6. Бизнес-логика и расчёты

### 6.1. VPD (Vapor Pressure Deficit)

**Определение**: Разница между насыщенным и фактическим парциальным давлением водяного пара; критичный параметр для выращивания растений.

**Расчёт**: 
```python
def calculate_vpd(temperature: float, humidity: float) -> float:
    # используется стандартная формула Magnus с коэффициентами
    # результат в кПа
    ...
```

**Использование**:
- Рассчитывается и возвращается в ответе `GET /shelves/{id}/current` (поле `vpd`)
- Используется в контексте AI чата (`system_prompt`)
- Если нет последнего `SensorLog` — VPD не рассчитывается (возвращается `null`)

---

## 7. HTTP API (полный контракт)

### 7.1. Общие принципы

- **Формат**: JSON
- **Базовый путь**: `/` (нет `/api/v1/`)
- **CORS**: разрешены localhost:*, http://127.0.0.1:*
- **Ошибки**: `HTTPException` с `detail: str`

### 7.2. Реализованные эндпоинты (8 шт.)

#### 1. Health Check
```
GET /
Response 200: { "status": "ok", "service": "Smart Hydroponics API" }
```
Проверка живости сервиса (ready for orchestrators).

#### 2. Dashboard Summary
```
GET /dashboard/summary
Response 200: DashboardSummaryResponse
  {
    "shelves": [
      {
        "id": 1,
        "name": "Shelf A",
        "status": "OK"
      },
      ...
    ]
  }
```
Краткая сводка по всем полкам для главного дашборда (traffic-light view).

#### 3. Get Shelf Current State
```
GET /shelves/{shelf_id}/current
Response 200: ShelfCurrentResponse
  {
    "shelf": {
      "id": 1,
      "name": "Shelf A",
      "status": "OK"
    },
    "latest_sensor": {
      "id": 100,
      "shelf_id": 1,
      "temperature": 24.5,
      "humidity": 65.0,
      "co2": 450,
      "tvoc": 120,
      "timestamp": "2026-04-28T10:30:00Z"
    },
    "device_state": {
      "shelf_id": 1,
      "light_brightness": 75,
      "fan_speed": 50,
      "target_temperature": 22.0,
      "heater_on": true,
      "humidifier_on": false,
      "is_ai_mode": false
    },
    "vpd": 1.23
  }
Response 404: { "detail": "Shelf {shelf_id} not found." }
```
Полный срез состояния полки: текущие показания + управление + рассчитанный VPD.

#### 4. Get Sensor Logs (History)
```
GET /shelves/{shelf_id}/logs?limit=200
Response 200: [SensorLogRead, ...]
  [
    { "id": 1, "shelf_id": 1, "temperature": 23.0, "humidity": 64.5, ... "timestamp": "2026-04-27T10:00:00Z" },
    ...
    { "id": 200, "shelf_id": 1, "temperature": 24.5, "humidity": 65.0, ... "timestamp": "2026-04-28T10:30:00Z" }
  ]
Response 400: { "detail": "limit must be between 1 and 2000" }
Response 404: { "detail": "Shelf {shelf_id} not found." }
```
История логов датчика (от старых к новым, max 2000).

#### 5. Update Device Control (Manual)
```
PATCH /shelves/{shelf_id}/control
Request:
  {
    "light_brightness": 80,
    "fan_speed": 60,
    "is_ai_mode": false
  }
Response 200: DeviceStateRead
  {
    "shelf_id": 1,
    "light_brightness": 80,
    "fan_speed": 60,
    "target_temperature": 22.0,
    "heater_on": true,
    "humidifier_on": false,
    "is_ai_mode": false
  }
Response 409: { "detail": "Manual control is disabled while AI mode is enabled." }
Response 404: { "detail": "Shelf {shelf_id} not found." }
```
Частичное обновление управления (все поля опциональны). **Бизнес-правило**: если `is_ai_mode=true`, нельзя менять остальное (409).

#### 6. Report Sensor Data (MQTT Legacy)
```
POST /sensors/report
Request:
  {
    "shelf_id": 1,
    "temperature": 24.5,
    "humidity": 65.0,
    "co2": 450,
    "tvoc": 120,
    "timestamp": "2026-04-28T10:30:00Z"  // optional
  }
Response 201: SensorLogRead
  { "id": 101, "shelf_id": 1, "temperature": 24.5, ... "timestamp": "2026-04-28T10:30:00Z" }
Response 404: { "detail": "No shelf found for shelf_id..." }
```
**Замечание**: основной способ инgest — MQTT listener (асинхронный фоновый процесс). Этот эндпоинт оставлен для ручного тестирования.

#### 7. AI Assistant Chat
```
POST /assistant/chat
Request:
  {
    "shelf_id": 1,
    "message": "Что делать при высоком VPD?"
  }
Response 200: ChatResponse
  {
    "reply": "При высоком VPD (>1.5 kPa) рекомендуется... [full response от Groq]"
  }
Response 401: { "detail": "Invalid or missing GROQ_API_KEY..." }
Response 404: { "detail": "Shelf {shelf_id} not found." }
Response 503: { "detail": "GROQ_API_KEY is not configured." }
```
Контекстный AI чат. System prompt заполняется последней телеметрией полки и состоянием устройств.

#### 8. WebSocket: Live Sensor Stream
```
WS /ws/shelves/{shelf_id}/sensors

Connection workflow:
  1. client connects → hub.connect(shelf_id, ws)
  2. client keeps connection open (keepalive)
  3. server pushes SensorLog as JSON when MQTT sends data
  4. client disconnects → hub.disconnect(shelf_id, ws)

Message format (server → client):
  {
    "type": "sensor_log",
    "data": { "id": 101, "shelf_id": 1, "temperature": 24.5, ... }
  }

Response 404 (on connect): WebSocketDisconnect (если shelf не существует)
```
**Real-time**: при получении нового логов через MQTT, все подписчики получают JSON на WebSocket.

---

## 7.3. MQTT Listener (Background Service)

**Фоновый процесс** (запускается в `lifespan` → `start_mqtt_listener`):

- **Хост/Порт**: из `MQTT_HOST`, `MQTT_PORT` (конфиг)
- **Auth**: `MQTT_USERNAME`, `MQTT_PASSWORD`
- **Topic**: `MQTT_TOPIC` (e.g. `sensors/air_quality`)
- **TLS**: да (системные CA сертификаты)

**Ожидаемый формат сообщения** (JSON):
```json
{
  "deviceId": "esp32-001",
  "temperature": 24.5,
  "humidity": 65.3,
  "co2": 450,
  "tvoc": 120,
  "timestamp": "2026-04-28T10:30:00Z"
}
```

**Логика**:
1. Получить сообщение → распарсить JSON
2. Найти Shelf по `deviceId` (`Shelf.device_id`)
3. Создать `SensorLog` с данными
4. **Broadcast**: отправить log всем подписчикам `WS /ws/shelves/{shelf_id}/sensors`

**Надёжность**:
- Auto-reconnect с экспоненциальным backoff (5s → 10s → 20s ... max 300s)
- Logging всех ошибок и статусов подключения

---

## 8. Локальный запуск и тестирование

### 8.1. Только PostgreSQL в Docker, API локально (dev mode)

```bash
# Из корня проекта
docker compose up -d postgres

# В backend/ — активировать venv
source .venv/bin/activate
pip install -r requirements.txt

# Запустить API
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

OpenAPI docs: http://localhost:8000/docs

### 8.2. Всё в Docker (включая API и MQTT listener)

```bash
# Из корня проекта
docker compose up -d --build
```

Services:
- `postgres`: 5432
- `api`: 8000

### 8.3. Seed Data (для тестирования)

```bash
cd backend
python seed.py
```

Создаёт:
- 3 полки с именами A/B/C
- DeviceState для каждой полки
- Синтетические SensorLog за 7 дней (для графиков в analytics)

---

## 9. Интеграция с мобильным клиентом (Flutter)

Frontend ожидает:

- **Base URL**: `http://{backend-host}:8000` (настраивается в `ApiService`)
- **API контракты**: см. выше (endpoints 1–7)
- **WebSocket**: поддерживает `WS /ws/shelves/{id}/sensors`

---

## 10. Нефункциональные требования

- **Надёжность**: MQTT listener восстанавливается при разрывах соединения; Groq API ошибки обработаны (401, 429, 503).
- **Производительность**: логи ограничены `limit` для избежания OOM; рекомендуется индекс `(shelf_id, timestamp desc)`.
- **Безопасность**: **НЕТУ AUTH** — для production добавить API key validation и user auth.
- **Масштабируемость**: PostgreSQL коннекшены pooled (asyncpg); WebSocket broadcast optimized для малого числа полок.

---

## 11. Roadmap и TODOs

### Высокий приоритет (в production)

- [ ] **Миграции БД (Alembic)**
  - `create_all` заменить на Alembic миграции
  - скрипт инициализации для чистой БД
  
- [ ] **Аутентификация**
  - API Key для ESP32 на `POST /sensors/report` (валидация в middleware)
  - User auth для мобильного клиента (JWT или session)
  - Rate limit по API key
  
- [ ] **Валидация входных данных**
  - Проверка диапазонов (temperature, humidity, co2 разумные диапазоны)
  - Защита от injection
  
- [ ] **Обработка ошибок**
  - Graceful shutdown MQTT listener при `docker stop`
  - Логирование ошибок в структурированном формате (JSON)

### Средний приоритет (улучшение UX)

- [ ] **API документация**
  - OpenAPI schema уже есть (`/docs`), но нужны примеры ответов для каждого статуса
  - Описать коды ошибок в OpenAPI аннотациях
  
- [ ] **Расширение аналитики**
  - Агрегированные срезы (hourly, daily averages)
  - Трендовые эндпоинты
  
- [ ] **Оптимизация производительности**
  - Индексы на `(shelf_id, timestamp DESC)` для быстрого fetch последнего лога
  - Кеширование summary (Redis или in-memory)

### Низкий приоритет (nice-to-have)

- [ ] **Push уведомления** (критичные состояния → мобильное приложение)
- [ ] **Интеграция с IoT платформами** (Azure IoT Hub, AWS IoT Core)
- [ ] **Экспорт данных** (CSV, Parquet для анализа)
- [ ] **Телеметрия сервиса** (Prometheus метрики, Jaeger traces)

---

## Глоссарий

| Термин | Определение |
|--------|-----------|
| **VPD** | Vapor Pressure Deficit — разница между насыщенным и фактическим давлением водяного пара; критичный параметр для растений |
| **Shelf** | Одна полка/контур управления в гидропонной системе |
| **DeviceState** | Состояние управления (свет, вентилятор, уставки) для одной полки |
| **SensorLog** | Одно измерение датчика в момент времени |
| **MQTT** | Message Queuing Telemetry Transport — протокол для IoT устройств |
| **ESP32** | Микроконтроллер с WiFi/MQTT способностью |
| **AI Mode** | Режим автопилота когда система сама управляет полкой (блокирует ручное управление) |
| **Groq** | LLM провайдер с fast inference (используется для AI ассистента-агронома) |

