// ── AUTH GUARD ──
function requireAuth(){
  if(sessionStorage.getItem('parkAuth')!=='1'){
    window.location.href='login.html';return false;
  }return true;
}

function logout(){
  sessionStorage.clear();
  window.location.href='login.html';
}

// ── LAYOUT BUILDER ──
function buildLayout(pageTitle, activePage){
  if(!requireAuth()) return;

  const email = sessionStorage.getItem('parkEmail')||'admin@parking.tn';
  const init = email.charAt(0).toUpperCase();

  const navItems = [
    {id:'accueil',      href:'index.html',          icon:'⊞', label:'Accueil'},
    {id:'parkings',     href:'parkings.html',        icon:'🅿', label:'Gestion Parkings', badge:'3'},
    {id:'utilisateurs', href:'utilisateurs.html',    icon:'👤', label:'Gestion Utilisateurs'},
    {id:'responsables', href:'responsables.html',    icon:'🛡', label:'Gestion Responsables'},
    {id:'statistiques', href:'statistiques.html',    icon:'📊', label:'Statistiques'},
    {id:'avis',         href:'avis.html',            icon:'⭐', label:'Avis Clients', badge:'12', badgeClass:'blue'},
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
          <span class="nav-icon-wrap">${n.icon}</span>
          <span>${n.label}</span>
          ${n.badge?`<span class="nav-badge${n.badgeClass?' '+n.badgeClass:''}">${n.badge}</span>`:''}
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
        <span>⏻</span> Déconnexion
      </a>
    </div>
  </aside>`;

  const topbarHTML = `
  <header class="topbar">
    <div class="topbar-left">
      <span class="topbar-breadcrumb">ParkAdmin /</span>
      <span class="topbar-title">${pageTitle}</span>
    </div>
    <div class="topbar-search">
      <span class="topbar-search-ico">🔍</span>
      <input type="text" placeholder="Rechercher...">
    </div>
    <div class="topbar-right">
      <span class="top-clock" id="clock">--:--:--</span>
      <div class="topbar-bell">🔔<span class="bell-dot"></span></div>
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

  document.body.insertAdjacentHTML('afterbegin',sidebarHTML+topbarHTML);

  if(!document.getElementById('toast-area')){
    const ta=document.createElement('div');ta.id='toast-area';document.body.appendChild(ta);
  }

  function tick(){
    const n=new Date();
    const t=`${String(n.getHours()).padStart(2,'0')}:${String(n.getMinutes()).padStart(2,'0')}:${String(n.getSeconds()).padStart(2,'0')}`;
    const el=document.getElementById('clock');if(el)el.textContent=t;
  }
  tick();setInterval(tick,1000);
}

// ── MODAL ──
function openModal(id){const el=document.getElementById(id);if(el)el.classList.add('open')}
function closeModal(id){const el=document.getElementById(id);if(el)el.classList.remove('open')}

// ── TOAST (light theme) ──
const TOAST_COLORS={success:'#10b981',danger:'#ef4444',warning:'#f59e0b',info:'#6366f1'};
function toast(msg,type='success'){
  const area=document.getElementById('toast-area');if(!area)return;
  const t=document.createElement('div');
  const c=TOAST_COLORS[type]||TOAST_COLORS.success;
  t.style.cssText=`
    background:white;border:1px solid ${c}33;border-left:3px solid ${c};
    color:#1e1e2e;padding:0.75rem 1.2rem;font-family:'Plus Jakarta Sans',sans-serif;
    font-size:13px;animation:toastIn .3s ease;min-width:220px;
    box-shadow:0 8px 24px rgba(0,0,0,0.1);display:flex;align-items:center;gap:.5rem;
    border-radius:10px;
  `;
  t.innerHTML=`<span style="color:${c};font-size:16px">●</span>${msg}`;
  area.appendChild(t);
  setTimeout(()=>{t.style.animation='toastOut .3s ease forwards';setTimeout(()=>t.remove(),300)},3000);
}

// ── TABLE FILTER ──
function filterTable(inputId,tableId){
  const v=document.getElementById(inputId).value.toLowerCase();
  document.querySelectorAll(`#${tableId} tbody tr`).forEach(r=>{
    r.style.display=r.textContent.toLowerCase().includes(v)?'':'none';
  });
}

const style=document.createElement('style');
style.textContent=`
  @keyframes toastIn{from{opacity:0;transform:translateX(20px)}to{opacity:1;transform:translateX(0)}}
  @keyframes toastOut{from{opacity:1;transform:translateX(0)}to{opacity:0;transform:translateX(20px)}}
`;
document.head.appendChild(style);