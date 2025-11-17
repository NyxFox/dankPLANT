(function () {
  const els = {
    temp: document.getElementById('temp'),
    humidity: document.getElementById('humidity'),
    updated: document.getElementById('updated'),
    device: document.getElementById('device'),
    rssi: document.getElementById('rssi')
  };

  function fmtTs(epoch) {
    if (!epoch || epoch <= 0) return '—';
    try {
      const d = new Date(epoch * 1000);
      return d.toLocaleString();
    } catch (_) { return '—'; }
  }

  async function fetchSensor() {
    try {
      const res = await fetch('/api/sensor', { cache: 'no-store' });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const json = await res.json();

      if (json && json.status === 'empty') {
        els.temp.textContent = '— °C';
        els.humidity.textContent = '— %';
        els.device.textContent = '—';
        els.rssi.textContent = 'RSSI: — dBm';
        els.updated.textContent = 'Stand: ' + fmtTs(json.timestamp_server);
        return;
      }

      const t = (typeof json.temp_c === 'number') ? json.temp_c.toFixed(1) : '—';
      const h = (typeof json.humidity === 'number') ? json.humidity.toString() : '—';
      els.temp.textContent = `${t} °C`;
      els.humidity.textContent = `${h} %`;
      els.device.textContent = json.device || '—';
      els.rssi.textContent = `RSSI: ${json.rssi ?? '—'} dBm`;

      const ts = json.timestamp || json.timestamp_server;
      els.updated.textContent = 'Stand: ' + fmtTs(ts);
    } catch (err) {
      console.error('fetch sensor failed:', err);
    }
  }

  // initial + poll every 5 seconds
  fetchSensor();
  setInterval(fetchSensor, 5000);
})();
