# ⚡ Quick Start Checklist

## 🎯 What Was Implemented (DONE ✅)

```
✅ MQTT Listener Service         (app/services/mqtt/sensor_listener.py)
✅ Shelf Model Update            (device_id field added)
✅ Main.py Integration           (lifespan hooks + migration)
✅ Dependencies                  (aiomqtt installed)
✅ Auto-reconnect Logic          (exponential backoff)
✅ Error Handling & Logging      (comprehensive)
✅ TLS/SSL Support              (HiveMQ Cloud ready)
```

---

## 🚀 Next Steps (YOU DO THESE)

### 1️⃣ Configure Environment (5 min)

Create `.env` in project root:
```bash
MQTT_ENABLED=true
MQTT_HOST=193fbce2f2fb461db5e5fea6c8257502.s1.eu.hivemq.cloud
MQTT_PORT=8883
MQTT_USERNAME=your_hivemq_username_here
MQTT_PASSWORD=your_hivemq_password_here
MQTT_TOPIC=tamyr/sensors
```

### 2️⃣ Update Database (2 min)

Connect to PostgreSQL:
```sql
-- Update shelves with device IDs
UPDATE shelves SET device_id = 'esp32-001' WHERE name = 'Shelf 1';
UPDATE shelves SET device_id = 'esp32-002' WHERE name = 'Shelf 2';
UPDATE shelves SET device_id = 'esp32-003' WHERE name = 'Shelf 3';

-- Auto-generate if IDs not set:
UPDATE shelves SET device_id = 'esp32-' || LPAD(id::text, 3, '0');

-- Verify:
SELECT name, device_id FROM shelves;
```

### 3️⃣ Configure ESP32 (Varies)

Update your ESP32 code to publish JSON to `tamyr/sensors`:
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

### 4️⃣ Start Backend (1 min)

```bash
cd backend
source ../.venv/bin/activate
python -m uvicorn app.main:app --reload
```

### 5️⃣ Verify Connection (1 min)

Look for logs:
```
Starting MQTT listener connecting to 193fbce2f2fb...
Connected to MQTT broker at 193fbce2f2fb:8883
Subscribed to topic: tamyr/sensors
```

### 6️⃣ Test Message (1 min)

Trigger ESP32 sensor reading. Check logs:
```
Received message on tamyr/sensors: {"deviceId":"esp32-001",...}
Saved sensor log for shelf Shelf 1 (temp: 24.5°C, humidity: 65.3%)
```

Then verify data:
```sql
SELECT * FROM sensor_logs ORDER BY timestamp DESC LIMIT 5;
```

---

## 📋 Configuration Values Reference

| Key | Current Value | Notes |
|-----|---|---|
| `MQTT_ENABLED` | `true` | Set to `false` to disable listener |
| `MQTT_HOST` | `193fbce2f...eu.hivemq.cloud` | HiveMQ Cloud endpoint |
| `MQTT_PORT` | `8883` | Standard MQTT over TLS port |
| `MQTT_USERNAME` | (from HiveMQ) | Your HiveMQ username |
| `MQTT_PASSWORD` | (from HiveMQ) | Your HiveMQ password |
| `MQTT_TOPIC` | `tamyr/sensors` | Configurable topic name |

---

## 🐛 Troubleshooting

### Listener doesn't start?
```bash
# Check MQTT_ENABLED=true in .env
# Check logs: "MQTT listener is disabled"
```

### "No shelf found for device_id"?
```bash
# Run UPDATE statement above to set device_ids
# Verify with: SELECT name, device_id FROM shelves;
```

### "MQTT connection error: username"?
```bash
# Check credentials in .env
# Test on HiveMQ console first
```

### Data not appearing in DB?
```bash
# Enable DEBUG logging to see message processing
# Check JSON format matches expected schema
# Query: SELECT * FROM sensor_logs ORDER BY timestamp DESC;
```

---

## 📚 Full Documentation

See **MQTT_INTEGRATION_GUIDE.md** for:
- Detailed architecture explanation
- Database queries for monitoring
- Advanced configuration options
- Debugging techniques
- Testing procedures

---

## 🎓 How It Works (High Level)

```
1. ESP32 publishes JSON every N seconds → MQTT topic
2. Listener receives message → Async processing
3. Extract deviceId → Lookup shelf in DB
4. Create SensorLog row → Persist to PostgreSQL
5. App queries sensor_logs for dashboard/analytics
```

**That's it!** Your MQTT integration is ready to go. Just follow the 6 steps above. ⚡

---

**Questions?** Check MQTT_INTEGRATION_GUIDE.md or review the source:
- `backend/app/services/mqtt/sensor_listener.py` (implementation)
- `backend/app/models/shelf.py` (schema)
- `backend/app/main.py` (integration)
