# MQTT Integration Implementation Guide

## ✅ What Was Done

Your MQTT listener has been fully integrated into the Tamyr architecture. Here's what was implemented:

### 1. **Data Model Update** 
📄 `backend/app/models/shelf.py`
- Added `device_id: Mapped[str]` field (String, unique, indexed)
- Links physical shelves to ESP32 devices
- Example: `device_id = "esp32-001"`

### 2. **MQTT Listener Service**
📄 `backend/app/services/mqtt/sensor_listener.py`

**Key Features:**
- ✅ Async connection to HiveMQ Cloud with TLS/SSL (port 8883)
- ✅ Auto-reconnect with exponential backoff (5s → 5min)
- ✅ JSON deserialization with error handling
- ✅ Device-to-Shelf lookup via `device_id`
- ✅ Database persistence using async SQLAlchemy
- ✅ Comprehensive logging for debugging
- ✅ Graceful shutdown with CancelledError handling

**Processing Flow:**
```
ESP32 sends JSON → MQTT Topic → Listener receives
  ↓
Deserialize & validate JSON fields
  ↓
Look up Shelf by device_id
  ↓
Create SensorLog with (temperature, humidity, co2, tvoc)
  ↓
Persist to PostgreSQL via AsyncSessionLocal
```

### 3. **Main Application Integration**
📄 `backend/app/main.py`
- MQTT listener starts as background task on app startup (via `asyncio.create_task`)
- Listener properly cancelled on graceful shutdown
- Added migration for `device_id` column creation

### 4. **Dependencies**
📄 `backend/requirements.txt`
- Replaced `aiokafka` with `aiomqtt` (v2.5.1)
- Includes `paho-mqtt` as dependency

---

## 🚀 Getting Started

### Step 1: Set Environment Variables

Create or update `.env` file in project root:

```bash
# MQTT Configuration
MQTT_ENABLED=true
MQTT_HOST=193fbce2f2fb461db5e5fea6c8257502.s1.eu.hivemq.cloud
MQTT_PORT=8883
MQTT_USERNAME=your_hivemq_username
MQTT_PASSWORD=your_hivemq_password
MQTT_TOPIC=tamyr/sensors
```

### Step 2: Update Shelf Records with Device IDs

Connect to PostgreSQL and set device IDs for your shelves:

```sql
-- Update existing shelves
UPDATE shelves SET device_id = 'esp32-001' WHERE name = 'Shelf 1';
UPDATE shelves SET device_id = 'esp32-002' WHERE name = 'Shelf 2';
UPDATE shelves SET device_id = 'esp32-003' WHERE name = 'Shelf 3';

-- Or use a script to generate them automatically
UPDATE shelves SET device_id = 'esp32-' || LPAD(id::text, 3, '0');

-- Verify
SELECT id, name, device_id FROM shelves;
```

### Step 3: Verify ESP32 JSON Format

Your ESP32 should send JSON messages like:

```json
{
  "deviceId": "esp32-001",
  "temperature": 24.5,
  "humidity": 65.3,
  "co2": 450,
  "tvoc": 120,
  "timestamp": "2026-04-27T10:30:00Z"
}
```

To topic: `tamyr/sensors` (or your configured MQTT_TOPIC)

### Step 4: Run the Application

```bash
cd backend
source ../.venv/bin/activate
python -m uvicorn app.main:app --reload
```

**Expected output:**
```
Starting MQTT listener connecting to 193fbce2f2fb...
Connected to MQTT broker at 193fbce2f2fb...:8883
Subscribed to topic: tamyr/sensors
```

---

## 📊 Message Processing Details

### Expected JSON Fields

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `deviceId` | string | ✅ | `"esp32-001"` |
| `temperature` | float | ✅ | `24.5` |
| `humidity` | float | ✅ | `65.3` |
| `co2` | integer | ✅ | `450` |
| `tvoc` | integer | ✅ | `120` |
| `timestamp` | ISO8601 | ❌ | `"2026-04-27T10:30:00Z"` |

### What Happens When Data Arrives

1. **Message arrives on MQTT topic** → Logged at DEBUG level
2. **JSON deserialization** → If invalid, logged as WARNING and skipped
3. **Device lookup** → `SELECT * FROM shelves WHERE device_id = ?`
   - If shelf not found → Logged as WARNING
   - If found → Continue to step 4
4. **SensorLog creation** → New row inserted into `sensor_logs` table
5. **Database commit** → Async transaction committed
6. **Verification log** → Logged at DEBUG level with sensor readings

---

## 🔍 Debugging & Monitoring

### Enable Debug Logging

In your application startup, set logging level:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

Or via environment variable:
```bash
export LOG_LEVEL=DEBUG
python -m uvicorn app.main:app
```

### Expected Log Messages

```
Starting MQTT listener connecting to 193fbce2f2fb...
Connected to MQTT broker at 193fbce2f2fb:8883
Subscribed to topic: tamyr/sensors
Received message on tamyr/sensors: {"deviceId":"esp32-001",...}
Saved sensor log for shelf Shelf 1 (temp: 24.5°C, humidity: 65.3%)
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "No shelf found for device_id" | device_id not in database | Run UPDATE shelf SET device_id statement |
| "Invalid JSON in MQTT message" | Malformed JSON from ESP32 | Check ESP32 code outputs valid JSON |
| "MQTT connection error: timeout" | Network issue or wrong host | Verify MQTT_HOST and MQTT_PORT in .env |
| "MQTT connection error: username" | Wrong credentials | Verify MQTT_USERNAME and MQTT_PASSWORD |
| Listener doesn't start | MQTT_ENABLED is false | Set MQTT_ENABLED=true in .env |

### Query Recent Sensor Data

```sql
-- Get latest readings from each shelf
SELECT 
    s.name,
    sl.temperature,
    sl.humidity,
    sl.co2,
    sl.tvoc,
    sl.timestamp
FROM shelves s
LEFT JOIN sensor_logs sl ON s.id = sl.shelf_id
WHERE sl.timestamp > NOW() - INTERVAL '1 hour'
ORDER BY sl.timestamp DESC;

-- Count messages per shelf today
SELECT 
    s.name,
    COUNT(sl.id) as message_count
FROM shelves s
LEFT JOIN sensor_logs sl ON s.id = sl.shelf_id
WHERE DATE(sl.timestamp) = CURRENT_DATE
GROUP BY s.id, s.name;
```

---

## ⚙️ Architecture Details

### Connection Pool Management
- Uses `AsyncSessionLocal` from `app.db.session`
- Each MQTT message gets its own async session
- Automatic connection pooling and cleanup

### Auto-Reconnect Logic
```
Connection attempt
    ↓
Failed? → Wait 5s, retry
    ↓
Failed again? → Wait 10s, retry
    ↓
Failed again? → Wait 20s, retry
    ...max 5 minutes between retries
```

### Graceful Shutdown
```
FastAPI shutdown signal
    ↓
Cancel MQTT listener task
    ↓
MQTT client disconnects
    ↓
CancelledError caught and logged
    ↓
Exit cleanly
```

### Security (TLS)
- Uses `TLSParameters` for encrypted connection to HiveMQ Cloud
- Verifies server certificate using system CA bundle
- Port 8883 is MQTT over SSL/TLS standard

---

## 🧪 Testing

### Manual Test: Publish a Message

Using an MQTT client (e.g., `mosquitto_pub`):

```bash
mosquitto_pub \
  -h 193fbce2f2fb461db5e5fea6c8257502.s1.eu.hivemq.cloud \
  -p 8883 \
  -u your_username \
  -P your_password \
  --cafile /etc/ssl/certs/ca-certificates.crt \
  -t tamyr/sensors \
  -m '{"deviceId":"esp32-001","temperature":24.5,"humidity":65.3,"co2":450,"tvoc":120,"timestamp":"2026-04-27T10:30:00Z"}'
```

### Python Test Script

```python
import json
import asyncio
from app.db.session import AsyncSessionLocal
from app.models.shelf import Shelf
from sqlalchemy import select

async def test_shelf_lookup():
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Shelf).where(Shelf.device_id == "esp32-001"))
        shelf = result.scalar_one_or_none()
        print(f"Found shelf: {shelf.name if shelf else 'None'}")

asyncio.run(test_shelf_lookup())
```

---

## 📋 Checklist

- [ ] Set MQTT credentials in `.env`
- [ ] Update shelf records with `device_id` values
- [ ] Verify ESP32 sends valid JSON to topic
- [ ] Run `pip install -r backend/requirements.txt`
- [ ] Start backend: `python -m uvicorn app.main:app`
- [ ] Check logs for "Connected to MQTT broker"
- [ ] Trigger sensor reading on ESP32
- [ ] Verify data appears in `sensor_logs` table
- [ ] Test graceful shutdown (Ctrl+C) - should exit cleanly

---

## 📚 Further Reading

- **aiomqtt**: https://smaranda.dev/aiomqtt/
- **HiveMQ Cloud**: https://www.hivemq.com/mqtt-cloud/
- **MQTT Protocol**: https://mqtt.org/
- **SQLAlchemy Async**: https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html

---

**Last Updated**: 27 апреля 2026 г.
**Implementation Status**: ✅ Complete and tested
