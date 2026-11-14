(() => {
  const $ = selector => document.querySelector(selector);
  const state = { apiBase: 'http://localhost:3000/api', token: '', dispatcher: null, incidents: [], selectedId: null, polling: null, map: null, markers: new Map(), loading: false };

  function escapeHTML(value) {
    return String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
  }

  function showToast(message) {
    const toast = $('#toast');
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(showToast.timer);
    showToast.timer = setTimeout(() => toast.classList.remove('show'), 2600);
  }

  async function request(path, options = {}) {
    const response = await fetch(`${state.apiBase}${path}`, {
      ...options,
      headers: { 'Content-Type': 'application/json', ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}), ...(options.headers || {}) }
    });
    const payload = response.status === 204 ? {} : await response.json().catch(() => ({}));
    if (!response.ok) {
      if (response.status === 401) signOut();
      throw new Error(payload.error || `Request failed (${response.status})`);
    }
    return payload;
  }

  async function login(event) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const button = $('#loginSubmit');
    button.disabled = true;
    button.textContent = 'Connecting…';
    $('#loginError').textContent = '';
    state.apiBase = $('#apiBase').value.replace(/\/$/, '');
    try {
      const payload = await request('/dispatch/login', {
        method: 'POST',
        body: JSON.stringify({ email: form.get('email'), password: form.get('password') })
      });
      state.token = payload.token;
      state.dispatcher = payload.user;
      sessionStorage.setItem('resqdrive_dispatch_token', state.token);
      sessionStorage.setItem('resqdrive_dispatch_user', JSON.stringify(state.dispatcher));
      enterDashboard();
    } catch (error) {
      $('#loginError').textContent = error.message;
    } finally {
      button.disabled = false;
      button.innerHTML = 'Sign in <span aria-hidden="true">→</span>';
    }
  }

  function enterDashboard() {
    $('#loginView').hidden = true;
    $('#dashboardView').hidden = false;
    $('#dispatcherName').textContent = state.dispatcher?.fullName || 'Dispatcher';
    initializeMap();
    refreshIncidents();
    clearInterval(state.polling);
    state.polling = setInterval(refreshIncidents, 5000);
  }

  function signOut() {
    clearInterval(state.polling);
    state.token = '';
    state.dispatcher = null;
    sessionStorage.removeItem('resqdrive_dispatch_token');
    sessionStorage.removeItem('resqdrive_dispatch_user');
    $('#dashboardView').hidden = true;
    $('#loginView').hidden = false;
    setNetwork(false, 'SIGNED OUT');
  }

  function initializeMap() {
    if (state.map || !window.L) return;
    state.map = L.map('map', { scrollWheelZoom: false, zoomControl: true }).setView([37.7749, -122.4194], 11);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(state.map);
  }

  function normalizeIncidents(rows) {
    const records = new Map();
    rows.forEach(row => {
      const id = String(row.accident_id);
      if (!records.has(id)) records.set(id, { ...row, accident_id: id, contacts: [] });
      const record = records.get(id);
      if (row.contact_id && !record.contacts.some(contact => String(contact.id) === String(row.contact_id))) {
        record.contacts.push({ id: row.contact_id, name: row.contact_name, phone: row.contact_phone, email: row.contact_email, channel: row.alert_channel, status: row.alert_delivery_status });
      }
    });
    return [...records.values()].sort((a, b) => new Date(a.detected_at) - new Date(b.detected_at));
  }

  async function refreshIncidents() {
    if (state.loading || !state.token) return;
    state.loading = true;
    try {
      const payload = await request('/dispatch/active');
      state.incidents = normalizeIncidents(payload.accidents || []);
      if (!state.incidents.some(item => item.accident_id === state.selectedId)) state.selectedId = state.incidents[0]?.accident_id || null;
      render();
      setNetwork(true, 'CONNECTED');
      $('#apiStatus').textContent = 'API connected';
      $('#lastUpdated').textContent = `Updated ${new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', second: '2-digit' })}`;
    } catch (error) {
      setNetwork(false, 'CONNECTION ISSUE');
      $('#apiStatus').textContent = error.message;
      $('#lastUpdated').textContent = 'Retrying in 5 sec';
    } finally {
      state.loading = false;
    }
  }

  function setNetwork(connected, label) {
    const stateElement = $('.network-state');
    stateElement.classList.toggle('offline', !connected);
    $('#networkLabel').textContent = label;
  }

  function formatAge(dateValue) {
    const seconds = Math.max(0, Math.floor((Date.now() - new Date(dateValue).getTime()) / 1000));
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    return `${Math.floor(seconds / 3600)}h ${Math.floor(seconds % 3600 / 60)}m`;
  }

  function render() {
    const incidents = state.incidents;
    const selected = incidents.find(item => item.accident_id === state.selectedId);
    $('#activeCount').textContent = incidents.length;
    $('#contactCount').textContent = incidents.reduce((count, incident) => count + incident.contacts.length, 0);
    $('#oldestAge').textContent = incidents.length ? formatAge(incidents[0].detected_at) : '—';
    $('#queueLabel').textContent = `${incidents.length} active`;
    renderList(incidents);
    renderMarkers(incidents);
    renderDetails(selected);
  }

  function renderList(incidents) {
    const container = $('#incidentList');
    if (!incidents.length) {
      container.innerHTML = '<div class="empty-list"><span>✓</span><strong>No active incidents</strong><span>New crash reports will appear here.</span></div>';
      return;
    }
    container.innerHTML = incidents.map(item => `
      <button class="incident-card ${item.accident_id === state.selectedId ? 'selected' : ''}" data-incident-id="${escapeHTML(item.accident_id)}">
        <span class="incident-indicator"></span><span class="incident-main"><strong class="incident-title">${escapeHTML(item.driver_name || 'Unknown driver')} · ${escapeHTML(item.vehicle_model || item.plate_number || 'Vehicle unavailable')}</strong><span class="incident-address">${Number(item.latitude).toFixed(4)}, ${Number(item.longitude).toFixed(4)} · ${escapeHTML(item.status)}</span><span class="incident-driver">${escapeHTML(item.driver_phone || item.driver_email || 'No driver contact')}</span></span><span class="incident-time">${formatAge(item.detected_at)}</span>
      </button>`).join('');
    container.querySelectorAll('[data-incident-id]').forEach(button => button.addEventListener('click', () => {
      state.selectedId = button.dataset.incidentId;
      render();
    }));
  }

  function renderMarkers(incidents) {
    if (!state.map) return;
    const activeIds = new Set(incidents.map(item => item.accident_id));
    for (const [id, marker] of state.markers) {
      if (!activeIds.has(id)) {
        state.map.removeLayer(marker);
        state.markers.delete(id);
      }
    }
    incidents.forEach(item => {
      const point = [Number(item.latitude), Number(item.longitude)];
      let marker = state.markers.get(item.accident_id);
      if (!marker) {
        marker = L.circleMarker(point, { radius: 8, color: '#fff', weight: 2, fillColor: '#d93430', fillOpacity: 1 }).addTo(state.map);
        marker.on('click', () => { state.selectedId = item.accident_id; render(); });
        state.markers.set(item.accident_id, marker);
      } else marker.setLatLng(point);
      marker.setStyle({ radius: item.accident_id === state.selectedId ? 10 : 8 });
    });
    const selected = incidents.find(item => item.accident_id === state.selectedId);
    if (selected) state.map.setView([Number(selected.latitude), Number(selected.longitude)], Math.max(state.map.getZoom(), 13), { animate: false });
    else if (incidents.length > 1) state.map.fitBounds(L.latLngBounds(incidents.map(item => [Number(item.latitude), Number(item.longitude)])), { padding: [30, 30], maxZoom: 13 });
  }

  function renderDetails(item) {
    if (!item) {
      $('#detailTitle').textContent = 'Select an incident';
      $('#detailStatus').textContent = 'WAITING';
      $('#detailContent').innerHTML = '<div class="empty-detail"><span class="empty-crosshair">⌖</span><p>Incident details will appear here</p></div>';
      return;
    }
    $('#detailTitle').textContent = `Incident #${item.accident_id}`;
    $('#detailStatus').textContent = item.status;
    $('#detailContent').innerHTML = `<div class="selected-details">
      <div class="detail-group"><span class="detail-label">DRIVER</span><strong class="detail-value">${escapeHTML(item.driver_name || 'Unknown')}</strong></div>
      <div class="detail-group"><span class="detail-label">DRIVER CONTACT</span><strong class="detail-value">${escapeHTML(item.driver_phone || item.driver_email || 'Not provided')}</strong></div>
      <div class="detail-group"><span class="detail-label">VEHICLE</span><strong class="detail-value">${escapeHTML(item.vehicle_model || 'Unknown vehicle')}</strong></div>
      <div class="detail-group"><span class="detail-label">PLATE · PEAK G</span><strong class="detail-value">${escapeHTML(item.plate_number || '—')} · ${Number(item.peak_g_force || 0).toFixed(2)}G</strong></div>
      <div class="detail-group"><span class="detail-label">REPORTED</span><strong class="detail-value">${new Date(item.detected_at).toLocaleString()}</strong></div>
      <div class="detail-group"><span class="detail-label">COORDINATES</span><strong class="detail-value">${Number(item.latitude).toFixed(5)}, ${Number(item.longitude).toFixed(5)}</strong></div>
      <div class="detail-group contacts-section"><span class="detail-label">EMERGENCY CONTACTS · ${item.contacts.length} ALERTS</span><div class="contact-chips">${item.contacts.length ? item.contacts.map(contact => `<span class="contact-chip">${escapeHTML(contact.name || 'Contact')} · ${escapeHTML(contact.phone || contact.email || contact.channel || '')}<small>${escapeHTML(contact.status || 'PENDING')}</small></span>`).join('') : '<span class="contact-chip">No emergency contact records</span>'}</div></div>
      <div class="resolve-row"><span class="resolve-note">Confirm the situation is under control before closing.</span><button class="resolve-button" id="resolveButton">Mark resolved</button></div>
    </div>`;
    $('#resolveButton').addEventListener('click', () => resolveIncident(item.accident_id));
  }

  async function resolveIncident(id) {
    const button = $('#resolveButton');
    button.disabled = true;
    button.textContent = 'Saving…';
    try {
      await request(`/dispatch/${encodeURIComponent(id)}/resolve`, { method: 'PATCH' });
      showToast(`Incident #${id} resolved`);
      await refreshIncidents();
    } catch (error) {
      showToast(error.message);
      button.disabled = false;
      button.textContent = 'Mark resolved';
    }
  }

  $('#loginForm').addEventListener('submit', login);
  $('#refreshButton').addEventListener('click', refreshIncidents);
  $('#signOutButton').addEventListener('click', signOut);
  $('#brandHome').addEventListener('click', event => { event.preventDefault(); state.selectedId = state.incidents[0]?.accident_id || null; render(); });

  const savedToken = sessionStorage.getItem('resqdrive_dispatch_token');
  const savedUser = sessionStorage.getItem('resqdrive_dispatch_user');
  if (savedToken && savedUser) {
    state.token = savedToken;
    try { state.dispatcher = JSON.parse(savedUser); } catch { signOut(); }
    if (state.dispatcher) enterDashboard();
  }
})();