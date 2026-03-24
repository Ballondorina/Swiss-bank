'use strict';

// ── DATA ──────────────────────────────────────────────────────────────────
const RANKS = {
    1: 'Associé',
    2: 'Soldat',
    3: 'Kapten',
    4: 'Underdirektör',
    5: 'Direktör'
};

const TIERS = { 1: 'Street', 2: 'Established', 3: 'Syndicate', 4: 'Empire' };

const MAX_PASSIVE    = { 1: 50000,  2: 200000, 3: 500000,  4: 1000000 };
const MISSIONS_REQ   = { 1: 3,     2: 5,      3: 8,       4: 12      };

let myRank      = 1;
let myCitizenId = '';

// ── RECEIVE DATA ──────────────────────────────────────────────────────────
window.addEventListener('message', e => {
    if (e.data.action === 'openPanel') {
        if (!e.data.data) return; // Not in org — panel stays closed
        buildPanel(e.data.data);
    }
});

function buildPanel(d) {
    myRank      = d.myRank || 1;
    myCitizenId = d.myCitizenId || '';

    const org  = d.org;
    const tier = org.tier;

    // Header
    el('org-name').textContent = org.label;
    el('org-tier').textContent = `Tier ${tier} · ${TIERS[tier] || '—'}`;
    el('vault-val').textContent = '$' + fmt(org.vault);

    const badge = el('type-badge');
    badge.textContent = (org.type || 'illegal').toUpperCase();
    badge.className   = 'type-badge ' + (org.type || 'illegal');

    // ── Overview stats ──
    const completed = (d.missions || []).filter(m => m.status === 'completed').length;
    const required  = MISSIONS_REQ[tier] || 3;
    const ratio     = Math.min(completed / required, 1.0);
    const maxP      = MAX_PASSIVE[tier] || 0;

    el('s-members').textContent = (d.members || []).length;
    el('s-missions').textContent = `${completed}/${required}`;
    el('s-rate').textContent     = Math.round(ratio * 100) + '%';
    el('s-rank').textContent     = RANKS[myRank] || '—';

    el('bar-fill').style.width   = (ratio * 100) + '%';
    el('passive-nums').textContent =
        '$' + fmt(Math.floor(maxP * ratio)) + ' / $' + fmt(maxP) + ' per day';

    // Top contributors
    buildContributors(d.members || []);

    // Members tab
    buildMembers(d.members || []);

    // Missions tab
    buildMissions(d.missions || []);

    // Ledger tab
    buildLedger(d.ledger || []);

    el('panel').classList.remove('hidden');
    showTab('overview', document.querySelector('.nav-btn[data-tab="overview"]'));
}

// ── CONTRIBUTORS ─────────────────────────────────────────────────────────
function buildContributors(members) {
    const sorted = [...members]
        .sort((a, b) => b.weekly_contribution - a.weekly_contribution)
        .slice(0, 5);

    el('contrib-list').innerHTML = sorted.map((m, i) => `
        <div class="contrib-item">
            <span class="contrib-name">
                #${i + 1} ${esc(m.name)}
                <span class="contrib-rank">${RANKS[m.rank] || '—'}</span>
            </span>
            <span class="contrib-amt">$${fmt(m.weekly_contribution)}</span>
        </div>
    `).join('') || '<p style="color:#333;font-size:12px;padding:12px">No activity this week.</p>';
}

// ── MEMBERS ───────────────────────────────────────────────────────────────
function buildMembers(members) {
    if (!members.length) {
        el('members-list').innerHTML = '<p style="color:#333;font-size:12px;padding:16px">No members.</p>';
        return;
    }

    el('members-list').innerHTML = members.map(m => {
        const isMe      = m.citizen_id === myCitizenId;
        const canManage = myRank >= 4 && !isMe && m.rank < myRank;
        const meTag     = isMe ? ' <span style="color:#44444e;font-size:10px">(You)</span>' : '';

        const actions = canManage ? `
            <div style="display:flex;gap:6px">
                <button class="btn-sm" onclick="promptRank('${m.citizen_id}','${esc(m.name)}',${m.rank})">Rank</button>
                <button class="btn-sm" onclick="promptSalary('${m.citizen_id}','${esc(m.name)}')">Salary</button>
                <button class="btn-sm danger" onclick="doKick('${m.citizen_id}','${esc(m.name)}')">Kick</button>
            </div>` : '';

        return `
        <div class="member-item">
            <div class="member-left">
                <span class="member-name">${esc(m.name)}${meTag}</span>
                <span class="member-meta">${RANKS[m.rank] || '—'}${m.division ? ' · ' + esc(m.division) : ''} · Loyalty ${m.loyalty || 100}%</span>
            </div>
            <div class="member-right">
                <span class="member-contrib">+$${fmt(m.weekly_contribution)}/wk</span>
                <span class="member-salary">Salary $${fmt(m.salary)}</span>
                ${actions}
            </div>
        </div>`;
    }).join('');
}

// ── MISSIONS ─────────────────────────────────────────────────────────────
function buildMissions(missions) {
    if (!missions.length) {
        el('missions-list').innerHTML = '<p style="color:#333;font-size:12px;padding:16px">No missions yet — check back shortly.</p>';
        return;
    }

    el('missions-list').innerHTML = missions.map(m => {
        const label      = fmtMissionType(m.mission_type);
        const statusBadge = `<span class="badge badge-${m.status}">${m.status}</span>`;
        const canStart    = m.status === 'pending' && myRank >= 2;
        const startBtn    = canStart
            ? `<button class="btn red" style="padding:6px 14px;font-size:11px" onclick="doStartMission(${m.id})">Take Mission</button>`
            : '';

        const cls = m.status === 'completed' ? 'is-completed'
                  : m.status === 'active'    ? 'is-active'
                  : m.status === 'failed'    ? 'is-failed'
                  : m.status === 'expired'   ? 'is-expired'
                  : '';

        return `
        <div class="mission-item ${cls}">
            <div class="mission-top">
                <span class="mission-label">${label}</span>
                <span class="mission-reward">+$${fmt(m.reward)}</span>
            </div>
            <div class="mission-bot">
                <span class="mission-dur">Time limit applies</span>
                <div style="display:flex;align-items:center;gap:10px">
                    ${statusBadge}
                    ${startBtn}
                </div>
            </div>
        </div>`;
    }).join('');
}

// ── LEDGER ────────────────────────────────────────────────────────────────
function buildLedger(entries) {
    if (!entries.length) {
        el('ledger-list').innerHTML = '<p style="color:#333;font-size:12px;padding:16px">No transactions yet.</p>';
        return;
    }

    el('ledger-list').innerHTML = entries.map(e => {
        const pos  = e.amount > 0;
        const sign = pos ? '+' : '';
        return `
        <div class="ledger-item">
            <div>
                <div class="ledger-desc">${esc(e.description || e.type)}</div>
                <div class="ledger-time">${fmtDate(e.created_at)}</div>
            </div>
            <span class="ledger-amt ${pos ? 'pos' : 'neg'}">${sign}$${fmt(Math.abs(e.amount))}</span>
        </div>`;
    }).join('');
}

// ── ACTIONS ───────────────────────────────────────────────────────────────
function doDeposit() {
    const amt = parseInt(el('dep-amt').value);
    if (!amt || amt <= 0) return;
    post('deposit', { amount: amt });
    el('dep-amt').value = '';
    closePanel();
}

function doWithdraw() {
    const amt = parseInt(el('wd-amt').value);
    if (!amt || amt <= 0) return;
    post('withdraw', { amount: amt });
    el('wd-amt').value = '';
    closePanel();
}

function doStartMission(missionId) {
    post('startMission', { missionId });
    closePanel();
}

function doKick(citizenId, name) {
    if (!confirm(`Remove ${name} from the organization?`)) return;
    post('kickMember', { citizenId });
    closePanel();
}

function promptRank(citizenId, name, current) {
    const list = Object.entries(RANKS).map(([k, v]) => `${k} = ${v}`).join('\n');
    const input = prompt(`Set rank for ${name} (1-4):\n${list}`, current);
    if (input === null) return;
    const r = parseInt(input);
    if (!r || r < 1 || r > 4) return;
    post('setRank', { citizenId, rank: r });
    closePanel();
}

function promptSalary(citizenId, name) {
    const input = prompt(`Set weekly salary for ${name} (0 to remove):`);
    if (input === null) return;
    const s = parseInt(input);
    if (isNaN(s) || s < 0) return;
    post('setSalary', { citizenId, salary: s });
    closePanel();
}

function leaveOrg() {
    if (!confirm('Are you sure you want to leave the organization?')) return;
    post('leaveOrg', {});
    closePanel();
}

// ── UI HELPERS ────────────────────────────────────────────────────────────
function showTab(name, btn) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    el('tab-' + name).classList.add('active');
    if (btn) btn.classList.add('active');
}

function closePanel() {
    el('panel').classList.add('hidden');
    post('closePanel', {});
}

// ── UTILS ─────────────────────────────────────────────────────────────────
const el  = id => document.getElementById(id);
const fmt = n  => Number(n || 0).toLocaleString('en-US');
const esc = s  => String(s || '').replace(/[<>&"']/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[c]));

function fmtMissionType(t) {
    return (t || '').split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

function fmtDate(s) {
    if (!s) return '';
    const d = new Date(s);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function post(cb, data) {
    fetch(`https://underworld/${cb}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data || {})
    });
}
