// ══════════════════════════════════════════════════════
//  AUTH GUARD
// ══════════════════════════════════════════════════════
function requireAuth(){
  if(sessionStorage.getItem('parkAuth')!=='1'){
    window.location.href='login.html';return false;
  }return true;
}

function logout(){
  sessionStorage.clear();
  window.location.href='login.html';
}

// ══════════════════════════════════════════════════════
//  LAYOUT BUILDER
// ══════════════════════════════════════════════════════
function buildLayout(pageTitle, activePage){
  if(!requireAuth()) return;

  const email = sessionStorage.getItem('parkEmail')||'admin@parking.tn';
  const init  = email.charAt(0).toUpperCase();

  const navItems = [
    {id:'accueil',      href:'index.html',        icon:'fa-house',          label:'Accueil'},
    {id:'parkings',     href:'parkings.html',      icon:'fa-square-parking', label:'Gestion Parkings'},
    {id:'utilisateurs', href:'utilisateurs.html',  icon:'fa-users',          label:'Gestion Utilisateurs'},
    {id:'agent',        href:'agents.html',  icon:'fa-shield-halved',  label:'Gestion Agents'},
    {id:'statistiques', href:'statistiques.html',  icon:'fa-chart-line',     label:'Statistiques'},
    {id:'avis',         href:'avis.html',          icon:'fa-star',           label:'Avis Clients'},
  ];

  const sidebarHTML = `
  <aside class="sidebar">
    <div class="sidebar-top">
      <div class="s-logo-mark">P</div>
      <div>
        <div class="s-logo-txt">Park<span>Admin</span></div>
        <div class="s-logo-sub">Administration</div>
      </div>
    </div>
    <div class="sidebar-body">
      <div class="nav-section-label">Menu principal</div>
      ${navItems.map(n=>`
        <a class="nav-link${n.id===activePage?' active':''}" href="${n.href}">
          <span class="nav-icon-wrap"><i class="fa-solid ${n.icon}"></i></span>
          <span>${n.label}</span>
        </a>
      `).join('')}
    </div>
    <div class="sidebar-bottom">
      <div class="admin-row">
        <div class="admin-av">${init}</div>
        <div>
          <div class="admin-name">Administrateur</div>
          <div class="admin-role">${email}</div>
        </div>
      </div>
      <a class="logout-link" href="#" onclick="logout()">
        <i class="fa-solid fa-right-from-bracket"></i> Déconnexion
      </a>
    </div>
  </aside>`;

  const topbarHTML = `
  <header class="topbar">
    <div class="topbar-left">
      <span class="topbar-breadcrumb">ParkAdmin /</span>
      <span class="topbar-title">${pageTitle}</span>
    </div>
    <div class="topbar-search" style="position:relative">
      <span class="topbar-search-ico"><i class="fa-solid fa-magnifying-glass"></i></span>
      <input type="text" id="globalSearch"
        placeholder="Rechercher parking, client, agent..."
        autocomplete="off"
        oninput="handleGlobalSearch(this.value)"
        onblur="setTimeout(()=>hideSearchDropdown(),320)">
      <div id="searchDropdown"></div>
    </div>
    <div class="topbar-right">
      <span class="top-clock" id="clock">--:--:--</span>
      <div class="topbar-bell" onclick="toast('Aucune nouvelle notification','info')" style="cursor:pointer">
        <i class="fa-solid fa-bell"></i><span class="bell-dot"></span>
      </div>
      <div class="topbar-profile">
        <div class="tp-av">${init}</div>
        <div>
          <div class="tp-name">Administrateur</div>
          <div class="tp-role">${email}</div>
        </div>
        <span class="tp-chevron">▾</span>
      </div>
    </div>
  </header>`;

  document.body.insertAdjacentHTML('afterbegin', sidebarHTML + topbarHTML);

  // Font Awesome
  if(!document.querySelector('link[href*="font-awesome"]')){
    const fa=document.createElement('link');
    fa.rel='stylesheet';
    fa.href='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css';
    document.head.appendChild(fa);
  }

  if(!document.getElementById('toast-area')){
    const ta=document.createElement('div');ta.id='toast-area';document.body.appendChild(ta);
  }

  // Horloge
  function tick(){
    const n=new Date();
    const t=`${String(n.getHours()).padStart(2,'0')}:${String(n.getMinutes()).padStart(2,'0')}:${String(n.getSeconds()).padStart(2,'0')}`;
    const el=document.getElementById('clock');if(el)el.textContent=t;
  }
  tick();setInterval(tick,1000);

  // Injecter styles search + modal
  _injectSearchStyles();
  _injectDetailModal();
}

// ══════════════════════════════════════════════════════
//  STYLES SEARCH DROPDOWN + MODAL DÉTAIL
// ══════════════════════════════════════════════════════
function _injectSearchStyles(){
  if(document.getElementById('_searchStyles')) return;
  const s=document.createElement('style');
  s.id='_searchStyles';
  s.textContent=`
    #searchDropdown{
      display:none;position:absolute;top:110%;left:0;right:0;
      background:#fff;border:1px solid #e2e8f0;border-radius:14px;
      box-shadow:0 12px 32px rgba(0,0,0,0.13);z-index:9999;
      max-height:420px;overflow-y:auto;
    }
    .sd-header{
      padding:.5rem 1rem;font-size:10px;font-weight:700;
      text-transform:uppercase;letter-spacing:.1em;color:#94a3b8;
      border-bottom:1px solid #f1f5f9;
    }
    .sd-item{
      display:flex;align-items:center;gap:.8rem;
      padding:.7rem 1rem;text-decoration:none;color:inherit;
      cursor:pointer;border-bottom:1px solid #f8fafc;
      transition:background .15s;
    }
    .sd-item:hover{ background:#f8fafc; }
    .sd-item:last-child{ border-bottom:none; }
    .sd-icon{
      width:36px;height:36px;border-radius:9px;flex-shrink:0;
      display:flex;align-items:center;justify-content:center;font-size:14px;
    }
    .sd-title{
      font-size:13px;font-weight:600;color:#1e293b;
      white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
    }
    .sd-sub{
      font-size:11px;color:#94a3b8;
      white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
    }
    .sd-badge{
      font-size:10px;font-weight:700;padding:2px 9px;
      border-radius:20px;flex-shrink:0;white-space:nowrap;
    }
    .sd-empty{ padding:1.4rem;text-align:center;color:#94a3b8;font-size:13px; }
    .sd-more{ padding:.6rem 1rem;font-size:11px;color:#94a3b8;text-align:center; }

    /* ── MODAL DÉTAIL ── */
    #detailOverlay{
      display:none;position:fixed;inset:0;background:rgba(15,23,42,.45);
      z-index:10000;align-items:center;justify-content:center;padding:1rem;
    }
    #detailOverlay.open{ display:flex; }
    #detailBox{
      background:#fff;border-radius:20px;width:100%;max-width:520px;
      box-shadow:0 24px 60px rgba(0,0,0,0.22);overflow:hidden;
      animation:detailIn .25s ease;
    }
    @keyframes detailIn{
      from{opacity:0;transform:translateY(18px) scale(.97)}
      to{opacity:1;transform:translateY(0) scale(1)}
    }
    #detailBox .d-head{
      padding:1.4rem 1.6rem 1rem;display:flex;align-items:center;gap:1rem;
      border-bottom:1px solid #f1f5f9;
    }
    #detailBox .d-avatar{
      width:52px;height:52px;border-radius:14px;flex-shrink:0;
      display:flex;align-items:center;justify-content:center;font-size:22px;
    }
    #detailBox .d-head-info{ flex:1;min-width:0; }
    #detailBox .d-name{
      font-size:16px;font-weight:700;color:#1e293b;
      white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
    }
    #detailBox .d-type{
      font-size:11px;font-weight:700;padding:2px 10px;border-radius:20px;
      display:inline-block;margin-top:4px;
    }
    #detailBox .d-close{
      width:32px;height:32px;border-radius:8px;border:1px solid #e2e8f0;
      background:none;cursor:pointer;font-size:16px;color:#64748b;
      display:flex;align-items:center;justify-content:center;flex-shrink:0;
    }
    #detailBox .d-close:hover{ background:#f1f5f9; }
    #detailBox .d-body{ padding:1.2rem 1.6rem 1.4rem; }
    #detailBox .d-grid{
      display:grid;grid-template-columns:1fr 1fr;gap:.75rem;
    }
    #detailBox .d-field{
      background:#f8fafc;border-radius:10px;padding:.7rem .9rem;
    }
    #detailBox .d-field.full{ grid-column:1/-1; }
    #detailBox .d-label{
      font-size:10px;font-weight:700;text-transform:uppercase;
      letter-spacing:.08em;color:#94a3b8;margin-bottom:4px;
    }
    #detailBox .d-value{
      font-size:13px;font-weight:600;color:#1e293b;
      word-break:break-all;
    }
    #detailBox .d-value.green{ color:#10b981; }
    #detailBox .d-value.red{   color:#ef4444; }
    #detailBox .d-value.amber{ color:#f59e0b; }
    #detailBox .d-footer{
      padding:.9rem 1.6rem;border-top:1px solid #f1f5f9;
      display:flex;gap:.6rem;justify-content:flex-end;
    }
    #detailBox .d-btn{
      padding:.5rem 1.1rem;border-radius:8px;font-size:12px;
      font-weight:600;cursor:pointer;border:none;transition:opacity .15s;
    }
    #detailBox .d-btn:hover{ opacity:.85; }
    #detailBox .d-btn-go{
      background:#6366f1;color:#fff;
    }
    #detailBox .d-btn-close{
      background:#f1f5f9;color:#64748b;
    }

    /* Stat chips dans modal parking */
    #detailBox .d-chips{
      display:flex;gap:.5rem;flex-wrap:wrap;margin-top:.5rem;
    }
    #detailBox .d-chip{
      font-size:11px;font-weight:700;padding:4px 10px;
      border-radius:8px;
    }

    @keyframes toastIn{from{opacity:0;transform:translateX(20px)}to{opacity:1;transform:translateX(0)}}
    @keyframes toastOut{from{opacity:1;transform:translateX(0)}to{opacity:0;transform:translateX(20px)}}
  `;
  document.head.appendChild(s);
}

// ══════════════════════════════════════════════════════
//  MODAL DÉTAIL — injection DOM
// ══════════════════════════════════════════════════════
function _injectDetailModal(){
  if(document.getElementById('detailOverlay')) return;
  const ov=document.createElement('div');
  ov.id='detailOverlay';
  ov.innerHTML=`<div id="detailBox"></div>`;
  ov.addEventListener('click', e=>{if(e.target===ov) closeDetailModal();});
  document.body.appendChild(ov);
}

function closeDetailModal(){
  const ov=document.getElementById('detailOverlay');
  if(ov) ov.classList.remove('open');
}

// ══════════════════════════════════════════════════════
//  OUVRE MODAL AVEC CONTENU SELON TYPE
// ══════════════════════════════════════════════════════
function openDetailModal(item){
  const box=document.getElementById('detailBox');
  const ov =document.getElementById('detailOverlay');
  if(!box||!ov) return;

  let html='';

  // ── PARKING ────────────────────────────────────────
  if(item._type==='parking'){
    const free     = (item.totalSpots||0)-(item.occupiedSpots||0);
    const rate     = item.totalSpots ? Math.round((item.occupiedSpots||0)/item.totalSpots*100) : 0;
    const rateClr  = rate>=80?'red':rate>=50?'amber':'green';
    const isOpen   = item.isOpen!==false;
    const typeIcon = {vip:'⭐',couvert:'🏗️',souterrain:'🔽',pmr:'♿'}[item.type]||'🅿️';

    html=`
      <div class="d-head">
        <div class="d-avatar" style="background:#6366f118;font-size:26px">${typeIcon}</div>
        <div class="d-head-info">
          <div class="d-name">${item.name||item.nom||'—'}</div>
          <span class="d-type" style="background:#6366f118;color:#6366f1">
            <i class="fa-solid fa-square-parking"></i> Parking
          </span>
        </div>
        <button class="d-close" onclick="closeDetailModal()">✕</button>
      </div>
      <div class="d-body">
        <div class="d-grid">
          <div class="d-field full">
            <div class="d-label">Adresse</div>
            <div class="d-value">${item.address||item.adresse||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Statut</div>
            <div class="d-value ${isOpen?'green':'red'}">${isOpen?'✅ Ouvert':'🔴 Fermé'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Type</div>
            <div class="d-value">${item.type||'Standard'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Prix / heure</div>
            <div class="d-value amber">${item.pricePerHour||item.tarif||0} DT / h</div>
          </div>
          <div class="d-field">
            <div class="d-label">Horaires</div>
            <div class="d-value">${item.openHours||'24h/24'}</div>
          </div>
          <div class="d-field full">
            <div class="d-label">Occupation</div>
            <div style="margin-top:6px;height:8px;background:#f1f5f9;border-radius:4px;overflow:hidden">
              <div style="height:100%;width:${rate}%;background:${rate>=80?'#ef4444':rate>=50?'#f59e0b':'#10b981'};border-radius:4px;transition:width .4s"></div>
            </div>
            <div class="d-chips" style="margin-top:8px">
              <span class="d-chip" style="background:#6366f118;color:#6366f1">
                Total : ${item.totalSpots||0}
              </span>
              <span class="d-chip" style="background:#ef444418;color:#ef4444">
                Occupées : ${item.occupiedSpots||0}
              </span>
              <span class="d-chip" style="background:#10b98118;color:#10b981">
                Libres : ${free}
              </span>
              <span class="d-chip" style="background:${rate>=80?'#ef444418':rate>=50?'#f59e0b18':'#10b98118'};color:${rate>=80?'#ef4444':rate>=50?'#f59e0b':'#10b981'}">
                ${rate}% occupé
              </span>
            </div>
          </div>
          ${item.latitude&&item.longitude?`
          <div class="d-field full">
            <div class="d-label">Coordonnées GPS</div>
            <div class="d-value">${item.latitude.toFixed(5)}, ${item.longitude.toFixed(5)}</div>
          </div>`:''}
        </div>
      </div>
      <div class="d-footer">
        <button class="d-btn d-btn-close" onclick="closeDetailModal()">Fermer</button>
        <button class="d-btn d-btn-go" onclick="closeDetailModal();window.location.href='parkings.html'">
          <i class="fa-solid fa-arrow-right"></i> Voir dans Parkings
        </button>
      </div>
    `;
  }

  // ── CLIENT ─────────────────────────────────────────
  else if(item._type==='client'){
    const sub  = item.subscription||'standard';
    const subLabel = sub==='vip'?'⭐ VIP':sub==='premium'?'🌟 Premium':'Standard';
    const subClr   = sub==='vip'?'#f59e0b':sub==='premium'?'#8b5cf6':'#6366f1';
    const nameParts = (item.name||item.nom||'?').trim();
    const avatar    = nameParts.charAt(0).toUpperCase();

    html=`
      <div class="d-head">
        <div class="d-avatar" style="background:#10b98118;color:#10b981;font-size:20px;font-weight:800">
          ${avatar}
        </div>
        <div class="d-head-info">
          <div class="d-name">${nameParts}</div>
          <span class="d-type" style="background:#10b98118;color:#10b981">
            <i class="fa-solid fa-user"></i> Client
          </span>
        </div>
        <button class="d-close" onclick="closeDetailModal()">✕</button>
      </div>
      <div class="d-body">
        <div class="d-grid">
          <div class="d-field full">
            <div class="d-label">Email</div>
            <div class="d-value">${item.email||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Téléphone</div>
            <div class="d-value">${item.phone||item.tel||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Abonnement</div>
            <div class="d-value" style="color:${subClr}">${subLabel}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Plaque</div>
            <div class="d-value">${item.vehiclePlate||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Véhicule</div>
            <div class="d-value">${item.vehicleModel||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Solde</div>
            <div class="d-value amber">${item.balance||0} DT</div>
          </div>
          <div class="d-field full">
            <div class="d-label">Membre depuis</div>
            <div class="d-value">${item.createdAt?.seconds
              ? new Date(item.createdAt.seconds*1000).toLocaleDateString('fr-FR',{day:'2-digit',month:'long',year:'numeric'})
              : '—'
            }</div>
          </div>
        </div>
      </div>
      <div class="d-footer">
        <button class="d-btn d-btn-close" onclick="closeDetailModal()">Fermer</button>
        <button class="d-btn d-btn-go" onclick="closeDetailModal();window.location.href='utilisateurs.html'">
          <i class="fa-solid fa-arrow-right"></i> Voir dans Clients
        </button>
      </div>
    `;
  }

  // ── AGENT ──────────────────────────────────────────
  else if(item._type==='agent'){
    const nameParts = (item.name||item.nom||'?').trim();
    const avatar    = nameParts.charAt(0).toUpperCase();

    html=`
      <div class="d-head">
        <div class="d-avatar" style="background:#f59e0b18;color:#f59e0b;font-size:20px;font-weight:800">
          ${avatar}
        </div>
        <div class="d-head-info">
          <div class="d-name">${nameParts}</div>
          <span class="d-type" style="background:#f59e0b18;color:#f59e0b">
            <i class="fa-solid fa-shield-halved"></i> Agent de Parking
          </span>
        </div>
        <button class="d-close" onclick="closeDetailModal()">✕</button>
      </div>
      <div class="d-body">
        <div class="d-grid">
          <div class="d-field full">
            <div class="d-label">Email</div>
            <div class="d-value">${item.email||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Téléphone</div>
            <div class="d-value">${item.phone||item.tel||'—'}</div>
          </div>
          <div class="d-field">
            <div class="d-label">Zone assignée</div>
            <div class="d-value">${item.zoneName||item.zone||'—'}</div>
          </div>
          <div class="d-field full">
            <div class="d-label">Shift</div>
            <div class="d-value">${item.shift||'—'}</div>
          </div>
          <div class="d-field full">
            <div class="d-label">Membre depuis</div>
            <div class="d-value">${item.createdAt?.seconds
              ? new Date(item.createdAt.seconds*1000).toLocaleDateString('fr-FR',{day:'2-digit',month:'long',year:'numeric'})
              : '—'
            }</div>
          </div>
        </div>
      </div>
      <div class="d-footer">
        <button class="d-btn d-btn-close" onclick="closeDetailModal()">Fermer</button>
        <button class="d-btn d-btn-go" onclick="closeDetailModal();window.location.href='responsables.html'">
          <i class="fa-solid fa-arrow-right"></i> Voir dans Agents
        </button>
      </div>
    `;
  }

  box.innerHTML=html;
  ov.classList.add('open');

  // Fermer avec Escape
  const onKey=e=>{ if(e.key==='Escape'){ closeDetailModal(); document.removeEventListener('keydown',onKey); } };
  document.addEventListener('keydown',onKey);
}

// ══════════════════════════════════════════════════════
//  FIREBASE LOADER (singleton)
// ══════════════════════════════════════════════════════
let _searchData = null;

async function _loadSearchData(){
  if(_searchData) return _searchData;
  try{
    const {initializeApp,getApps} = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js');
    const {getFirestore,collection,getDocs} = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js');

    const cfg={
      apiKey:"AIzaSyCi-UTQReIk0l5gA9ayDNgUrEIXWteDPXQ",
      authDomain:"pfes-5bb45.firebaseapp.com",
      projectId:"pfes-5bb45",
      storageBucket:"pfes-5bb45.appspot.com",
      messagingSenderId:"857843523698",
      appId:"1:857843523698:web:a8cd7566edb367eee6e2eb"
    };
    const app = getApps().length ? getApps()[0] : initializeApp(cfg);
    const db  = getFirestore(app);

    const [zonesSnap,usersSnap,adminsSnap] = await Promise.all([
      getDocs(collection(db,'zones')),
      getDocs(collection(db,'users')),
      getDocs(collection(db,'admins')),
    ]);

    const zones=[],users=[],agents=[];
    zonesSnap.forEach(d=>zones.push({id:d.id,...d.data()}));
    usersSnap.forEach(d=>users.push({id:d.id,...d.data()}));
    adminsSnap.forEach(d=>{
      const data=d.data();
      // Supporte 'agent' et 'responsable' (rétro-compat)
      if(data.role==='agent'||data.role==='responsable')
        agents.push({id:d.id,...data});
    });

    _searchData={zones,users,agents};
    return _searchData;
  }catch(e){
    console.error(e);
    return {zones:[],users:[],agents:[]};
  }
}

// ══════════════════════════════════════════════════════
//  GLOBAL SEARCH — avec ouverture modal au clic
// ══════════════════════════════════════════════════════
let _searchTimer=null;

async function handleGlobalSearch(val){
  const dropdown=document.getElementById('searchDropdown');
  if(!val||val.trim().length<2){ dropdown.style.display='none'; return; }

  clearTimeout(_searchTimer);
  _searchTimer=setTimeout(async()=>{
    dropdown.style.display='block';
    dropdown.innerHTML=`
      <div class="sd-empty">
        <i class="fa-solid fa-spinner fa-spin" style="font-size:1.2rem;margin-bottom:6px;display:block"></i>
        Recherche en cours...
      </div>`;

    const q=val.toLowerCase();
    const data=await _loadSearchData();
    const results=[];

    // ── Parkings ──
    data.zones
      .filter(z=>(z.name||z.nom||'').toLowerCase().includes(q)
             ||(z.address||z.adresse||'').toLowerCase().includes(q)
             ||(z.type||'').toLowerCase().includes(q))
      .forEach(z=>results.push({
        _type:'parking', ...z,
        _icon:'fa-square-parking', _color:'#6366f1',
        _typeLabel:'Parking',
        _title: z.name||z.nom||'—',
        _sub: `${z.address||z.adresse||'—'} · ${z.freeSpots!==undefined?z.freeSpots:(z.totalSpots||0)-(z.occupiedSpots||0)} places libres`,
      }));

    // ── Clients ──
    data.users
      .filter(u=>(u.name||u.nom||'').toLowerCase().includes(q)
             ||(u.email||'').toLowerCase().includes(q)
             ||(u.vehiclePlate||'').toLowerCase().includes(q)
             ||(u.phone||'').toLowerCase().includes(q))
      .forEach(u=>results.push({
        _type:'client', ...u,
        _icon:'fa-user', _color:'#10b981',
        _typeLabel:'Client',
        _title: u.name||u.nom||'—',
        _sub: `${u.email||'—'} · ${u.vehiclePlate||'Sans véhicule'}`,
      }));

    // ── Agents ──
    data.agents
      .filter(a=>(a.name||a.nom||'').toLowerCase().includes(q)
             ||(a.email||'').toLowerCase().includes(q)
             ||(a.zoneName||a.zone||'').toLowerCase().includes(q)
             ||(a.phone||'').toLowerCase().includes(q))
      .forEach(a=>results.push({
        _type:'agent', ...a,
        _icon:'fa-shield-halved', _color:'#f59e0b',
        _typeLabel:'Agent',
        _title: a.name||a.nom||'—',
        _sub: `${a.email||'—'} · Zone: ${a.zoneName||a.zone||'—'}`,
      }));

    if(results.length===0){
      dropdown.innerHTML=`
        <div class="sd-empty">
          <i class="fa-solid fa-search" style="font-size:1.4rem;margin-bottom:8px;display:block;color:#cbd5e1"></i>
          Aucun résultat pour <strong>"${val}"</strong>
        </div>`;
      return;
    }

    // Stocker les données pour récupération au clic
    window._searchResults=results;

    dropdown.innerHTML=`
      <div class="sd-header">${results.length} résultat${results.length>1?'s':''}</div>
      ${results.slice(0,8).map((r,i)=>`
        <div class="sd-item" onmousedown="event.preventDefault()" onclick="hideSearchDropdown();openDetailModal(window._searchResults[${i}])">
          <div class="sd-icon" style="background:${r._color}18">
            <i class="fa-solid ${r._icon}" style="color:${r._color}"></i>
          </div>
          <div style="flex:1;min-width:0">
            <div class="sd-title">${r._title}</div>
            <div class="sd-sub">${r._sub}</div>
          </div>
          <span class="sd-badge" style="background:${r._color}18;color:${r._color}">
            ${r._typeLabel}
          </span>
        </div>
      `).join('')}
      ${results.length>8?`<div class="sd-more">+${results.length-8} autres résultats — affinez votre recherche</div>`:''}
    `;
  },280);
}

function hideSearchDropdown(){
  const d=document.getElementById('searchDropdown');
  if(d) d.style.display='none';
}

// ══════════════════════════════════════════════════════
//  MODAL GÉNÉRIQUE (pour les autres pages)
// ══════════════════════════════════════════════════════
function openModal(id){ const el=document.getElementById(id);if(el)el.classList.add('open'); }
function closeModal(id){ const el=document.getElementById(id);if(el)el.classList.remove('open'); }

// ══════════════════════════════════════════════════════
//  TOAST
// ══════════════════════════════════════════════════════
const TOAST_COLORS={success:'#10b981',danger:'#ef4444',warning:'#f59e0b',info:'#6366f1'};

function toast(msg,type='success'){
  const area=document.getElementById('toast-area');if(!area)return;
  const t=document.createElement('div');
  const c=TOAST_COLORS[type]||TOAST_COLORS.success;
  t.style.cssText=`
    background:white;border:1px solid ${c}33;border-left:3px solid ${c};
    color:#1e1e2e;padding:.75rem 1.2rem;font-family:'Plus Jakarta Sans',sans-serif;
    font-size:13px;animation:toastIn .3s ease;min-width:220px;
    box-shadow:0 8px 24px rgba(0,0,0,.1);display:flex;align-items:center;gap:.5rem;
    border-radius:10px;
  `;
  t.innerHTML=`<span style="color:${c};font-size:16px">●</span>${msg}`;
  area.appendChild(t);
  setTimeout(()=>{
    t.style.animation='toastOut .3s ease forwards';
    setTimeout(()=>t.remove(),300);
  },3200);
}

// ══════════════════════════════════════════════════════
//  TABLE FILTER
// ══════════════════════════════════════════════════════
function filterTable(inputId,tableId){
  const v=document.getElementById(inputId).value.toLowerCase();
  document.querySelectorAll(`#${tableId} tbody tr`).forEach(r=>{
    r.style.display=r.textContent.toLowerCase().includes(v)?'':'none';
  });
}