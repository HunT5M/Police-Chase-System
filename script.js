let allowedIds = [];
let selectedBlip = 161; 
let selectedColor = 1;  

function openTab(tabId) {
    document.querySelectorAll('.tab-page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-buttons button').forEach(b => b.classList.remove('active'));
    document.getElementById(tabId).classList.add('active');
    const activeBtn = document.querySelector(`.nav-buttons button[onclick="openTab('${tabId}')"]`);
    if (activeBtn) activeBtn.classList.add('active');
    
    const titles = { 'settings': 'CONFIGURATION', 'style': 'VISUALS', 'perms': 'ACCESS CONTROL', 'dispatch': 'DISPATCH SETTINGS' };
    document.getElementById('header-title').innerText = titles[tabId];
}

function updateVal(input, id, suffix) {
    document.getElementById(id).innerText = input.value + suffix;
}

function selectBlip(el, id) {
    selectedBlip = id;
    document.querySelectorAll('#blipIcons .sel-item').forEach(d => d.classList.remove('active'));
    el.classList.add('active');
}

function selectColor(el, id) {
    selectedColor = id;
    document.querySelectorAll('#blipColors .sel-color').forEach(d => d.classList.remove('active'));
    el.classList.add('active');
}

function addId() {
    const input = document.getElementById('newId');
    const val = input.value.trim();
    if (val && !allowedIds.includes(val)) {
        allowedIds.push(val);
        renderIds();
        input.value = '';
    }
}

function removeId(val) { allowedIds = allowedIds.filter(id => id !== val); renderIds(); }

function renderIds() {
    const container = document.getElementById('idList');
    container.innerHTML = ''; 
    allowedIds.forEach(id => {
        const div = document.createElement('div');
        div.className = 'list-item';
        div.innerHTML = `<span>${id}</span><i class="fa-solid fa-xmark del-btn" onclick="removeId('${id}')"></i>`;
        container.appendChild(div);
    });
}

function closeMenu() {
    const menu = document.getElementById('menu');
    const tooltip = document.getElementById('tooltip');
    if (tooltip) tooltip.classList.remove('show');
    menu.classList.add('closing');
    setTimeout(() => {
        document.body.style.display = 'none';
        menu.classList.remove('closing');
        try { fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST', body: JSON.stringify({}) }).catch(err => {}); } catch(e) {}
    }, 400);
}

function saveData() {
    const data = {
        minSpeed: document.getElementById('minSpeed').value,
        maxDist: document.getElementById('maxDist').value,
        fillRate: document.getElementById('fillRate').value,
        colors: {
            bar: document.getElementById('barColor').value,
            ready: document.getElementById('readyColor').value,
            text: document.getElementById('targetColor').value
        },
        globalAlpha: document.getElementById('globalAlpha').value,
        restrictMode: document.getElementById('restrictSwitch').checked,
        allowedIds: allowedIds,
        dispatch: {
            enabled: document.getElementById('dispatchSwitch').checked,
            sprite: selectedBlip,
            color: selectedColor
        }
    };
    try { fetch(`https://${GetParentResourceName()}/saveSettings`, { method: 'POST', body: JSON.stringify(data) }).catch(err => {}); } catch(e) {}
}

window.addEventListener('message', function(event) {
    if (event.data.action === 'open') {
        if (document.body.style.display === 'flex') return; 
        const cfg = event.data.data;
        if (cfg) {
            if (cfg.minSpeed) { document.getElementById('minSpeed').value = cfg.minSpeed; updateVal(document.getElementById('minSpeed'), 'sVal', ' km/h'); }
            if (cfg.maxDist) { document.getElementById('maxDist').value = cfg.maxDist; updateVal(document.getElementById('maxDist'), 'dVal', ' m'); }
            if (cfg.fillRate) { document.getElementById('fillRate').value = cfg.fillRate; updateVal(document.getElementById('fillRate'), 'fVal', ''); }
            if (cfg.alpha) { document.getElementById('globalAlpha').value = cfg.alpha; updateVal(document.getElementById('globalAlpha'), 'aVal', ''); }
            if (cfg.colors) {
                if (cfg.colors.bar) document.getElementById('barColor').value = cfg.colors.bar;
                if (cfg.colors.ready) document.getElementById('readyColor').value = cfg.colors.ready;
                if (cfg.colors.text) document.getElementById('targetColor').value = cfg.colors.text;
            }
            if (cfg.allowedIds) { allowedIds = cfg.allowedIds; renderIds(); }
            if (cfg.dispatch) {
                document.getElementById('dispatchSwitch').checked = cfg.dispatch.enabled;
                selectedBlip = cfg.dispatch.sprite || 161;
                selectedColor = cfg.dispatch.color || 1;
                document.querySelectorAll('#blipIcons .sel-item').forEach(d => {
                    d.classList.remove('active');
                    if (d.getAttribute('onclick').includes(selectedBlip)) d.classList.add('active');
                });
                document.querySelectorAll('#blipColors .sel-color').forEach(d => {
                    d.classList.remove('active');
                    if (d.getAttribute('onclick').includes(`, ${selectedColor})`)) d.classList.add('active');
                });
            }
        }
        document.body.style.display = 'flex';
        const menu = document.getElementById('menu');
        menu.classList.remove('closing');
        menu.style.animation = 'none';
        void menu.offsetHeight; 
        menu.style.animation = 'glitch-open 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94) both';
        openTab('settings');
    } else if (event.data.action === 'close') { 
        closeMenu(); 
    }
});

document.onkeyup = function(data) { 
    if (data.which == 27) closeMenu(); 
};

// ==========================================
// TOOLTIP ENGINE 
// ==========================================
const tooltip = document.getElementById('tooltip');
const tooltipContent = document.getElementById('tooltip-content');
const menuPanel = document.getElementById('menu');

document.addEventListener('mouseover', function(e) {
    const el = e.target.closest('[data-tooltip]');
    if (el) {
        const rect = menuPanel.getBoundingClientRect();
        tooltipContent.innerHTML = el.getAttribute('data-tooltip');
        tooltip.style.left = (rect.left + rect.width / 2) + 'px';
        tooltip.style.top = rect.top + 'px';
        tooltip.classList.add('show');
    }
});

document.addEventListener('mouseout', function(e) {
    if (e.target.closest('[data-tooltip]')) {
        tooltip.classList.remove('show');
    }
});