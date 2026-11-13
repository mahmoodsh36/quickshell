pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// open-meteo forecast (no api key), refreshed every 20 minutes and cached so it shows offline
Singleton {
  id: root
  readonly property var place: {
    const p = Config.weatherLocation.split(",");
    return { lat: Number(p[0]), lon: Number(p[1]), name: p[2] || "" };
  }
  readonly property string unit: Config.weatherUnit

  property var data: null
  property string error: ""
  property bool loading: false
  property real fetchedAt: 0
  property bool rainWarned: false

  readonly property bool ok: data !== null && !!data.current
  readonly property var current: ok ? data.current : null
  readonly property int code: ok ? current.weather_code : -1
  readonly property bool isDay: ok ? current.is_day === 1 : true
  readonly property int temp: ok ? Math.round(current.temperature_2m) : 0
  readonly property int feels: ok ? Math.round(current.apparent_temperature) : 0
  readonly property string label: describe(code)

  // the api answers in the place's local time; this turns its strings into real instants
  function at(s) {
    return new Date(Date.parse((s.length === 10 ? s + "T00:00" : s) + "Z") - (data ? data.utc_offset_seconds : 0) * 1000);
  }

  // "now" advances with each fetch, which is often enough at hourly resolution
  readonly property var hours: {
    if (!ok)
      return [];
    const h = data.hourly, now = fetchedAt || Date.now(), out = [];
    for (let i = 0; i < h.time.length && out.length < 25; i++) {
      const t = at(h.time[i]);
      if (t.getTime() + 3600000 <= now)
        continue;
      out.push({ time: t, temp: h.temperature_2m[i], pop: h.precipitation_probability[i] || 0, code: h.weather_code[i], day: h.is_day[i] === 1 });
    }
    return out;
  }
  readonly property var days: {
    if (!ok)
      return [];
    const d = data.daily;
    return d.time.map((t, i) => ({
          date: at(t),
          code: d.weather_code[i],
          max: Math.round(d.temperature_2m_max[i]),
          min: Math.round(d.temperature_2m_min[i]),
          pop: d.precipitation_probability_max[i] || 0
        })).slice(0, 6);
  }
  readonly property date sunrise: ok ? at(data.daily.sunrise[0]) : new Date(0)
  readonly property date sunset: ok ? at(data.daily.sunset[0]) : new Date(0)

  function iconFor(c, day) {
    if (c < 0)
      return "cloud_off";
    if (c === 0)
      return day ? "sunny" : "clear_night";
    if (c <= 2)
      return day ? "partly_cloudy_day" : "partly_cloudy_night";
    if (c === 3)
      return "cloud";
    if (c === 45 || c === 48)
      return "foggy";
    if (c >= 95)
      return "thunderstorm";
    if ((c >= 71 && c <= 77) || c === 85 || c === 86)
      return "weather_snowy";
    if (c === 65 || c === 67 || c === 82)
      return "rainy_heavy";
    if (c >= 51 && c <= 57)
      return "rainy_light";
    return "rainy";
  }
  // wmo weather interpretation codes
  function describe(c) {
    const names = {
      0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Rime fog",
      51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
      61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain",
      71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
      80: "Showers", 81: "Showers", 82: "Violent showers", 85: "Snow showers", 86: "Snow showers",
      95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail"
    };
    return c < 0 ? (error || "No data") : names[c] || "Unknown";
  }

  function refresh() {
    if (loading)
      return;
    loading = true;
    const q = "latitude=" + place.lat + "&longitude=" + place.lon + "&temperature_unit=" + unit + "&timezone=auto&forecast_days=7" + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,precipitation,wind_speed_10m" + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max" + "&minutely_15=precipitation&forecast_minutely_15=8";
    const xhr = new XMLHttpRequest();
    request = xhr;
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
        return;
      request = null;
      loading = false;
      watchdog.stop();
      if (xhr.status !== 200) {
        error = xhr.status === 0 ? "Offline" : "HTTP " + xhr.status;
        return;
      }
      try {
        ingest(xhr.responseText, Date.now());
        cache.setText(JSON.stringify({ fetchedAt: fetchedAt, data: data }));
      } catch (e) {
        error = "Bad response";
      }
    };
    xhr.open("GET", "https://api.open-meteo.com/v1/forecast?" + q);
    xhr.send();
    watchdog.restart();
  }
  property var request: null

  function ingest(text, when) {
    data = JSON.parse(text);
    fetchedAt = when;
    error = "";
    checkRain();
  }

  // one toast per dry spell when the next hour turns wet
  function checkRain() {
    const m = data.minutely_15;
    if (!m)
      return;
    const soon = m.precipitation.slice(1, 5).findIndex(p => p >= 0.2);
    if (soon < 0 || current.precipitation >= 0.2) {
      rainWarned = current.precipitation >= 0.2;
      return;
    }
    if (rainWarned)
      return;
    rainWarned = true;
    const when = Qt.formatTime(at(m.time[soon + 1]), "hh:mm");
    Quickshell.execDetached(["notify-send", "-a", "Weather", "-i", "weather-showers", "Rain soon", "Expected around " + when + (place.name ? " in " + place.name : "")]);
  }

  Timer {
    id: watchdog
    interval: 20000
    onTriggered: {
      const xhr = root.request;
      root.request = null;
      root.loading = false;
      root.error = "Timed out";
      if (xhr)
        xhr.abort();
    }
  }

  Timer {
    interval: 20 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  FileView {
    id: cache
    path: Quickshell.statePath("weather.json")
    printErrors: false
    onLoaded: {
      try {
        const c = JSON.parse(text());
        if (!root.data && c.data) {
          root.data = c.data;
          root.fetchedAt = c.fetchedAt;
        }
      } catch (e) {}
      root.refresh();
    }
    onLoadFailed: root.refresh()
  }
}
