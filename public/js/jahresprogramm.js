(async () => {
    const listEl = document.getElementById('events-list');
    if (!listEl) return;
  
    const limitAttr = listEl.getAttribute('data-limit');
    const limit = limitAttr ? parseInt(limitAttr, 10) : null;
  
    try {
      const res = await fetch('/data/jahresprogramm.json', { cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
  
      let events = Array.isArray(data.events) ? data.events : [];
  
      // Sortierung nach ISO-Datum (aufsteigend)
      events.sort((a, b) => (a.date_iso || '').localeCompare(b.date_iso || ''));
  
      // nur kommende Events (heute + Zukunft)
      const todayIso = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
      events = events.filter(ev => (ev.date_iso || '') >= todayIso);
  
      // Limit (Index/Anlässe)
      if (limit && limit > 0) events = events.slice(0, limit);
  
      listEl.innerHTML = '';
  
      if (!events.length) {
        listEl.innerHTML = '<p>Aktuell sind keine bevorstehenden Anlässe erfasst.</p>';
        return;
      }
  
      for (const ev of events) {
        const card = document.createElement('div');
        card.className = 'event-card';
  
        // ISO nur für Ordnung/Debug als Attribut, NICHT sichtbar
        if (ev.date_iso) card.setAttribute('data-date', ev.date_iso);
  
        const metaLine = ev.meta
          ? `<div class="meta">${ev.meta}</div>`
          : '';
  
        const timeLine = ev.time
          ? `<p><strong>Uhrzeit:</strong> ${ev.time} Uhr</p>`
          : '';
  
        card.innerHTML = `
          <h3>${ev.title_date || ''}</h3>
          ${metaLine}
          ${ev.text_html ? `<p>${ev.text_html}</p>` : ''}
          ${timeLine}
        `;
  
        listEl.appendChild(card);
      }
    } catch (err) {
      console.error('Jahresprogramm konnte nicht geladen werden:', err);
      listEl.innerHTML = '<p>Jahresprogramm konnte nicht geladen werden.</p>';
    }
  })();
  
  // test zum refresh
  