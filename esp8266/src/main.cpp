/*
  ESP8266 D1 mini Grow Station Node

  Features:
  - WiFi connect with auto-reconnect
  - Read DHT11 temperature & humidity
  - SSD1306 OLED via I2C shows live metrics and WiFi RSSI
  - NTP time via configTime()
  - POST JSON to http://<SERVER_IP>/api/sensor every 10 seconds with retry

  JSON schema:
  {
    "device": "esp8266-grow-controller-01",
    "temp_c": 24.8,
    "humidity": 58,
    "timestamp": 1731809160,
    "rssi": -61
  }

  OLED-Belegungsplan (D1 mini typical):
  - SSD1306 I2C
    SDA -> <GPIO_OLED_SDA> (z. B. D2 / GPIO4)
    SCL -> <GPIO_OLED_SCL> (z. B. D1 / GPIO5)
  - DHT11 Data -> <GPIO_DHT> (z. B. D4 / GPIO2)

  Placeholders to keep in code: <GPIO_DHT>, <GPIO_OLED_SDA>, <GPIO_OLED_SCL>, <SERVER_IP>, <SSID>, <WIFI_PASSWORD>
*/

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <time.h>

#include "config.h" // copy include/config.h.example -> include/config.h and edit placeholders

// DHT
#define DHTTYPE DHT11
DHT dht(GPIO_DHT, DHTTYPE);

// OLED display
Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);

// Timers
static unsigned long lastMeasure = 0;
const unsigned long MEASURE_INTERVAL_MS = 10000; // 10 seconds

// Network
static bool timeInitialized = false;

void drawOLED(const String &ssid, long rssi, float t, float h) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 0);
  display.print("WiFi: "); display.print(ssid);

  display.setCursor(0, 10);
  display.print("RSSI: "); display.print(rssi); display.print(" dBm");

  display.setCursor(0, 24);
  display.setTextSize(2);
  display.print("T:");
  if (isnan(t)) display.print("--"); else display.print(String(t, 1));
  display.print("C");

  display.setCursor(0, 46);
  display.setTextSize(2);
  display.print("H:");
  if (isnan(h)) display.print("--"); else display.print(String(h, 0));
  display.print("%");

  display.display();
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(300);
  }
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  connectWiFi();
}

void ensureTime() {
  if (timeInitialized) return;
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  // Wait briefly for time
  for (int i = 0; i < 20; i++) {
    time_t now = time(nullptr);
    if (now > 1600000000) { // sanity check
      timeInitialized = true;
      break;
    }
    delay(250);
  }
}

bool postJSON(float tempC, float humidity, long rssi) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClient client;
  HTTPClient http;

  String url = String("http://") + SERVER_IP + "/api/sensor";
  if (!http.begin(client, url)) {
    return false;
  }

  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> doc;
  doc["device"] = F("esp8266-grow-controller-01");
  doc["temp_c"] = tempC;
  doc["humidity"] = (int)round(humidity);

  time_t now = time(nullptr);
  if (now < 100000) {
    // If NTP not ready, send millis-based timestamp as fallback epoch-ish
    doc["timestamp"] = (int)(millis() / 1000);
  } else {
    doc["timestamp"] = (int)now;
  }

  doc["rssi"] = (int)rssi;

  String body;
  serializeJson(doc, body);

  int httpCode = http.POST(body);
  http.end();

  return (httpCode >= 200 && httpCode < 300);
}

void setup() {
  Serial.begin(115200);

  // I2C init on custom pins
  Wire.begin(GPIO_OLED_SDA, GPIO_OLED_SCL);

  // OLED init
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    // No display; continue headless
  } else {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println(F("Grow Node booting..."));
    display.display();
  }

  // Sensors
  dht.begin();

  // WiFi
  connectWiFi();
  ensureTime();
}

void loop() {
  ensureWiFi();

  const unsigned long nowMs = millis();
  if (nowMs - lastMeasure >= MEASURE_INTERVAL_MS) {
    lastMeasure = nowMs;

    float t = dht.readTemperature();   // Celsius
    float h = dht.readHumidity();
    long rssi = WiFi.RSSI();

    // Update OLED
    drawOLED(WiFi.SSID(), rssi, t, h);

    // Retry POST up to 3 times with small backoff
    bool ok = false;
    for (int i = 0; i < 3 && !ok; i++) {
      ok = postJSON(t, h, rssi);
      if (!ok) {
        delay(750 + i * 250);
        ensureWiFi();
      }
    }
  }

  delay(10);
}
