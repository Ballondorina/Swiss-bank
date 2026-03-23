function formatNumberInput(el) {
    // Remove all non-digit characters except minus sign
    let raw = el.value.replace(/[^0-9]/g, '');
    
    if (!raw) {
        el.value = '';
        return;
    }
    
    // Remove leading zeros
    raw = raw.replace(/^0+/, '') || '0';
    
    // Format with thousands separators
    const number = parseInt(raw, 10);
    if (isNaN(number)) {
        el.value = '';
        return;
    }
    
    el.value = number.toLocaleString();
}

function getNumericValue(el) {
    if (!el || !el.value) return 0;
    const raw = el.value.replace(/,/g, '');
    const number = parseInt(raw, 10);
    return isNaN(number) ? 0 : number;
}

['inp-deposit', 'inp-withdraw', 'inp-transfer-amount'].forEach(id => {
    const input = document.getElementById(id);
    if (input) {
        // Prevent non-numeric input
        input.addEventListener('keydown', (e) => {
            // Allow backspace, delete, tab, escape, enter and decimal point
            if ([46, 8, 9, 27, 13].includes(e.keyCode) || 
                // Allow: Ctrl+A, Command+A
                (e.keyCode === 65 && (e.ctrlKey === true || e.metaKey === true)) || 
                // Allow: Ctrl+C, Command+C
                (e.keyCode === 67 && (e.ctrlKey === true || e.metaKey === true)) || 
                // Allow: Ctrl+X, Command+X
                (e.keyCode === 88 && (e.ctrlKey === true || e.metaKey === true)) ||
                // Allow: home, end, left, right, down, up
                (e.keyCode >= 35 && e.keyCode <= 40)) {
                return;
            }
            // Ensure that it is a number and stop the keypress if not
            if ((e.shiftKey || (e.keyCode < 48 || e.keyCode > 57)) && (e.keyCode < 96 || e.keyCode > 105)) {
                e.preventDefault();
            }
        });
        
        input.addEventListener('input', () => formatNumberInput(input));
        input.addEventListener('blur', () => formatNumberInput(input));
    }
});

const appRoot = document.getElementById('app');
const screensaverOverlay = document.getElementById('screensaver-overlay');
const currencyRainLayer = document.getElementById('currency-rain');
const confettiLayer = document.getElementById('confetti-layer');
const cardVisual = document.getElementById('credit-card-visual');
const cardBackSticker = document.getElementById('card-slogan');
const balanceCard = document.querySelector('.balance-card');
const bankUI = document.getElementById('bank-ui');
const atmContainer = document.getElementById('atm-container');
const atmUI = document.getElementById('atm-ui');
const shield = document.getElementById('interaction-shield');
const atmVignette = document.getElementById('atm-vignette');
const transferIbanInput = document.getElementById('inp-transfer-iban');
const ibanFeedbackEl = document.getElementById('iban-feedback');
const transferAmountInput = document.getElementById('inp-transfer-amount');
const transferButton = document.getElementById('btn-transfer');
let idleTimer = null;
const idleTimeout = 15000;

const cardSlogans = [
    "Bank Champ", "Debt Slayer", "Tap Tap Rich", "Interest Ninja",
    "PINfluencer", "Cashwave Rider", "Verified Broke", "Swipe Wizard"
];
const themeColors = {
    midnight: ["#1f5eff", "#10b981", "#6ee7b7"],
    neon: ["#ff1fb8", "#23f5ff", "#ff8f1f"],
    minimal: ["#00d4a4", "#8b5cf6", "#5eead4"]
};

function resetIdleTimer() {
    if (!bankUI.classList.contains('show')) return;
    hideScreensaver();
    clearTimeout(idleTimer);
    idleTimer = setTimeout(showScreensaver, idleTimeout);
}

function showScreensaver() {
    if (screensaverOverlay) screensaverOverlay.classList.add('show');
}

function hideScreensaver() {
    if (screensaverOverlay) screensaverOverlay.classList.remove('show');
}

['mousemove','keydown','wheel','touchstart','click'].forEach(evt => {
    document.addEventListener(evt, resetIdleTimer, { passive: true });
});

if (screensaverOverlay) {
    screensaverOverlay.addEventListener('click', () => {
        hideScreensaver();
        resetIdleTimer();
    });
}

function spawnParticles(container, className, colors, count, keyframes = 'confettiFall') {
    if (!container) return;
    for (let i = 0; i < count; i++) {
        const piece = document.createElement('span');
        piece.className = className;
        piece.style.left = `${Math.random() * 100}%`;
        piece.style.top = `${Math.random() * -20}px`;
        piece.style.background = colors[Math.floor(Math.random() * colors.length)];
        if (className === 'currency-rain-piece') {
            piece.textContent = Math.random() > 0.5 ? '💰' : '💵';
        }
        piece.style.animationName = keyframes;
        container.appendChild(piece);
        setTimeout(() => piece.remove(), 1200);
    }
}

function spawnConfetti() {
    const colors = themeColors[currentTheme] || themeColors.midnight;
    spawnParticles(confettiLayer, 'confetti-piece', colors, 30);
}

function triggerCurrencyRain() {
    attachCurrencyRainPosition();
    const colors = themeColors[currentTheme] || themeColors.midnight;
    spawnParticles(currencyRainLayer, 'currency-rain-piece', colors, 15, 'currencyDrop');
}

function attachCurrencyRainPosition() {
    if (!currencyRainLayer || !balanceCard || !appRoot) return;
    const appRect = appRoot.getBoundingClientRect();
    const rect = balanceCard.getBoundingClientRect();
    currencyRainLayer.style.left = `${rect.left - appRect.left}px`;
    currencyRainLayer.style.top = `${rect.top - appRect.top}px`;
    currencyRainLayer.style.width = `${rect.width}px`;
    currencyRainLayer.style.height = `${rect.height}px`;
}

window.addEventListener('resize', attachCurrencyRainPosition);
window.addEventListener('scroll', attachCurrencyRainPosition);

let chartInstance = null;
let currentPin = '';
let currencySymbol = '$';
let currentAccountType = 'personal';
let cardTiers = []; 
let balanceHidden = false;
let currentRawBalance = 0;
let cachedTransactions = [];
let cachedMails = [];
let currentLocale = {};
let configAudio = { Success: 'correct.wav', Error: 'wrong.mp3', Click: 'click.wav', Volume: 0.5 };
let currentIbanValid = false;
let ibanValidationTimer = null;
let currentPageId = 'overview';
let currentTheme = 'midnight';
const quips = {
    midnight: {
        atm: [
            "Insert card, pray for funds.",
            "Don't worry, nobody saw that PIN… probably.",
            "Bank security is just vibes after midnight."
        ],
        drawtext: [
            "The bank is always watching 😏",
            "Approach calmly; it scares the ATMs.",
            "Tap E gently. These machines have feelings."
        ]
    },
    neon: {
        atm: [
            "Neon lights, neon debt.",
            "Please keep hands inside the rave at all times.",
            "This ATM accepts vibes and PINs only."
        ],
        drawtext: [
            "Insert card, become fabulous.",
            "Warning: May cause spontaneous spending.",
            "Glow hard or go home."
        ]
    },
    minimal: {
        atm: [
            "Minimal queue, maximal judgment.",
            "Every tap counted, every cent judged.",
            "Try not to overdraft in public."
        ],
        drawtext: [
            "Simplicity is expensive.",
            "Yes, this minimalist box takes your money.",
            "Press E like you mean it."
        ]
    }
};

// --- CURRENCY CHANGER LOGIC ---
const currencyToggle = document.getElementById('currency-dropdown-toggle');
const currencyMenu = document.getElementById('currency-dropdown-menu');
const currencyActiveLabel = document.getElementById('currency-active-label');
const themeSelect = document.getElementById('theme-selector');

function setupCurrencyChanger(availableCurrencies) {
    if (!availableCurrencies || !currencyMenu) return;
    currencyMenu.innerHTML = '';
    
    availableCurrencies.forEach(curr => {
        const item = document.createElement('div');
        item.className = 'currency-dropdown__item';
        item.innerText = curr.label;
        item.onclick = () => {
            currencySymbol = curr.symbol;
            currencyActiveLabel.innerText = curr.label;
            currencyMenu.classList.add('hidden');
            updateBalanceDisplay();
            renderTransactions(cachedTransactions);
            refreshGoalDisplay(); // Update goal text with new symbol
            triggerCurrencyRain();
            playSound(configAudio.Click, 0.2);
        };
        currencyMenu.appendChild(item);
    });
}

function applyTheme(theme) {
    const themeValue = theme || localStorage.getItem('swisserTheme') || 'midnight';
    document.body.setAttribute('data-theme', themeValue);
    currentTheme = themeValue;
    if (themeSelect) themeSelect.value = themeValue;
    localStorage.setItem('swisserTheme', themeValue);
}
applyTheme();

function triggerThemeVisuals(theme) {
    const app = document.getElementById('app');
    const themeClasses = ['theme-midnight', 'theme-neon', 'theme-minimal'];
    
    // Remove all theme classes first
    app.classList.remove(...themeClasses);
    
    // Add the selected theme class
    switch(theme) {
        case 'neon':
            app.classList.add('theme-neon');
            break;
        case 'minimal':
            app.classList.add('theme-minimal');
            break;
        default: // midnight (default)
            app.classList.add('theme-midnight');
    }
    
    // Trigger any additional theme-specific visual effects
    if (theme === 'neon') {
        // Add any neon-specific visual effects here
    }
}

if (themeSelect) {
    themeSelect.addEventListener('change', (e) => {
        const theme = e.target.value;
        applyTheme(theme);
        triggerThemeVisuals(theme);
        playSound(configAudio.Click, 0.15);
    });
}
currencyToggle.addEventListener('click', (e) => {
    e.stopPropagation();
    currencyMenu.classList.toggle('hidden');
    playSound(configAudio.Click, 0.1);
});

document.addEventListener('click', () => {
    currencyMenu.classList.add('hidden');
});

// --- AUDIO HELPER ---
function playSound(file, volume = configAudio.Volume) {
    if (!file) return;
    const audio = new Audio(`./sounds/${file}`);
    audio.volume = volume;
    const playPromise = audio.play();
    if (playPromise !== undefined) {
        playPromise.then(_ => {}).catch(error => {
            console.log("Audio play deferred until interaction.");
        });
    }
}

shield.addEventListener('click', () => {
    shield.style.display = 'none';
    playSound(configAudio.Click, 0.05); 
});

function triggerKeyGlow(btn, state) {
    if (!btn) return;
    btn.classList.remove('active-glow', 'succeed', 'error');
    // force reflow to restart animation
    void btn.offsetWidth;
    btn.classList.add('active-glow');
    if (state === 'success') btn.classList.add('succeed');
    if (state === 'error') btn.classList.add('error');
    setTimeout(() => {
        btn.classList.remove('active-glow', 'succeed', 'error');
    }, 300);
}

function setVignetteState(state) {
    if (!atmVignette) return;
    atmVignette.classList.remove('success', 'error');
    if (!state) return;
    atmVignette.classList.add(state);
    setTimeout(() => atmVignette.classList.remove(state), 900);
}

function showAtmQuip() {
    const target = document.getElementById('atm-quip');
    if (!target) return;
    const lines = quips[currentTheme]?.atm || quips.midnight.atm;
    target.innerText = lines[Math.floor(Math.random() * lines.length)];
}

document.querySelectorAll('.pin-number').forEach(btn => {
    const pinValue = btn.dataset.pin;
    const isSubmit = btn.dataset.submit === 'true';
    if (isSubmit) {
        btn.addEventListener('click', () => {
            triggerKeyGlow(btn);
            submitPin();
        });
    } else if (pinValue !== undefined) {
        btn.addEventListener('click', () => {
            triggerKeyGlow(btn);
            addPin(pinValue);
        });
    }
});

function setIbanFeedback(message, state = 'info') {
    if (!ibanFeedbackEl) return;
    ibanFeedbackEl.textContent = message || '';
    ibanFeedbackEl.classList.remove('success', 'error', 'info');
    if (message) {
        ibanFeedbackEl.classList.add(state);
    }
}

function setTransferButtonState(enabled) {
    if (!transferButton) return;
    transferButton.disabled = !enabled;
    transferButton.classList.toggle('disabled', !enabled);
}

function updateTransferButtonState() {
    const amount = parseFloat(transferAmountInput?.value || 0);
    const enabled = currentIbanValid && amount > 0;
    setTransferButtonState(enabled);
}

function resetIbanFeedback() {
    currentIbanValid = false;
    setIbanFeedback('', 'info');
    updateTransferButtonState();
}

async function handleIbanValidation(value) {
    if (!value) {
        resetIbanFeedback();
        return;
    }
    setIbanFeedback('Checking account...', 'info');
    const result = await validateIban(value);
    if (transferIbanInput && transferIbanInput.value.trim() !== value) return;
    if (result.valid) {
        currentIbanValid = true;
        const name = result.name?.trim();
        setIbanFeedback(name ? `Recipient: ${name}` : 'Account verified', 'success');
        showRecipientPreview(name || 'Unknown', value);
    } else {
        currentIbanValid = false;
        setIbanFeedback('Account number not found', 'error');
        hideRecipientPreview();
    }
    updateTransferButtonState();
}

if (transferIbanInput) {
    transferIbanInput.addEventListener('input', () => {
        const value = transferIbanInput.value.trim();
        currentIbanValid = false;
        setTransferButtonState(false);
        clearTimeout(ibanValidationTimer);
        if (!value) {
            resetIbanFeedback();
            return;
        }
        ibanValidationTimer = setTimeout(() => handleIbanValidation(value), 350);
    });
}

if (transferAmountInput) {
    transferAmountInput.addEventListener('input', updateTransferButtonState);
}

// --- PARALLAX EFFECT ---
const cardHolo = document.querySelector('.holographic-strip');

if (cardVisual) {
    cardVisual.addEventListener('mousemove', (e) => {
        if (!bankUI.classList.contains('show')) return;
        const { left, top, width, height } = cardVisual.getBoundingClientRect();
        const centerX = left + width / 2;
        const centerY = top + height / 2;
        const mouseX = e.clientX - centerX;
        const mouseY = e.clientY - centerY;
        const rotateX = (mouseY / (height / 2)) * -15;
        const rotateY = (mouseX / (width / 2)) * 15;
        cardVisual.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
        if (cardHolo) {
            const holoPos = 50 + (rotateY * 2);
            cardHolo.style.left = `${holoPos}%`;
        }
    });

    cardVisual.addEventListener('mouseleave', () => {
        cardVisual.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg)`;
    });
}

// --- NAVIGATION ---
function setActivePage(pageId, labelEl) {
    if (!pageId || pageId === currentPageId) return;
    const currentPage = document.getElementById(`page-${currentPageId}`);
    const nextPage = document.getElementById(`page-${pageId}`);
    if (!nextPage) return;

    if (currentPage) {
        currentPage.classList.remove('active');
        currentPage.classList.add('exit-left');
        setTimeout(() => {
            currentPage.classList.add('hidden');
            currentPage.classList.remove('exit-left');
        }, 350);
    }

    nextPage.classList.remove('hidden');
    requestAnimationFrame(() => nextPage.classList.add('active'));

    currentPageId = pageId;

    if (labelEl) document.getElementById('page-title').innerText = labelEl.innerText;
    if (pageId === 'overview') setTimeout(initChart, 100);
    if (pageId === 'mailbox') markMailsAsRead();
    if (pageId === 'loans') loadLoanData();
    if (pageId === 'org') loadOrgData();
}

document.querySelectorAll('.sidebar-item').forEach(item => {
    if (item.id === 'btn-exit') return;
    item.addEventListener('click', () => {
        const pageId = item.dataset.page;
        document.querySelectorAll('.sidebar-item').forEach(n => n.classList.remove('selected'));
        item.classList.add('selected');
        setActivePage(pageId, item.querySelector('span'));
        playSound(configAudio.Click, 0.2);
    });
});

document.getElementById('btn-exit').addEventListener('click', closeUI);

function closeUI() {
    bankUI.classList.remove('animate-in');
    setTimeout(() => bankUI.classList.remove('show'), 200);
    atmUI.classList.remove('show');
    shield.style.display = 'none';
    document.body.classList.remove('bank-open');
    setTimeout(() => {
        bankUI.style.display = 'none';
        atmContainer.style.display = 'none';
        fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
        currentPin = '';
        updatePinDots();
    }, 500);
}

// --- PIN PAD ---
window.addPin = (num) => {
    if (num === 'clear') {
        currentPin = '';
        playSound(configAudio.Click, 0.3);
    } else if (currentPin.length < 4) {
        currentPin += num;
        playSound(configAudio.Click, 0.4);
    }
    updatePinDots();
};

window.submitPin = () => {
    if (currentPin.length !== 4) return;
    fetch(`https://${GetParentResourceName()}/checkPIN`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ pin: currentPin })
    }).then(res => res.json()).then(isValid => {
        if (isValid) pinSuccess();
        else pinError();
    });
};

function pinSuccess() {
    playSound(configAudio.Success, 0.8);
    document.querySelectorAll('.dot').forEach(d => {
        d.classList.remove('wrong');
        d.classList.add('correct');
    });
    setVignetteState('success');
    setTimeout(() => {
        atmUI.classList.remove('show');
        setTimeout(() => {
            atmContainer.style.display = 'none';
            fetch(`https://${GetParentResourceName()}/loadBankData`, { 
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).then(res => res.json()).then(data => openBankDashboard(data, currentLocale));
        }, 500);
    }, 600);
}

function pinError() {
    playSound(configAudio.Error, 0.8);
    document.querySelectorAll('.dot').forEach(d => {
        d.classList.add('wrong');
    });
    setVignetteState('error');
    setTimeout(() => {
        document.querySelectorAll('.dot').forEach(d => {
            d.classList.remove('wrong');
            d.classList.remove('active');
        });
        currentPin = ''; 
        updatePinDots();
    }, 800);
}

function updatePinDots() {
    for (let i = 1; i <= 4; i++) {
        const dot = document.getElementById(`dot-${i}`);
        if (dot) {
            if (currentPin.length >= i) dot.classList.add('active');
            else dot.classList.remove('active');
        }
    }
}

// --- DASHBOARD ---
function openBankDashboard(data, locale) {
    if (!data) return;
    currentLocale = locale || {};
    applyLocale(currentLocale);
    document.body.classList.add('bank-open');
    bankUI.style.display = 'block';
    shield.style.display = 'block'; 
    document.querySelectorAll('.page-content').forEach(page => {
        if (page.id === 'page-overview') {
            page.classList.remove('hidden');
            page.classList.add('active');
        } else {
            page.classList.add('hidden');
            page.classList.remove('active');
        }
    });
    currentPageId = 'overview';
    bankUI.classList.remove('animate-in');
    bankUI.classList.add('show');
    setTimeout(() => bankUI.classList.add('animate-in'), 50);
    
    // Set up currency from Config if available
    if (data.availableCurrencies) {
        setupCurrencyChanger(data.availableCurrencies);
    }

    setTimeout(() => {
        updateUI(data);
        setTimeout(initChart, 300);
    }, 100);
}

function applyLocale(loc) {
    if (!loc) return;
    const mappings = {
        // Sidebar nav
        'lbl-overview':      loc.overview,
        'lbl-transactions':  loc.transactions,
        'lbl-transfer':      loc.transfer,
        'lbl-loans':         loc.loans || "Loans",
        'lbl-org':           loc.org || "Organization",
        'lbl-mailbox':       loc.mailbox || "Mailbox",
        'lbl-settings':      loc.settings,
        'lbl-exit':          loc.exit,
        // Overview
        'lbl-balance':          loc.balance,
        'lbl-analysis-title':   loc.analysis_title,
        'lbl-savings-goal-title': loc.savings_goal,
        'btn-goal-settings':    loc.goal_settings,
        'lbl-card-number':      loc.card_number_label,
        // Deposit / withdraw buttons
        'btn-deposit':   loc.deposit,
        'btn-withdraw':  loc.withdraw,
        // Transfer page
        'lbl-quick-transfer':   loc.quick_transfer,
        'lbl-transfer-iban':    loc.transfer_iban_label,
        'lbl-transfer-amount':  loc.transfer_amount_label,
        'btn-transfer':         loc.send,
        // Loans page
        'lbl-take-loan':            loc.take_loan || "Request a Loan",
        'btn-repay-loan':           loc.repay_loan || "Repay Loan",
        'btn-take-loan':            loc.take_loan || "Request a Loan",
        'no-loan-title':            loc.no_active_loan || "No Active Loan",
        'no-loan-sub':              loc.no_active_loan_sub || "Borrow money instantly.",
        'loan-frozen-banner__title': loc.loan_frozen_title || "Account Frozen",
        'loan-frozen-banner__sub':  loc.loan_frozen_sub,
        // Org page
        'org-no-account-title':     loc.org_no_account || "No Organization Account",
        // Settings
        'lbl-security-title':   loc.settings_title,
        'lbl-card-design-title': loc.card_design,
        'lbl-avatar-title':     loc.avatar_design || "Profile Picture",
        'btn-change-pin':       loc.change_pin_btn || "Update Code",
        'btn-order-card':       loc.order_card || "Order Card",
        'btn-remove-card':      loc.reset_default || "Reset Default",
        'btn-update-avatar':    loc.update_avatar || "Update Avatar",
        'btn-remove-avatar':    loc.reset_default || "Reset Default",
        // Goal modal
        'lbl-update-goal-title': loc.update_goal_title,
        'lbl-goal-name':         loc.goal_name_label,
        'lbl-goal-target':       loc.goal_target_label,
        'btn-save-goal':         loc.save_goal,
        'btn-cancel-goal':       loc.cancel,
    };

    for (const [id, text] of Object.entries(mappings)) {
        const el = document.getElementById(id);
        if (el && text) el.innerText = text;
    }

    // Loans warning banner uses innerHTML so we can bold the first line
    const warnEl = document.querySelector('.loan-warning-banner__text');
    if (warnEl && loc.loan_warning) {
        warnEl.innerHTML = `<strong>${loc.loan_warning}</strong><span>${loc.loan_warning_sub || ''}</span>`;
    }
    // Org no-account sub text
    const orgSubEl = document.querySelector('#org-no-account .no-loan-sub');
    if (orgSubEl && loc.org_no_account_sub) orgSubEl.innerText = loc.org_no_account_sub;
}

let lastGoalData = null;
function updateUI(data) {
    if(!data) return;
    currentRawBalance = data.balance || 0;
    cachedTransactions = data.transactions || [];
    cachedMails = data.mails || [];
    currentAccountType = data.currentAccount || 'personal';
    cardTiers = data.tiers || []; 
    currencySymbol = data.currency || '$';
    lastGoalData = data.goal;

    document.getElementById('user-name').innerText = data.name || "Unknown";
    document.getElementById('card-iban').innerText = data.iban || "SE00 0000";
    
    const avatarImg = document.getElementById('user-avatar');
    const removeAvatarBtnEl = document.getElementById('btn-remove-avatar');
    if (avatarImg) {
        if (data.avatarUrl && data.avatarUrl !== "REMOVE") {
            avatarImg.src = data.avatarUrl;
            removeAvatarBtnEl?.classList.remove('hidden');
        } else {
            avatarImg.src = `https://ui-avatars.com/api/?name=${data.name}&background=1f5eff&color=fff`;
            removeAvatarBtnEl?.classList.add('hidden');
        }
    }

    updateBalanceDisplay();
    updateCardVisuals(currentRawBalance, data.cardUrl);
    renderTransactions(cachedTransactions);
    renderMails(cachedMails);
    updateGoalUI(data.goal, currentRawBalance);
    updateStatPills(cachedTransactions);
    renderQuickContacts(cachedTransactions);

    if (data.cardUrl && data.cardUrl !== "REMOVE") {
        document.getElementById('btn-remove-card').classList.remove('hidden');
    } else {
        document.getElementById('btn-remove-card').classList.add('hidden');
    }
}

function updateBalanceDisplay() {
    const el = document.getElementById('display-balance');
    el.innerText = balanceHidden ? `**** ${currencySymbol}` : `${currentRawBalance.toLocaleString()} ${currencySymbol}`;
}

function refreshGoalDisplay() {
    if (lastGoalData) updateGoalUI(lastGoalData, currentRawBalance);
}

document.getElementById('toggle-balance').addEventListener('click', function() {
    balanceHidden = !balanceHidden;
    this.className = balanceHidden ? 'fa-solid fa-eye' : 'fa-solid fa-eye-slash';
    updateBalanceDisplay();
});

function updateCardVisuals(balance, customUrl) {
    const cardBg = document.getElementById('card-dynamic-bg');
    const label = document.getElementById('card-tier-label');
    const cardContainer = document.getElementById('credit-card-visual');
    
    cardContainer.classList.remove('card-standard', 'card-gold', 'card-platinum', 'card-silver', 'card-emerald', 'card-diamond');
    cardBg.style.backgroundImage = '';

    if (customUrl && customUrl.length > 5 && customUrl !== "REMOVE") {
        cardBg.style.backgroundImage = `url(${customUrl})`;
        label.innerText = 'CUSTOM DESIGN';
    } else {
        const sortedTiers = [...cardTiers].sort((a, b) => b.amount - a.amount);
        let activeTier = { label: 'STANDARD', style: 'standard' };
        for (const tier of sortedTiers) {
            if (balance >= tier.amount) {
                activeTier = tier;
                break; 
            }
        }
        label.innerText = activeTier.label;
        cardContainer.classList.add(`card-${activeTier.style}`);
    }
}

function renderTransactions(txs) {
    const list = document.getElementById('transaction-list');
    list.innerHTML = '';
    if (!txs || txs.length === 0) {
        list.innerHTML = `<div class="text-center opacity-50 mt-5">No transactions found</div>`;
        return;
    }
    txs.forEach((t) => {
        const isIncome = t.type === 'income';
        const row = document.createElement('div');
        row.className = 'transaction-row';
        row.innerHTML = `
                <div class="transaction-details">
                    <div class="transaction-icon ${isIncome ? 'income' : 'outcome'}">
                        <i class="fa-solid ${isIncome ? 'fa-arrow-down' : 'fa-arrow-up'}"></i>
                    </div>
                    <div class="transaction-meta">
                        <div style="font-weight: 700; font-size: 18px;">${t.label}</div>
                        <div style="font-size: 13px; opacity: 0.4">${new Date(t.date).toLocaleString()}</div>
                    </div>
                </div>
                <div class="${isIncome ? 'text-income' : 'text-outcome'}">
                    ${isIncome ? '+' : '-'}${t.amount.toLocaleString()} ${currencySymbol}
                </div>`;
        list.appendChild(row);
    });
}

function renderMails(mails) {
    const list = document.getElementById('mail-list');
    list.innerHTML = '';
    let unreadCount = 0;
    mails.forEach((m) => {
        if (!m.is_read) unreadCount++;
        const mailDiv = document.createElement('div');
        mailDiv.className = `transaction-row ${m.is_read ? '' : 'unread'}`;
        mailDiv.style.flexDirection = 'column';
        mailDiv.style.alignItems = 'flex-start';
        mailDiv.innerHTML = `
                <div class="d-flex justify-content-between w-100 mb-2">
                    <span style="font-weight: 800; color: #1f5eff;">${m.sender}</span>
                    <span style="opacity: 0.4; font-size: 12px;">${new Date(m.date).toLocaleDateString()}</span>
                </div>
                <div style="font-weight: 700; font-size: 16px; margin-bottom: 5px;">${m.subject}</div>
                <div style="font-size: 14px; opacity: 0.7; line-height: 1.5;">${m.message}</div>`;
        list.appendChild(mailDiv);
    });
    const badge = document.getElementById('mail-badge');
    if (unreadCount > 0) { 
        badge.innerText = unreadCount; 
        badge.classList.remove('hidden'); 
    } else {
        badge.classList.add('hidden');
    }
}

function markMailsAsRead() {
    fetch(`https://${GetParentResourceName()}/markMailsRead`, { method: 'POST' });
}

function updateGoalUI(goal, balance) {
    if (!goal) return;
    const goalTitleEl = document.getElementById('goal-title');
    const goalCurrentEl = document.getElementById('goal-current');
    const goalTargetEl = document.getElementById('goal-target');
    goalTitleEl.innerText = goal.title || "Savings Goal";
    goalCurrentEl.innerText = `${balance.toLocaleString()} ${currencySymbol}`;

    const targetValue = Number(goal.target) || 0;
    if (targetValue > 0) {
        goalTargetEl.innerText = `/ ${targetValue.toLocaleString()} ${currencySymbol}`;
    } else {
        goalTargetEl.innerText = `/ —`;
    }

    const target = targetValue > 0 ? targetValue : 1;
    const percent = targetValue > 0 ? Math.min((balance / target) * 100, 100) : 0;
    const progressBar = document.getElementById('goal-progress-bar');
    progressBar.style.width = `${percent}%`;
    if (percent >= 100) progressBar.classList.add('goal-completed');
    else progressBar.classList.remove('goal-completed');
}

window.toggleGoalEdit = function(forceState) {
    const modal = document.getElementById('goal-modal');
    const shouldShow = typeof forceState === 'boolean' ? forceState : modal.classList.contains('hidden');
    if (shouldShow) {
        modal.classList.remove('hidden');
        modal.style.display = 'flex';
        document.getElementById('inp-goal-title').value = lastGoalData?.title || '';
        document.getElementById('inp-goal-target').value = lastGoalData?.target || '';
    } else {
        modal.classList.add('hidden');
        modal.style.display = 'none';
    }
}

window.saveGoal = function() {
    const title = document.getElementById('inp-goal-title').value;
    const targetInput = document.getElementById('inp-goal-target').value;
    const sanitized = targetInput.replace(/[, ]/g, '');
    const target = Number(sanitized);
    if (!title || !target || target <= 0) return;
    fetch(`https://${GetParentResourceName()}/updateGoal`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title, target: target })
    }).then(res => res.json()).then(success => {
        if (success) {
            toggleGoalEdit(false);
            refreshData();
        }
    });
}

function initChart() {
    const canvas = document.getElementById('transactionChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (chartInstance) chartInstance.destroy();
    const incomeData = cachedTransactions.filter(t => t.type === 'income').map(t => t.amount).slice(0, 7).reverse();
    const outcomeData = cachedTransactions.filter(t => t.type === 'outcome').map(t => t.amount).slice(0, 7).reverse();
    chartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['1', '2', '3', '4', '5', '6', '7'],
            datasets: [{ label: 'In', data: incomeData.length ? incomeData : [0,0,0,0,0,0,0], borderColor: '#10b981', borderWidth: 3, tension: 0.4, pointRadius: 0 },
                       { label: 'Ut', data: outcomeData.length ? outcomeData : [0,0,0,0,0,0,0], borderColor: '#ef4444', borderWidth: 3, tension: 0.4, pointRadius: 0 }]
        },
        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { display: false }, x: { display: false } } }
    });
}

document.getElementById('btn-deposit').addEventListener('click', () => {
    const input = document.getElementById('inp-deposit');
    const amt = getNumericValue(input);
    if (!amt || amt <= 0) return;
    fetch(`https://${GetParentResourceName()}/deposit`, { method: 'POST', body: JSON.stringify({ amount: amt, accountType: currentAccountType })});
    input.value = '';
    setTimeout(refreshData, 300);
});

document.getElementById('btn-withdraw').addEventListener('click', () => {
    const input = document.getElementById('inp-withdraw');
    const amt = getNumericValue(input);
    if (!amt || amt <= 0) return;
    fetch(`https://${GetParentResourceName()}/withdraw`, { method: 'POST', body: JSON.stringify({ amount: amt, accountType: currentAccountType })});
    input.value = '';
    setTimeout(refreshData, 300);
});

if (transferButton) {
    transferButton.addEventListener('click', async () => {
        if (transferButton.classList.contains('disabled')) return;
        const iban = transferIbanInput.value.trim();
        const amt = getNumericValue(transferAmountInput);
        if (!iban || !amt || amt <= 0) return;

        const validation = await validateIban(iban);
        if (!validation.valid) {
            currentIbanValid = false;
            setIbanFeedback('Invalid account number. Please double-check.', 'error');
            updateTransferButtonState();
            return;
        }

        fetch(`https://${GetParentResourceName()}/transfer`, {
            method: 'POST',
            body: JSON.stringify({ iban: iban, amount: amt, accountType: currentAccountType })
        });
        transferIbanInput.value = '';
        transferAmountInput.value = '';
        resetIbanFeedback();
        setTimeout(refreshData, 300);
    });
}

async function validateIban(iban) {
    try {
        const res = await fetch(`https://${GetParentResourceName()}/validateIBAN`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ iban })
        });
        const data = await res.json();
        return data || { valid: false };
    } catch (err) {
        console.error('IBAN validation failed', err);
        return { valid: false };
    }
}

document.getElementById('btn-change-pin').addEventListener('click', () => {
    const current = document.getElementById('inp-current-pin').value;
    const newPin = document.getElementById('inp-new-pin').value;
    const confirm = document.getElementById('inp-confirm-pin').value;
    if (newPin.length !== 4 || newPin !== confirm) return;
    fetch(`https://${GetParentResourceName()}/changePIN`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ currentPin: current, newPin: newPin })
    }).then(() => {
        document.getElementById('inp-current-pin').value = '';
        document.getElementById('inp-new-pin').value = '';
        document.getElementById('inp-confirm-pin').value = '';
    });
});

document.getElementById('btn-order-card').addEventListener('click', () => {
    const url = document.getElementById('inp-card-url').value;
    if (!url) return;
    fetch(`https://${GetParentResourceName()}/updateCard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: url })
    }).then(() => refreshData());
});

document.getElementById('btn-remove-card').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/updateCard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: "REMOVE" })
    }).then(() => refreshData());
});

const updateAvatarBtn = document.getElementById('btn-update-avatar');
if (updateAvatarBtn) {
    updateAvatarBtn.addEventListener('click', () => {
        const url = document.getElementById('inp-avatar-url').value;
        if (!url) return;
        fetch(`https://${GetParentResourceName()}/updateAvatar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url: url })
        }).then(() => {
            document.getElementById('inp-avatar-url').value = '';
            refreshData();
        });
    });
}

const removeAvatarBtn = document.getElementById('btn-remove-avatar');
if (removeAvatarBtn) {
    removeAvatarBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/updateAvatar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url: "REMOVE" })
        }).then(() => refreshData());
    });
}

function refreshData() {
    fetch(`https://${GetParentResourceName()}/refresh`, { 
        method: 'POST', 
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ accountType: currentAccountType })
    }).then(res => res.json()).then(data => updateUI(data));
}

// --- DRAWTEXT HANDLERS ---
function drawText(data) {
    const container = document.getElementById('drawtext-container');
    const msg = document.getElementById('drawtext-msg');
    const quip = document.getElementById('drawtext-quip');
    msg.innerText = data.text;
    if (quip) {
        const lines = quips[currentTheme]?.drawtext || quips.midnight.drawtext;
        quip.innerText = lines[Math.floor(Math.random() * lines.length)];
    }
    container.className = `drawtext-wrapper drawtext-${data.position || 'left'}`;
    container.classList.remove('hidden');
}

function hideText() {
    document.getElementById('drawtext-container').classList.add('hidden');
}

function keyPressed() {
    const key = document.getElementById('drawtext-key');
    key.classList.add('pressed');
    setTimeout(() => key.classList.remove('pressed'), 200);
}

// ===== ORGANIZATION PAGE =====
let currentOrgData = null;

function loadOrgData() {
    fetch(`https://${GetParentResourceName()}/getOrgData`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({})
    }).then(r => r.json()).then(data => renderOrgUI(data));
}

function renderOrgUI(data) {
    const noAcc   = document.getElementById('org-no-account');
    const main    = document.getElementById('org-main');
    const sidebarItem = document.getElementById('sidebar-org');

    if (!data) {
        // Not in a gang or not a member — hide sidebar tab
        if (sidebarItem) sidebarItem.classList.add('hidden');
        return;
    }

    if (sidebarItem) sidebarItem.classList.remove('hidden');
    currentOrgData = data;

    if (data.noAccount) {
        noAcc.classList.remove('hidden');
        main.classList.add('hidden');
        const title = document.getElementById('org-no-account-title');
        if (title) title.innerText = `No account for "${data.gangName}"`;
        return;
    }

    noAcc.classList.add('hidden');
    main.classList.remove('hidden');

    // Header
    document.getElementById('org-name-display').innerText = data.label || data.orgId;
    document.getElementById('org-account-no-display').innerText = data.accountNo || '—';
    document.getElementById('org-balance-display').innerText = `${(data.balance || 0).toLocaleString()} ${currencySymbol}`;

    const roleBadge = document.getElementById('org-role-badge');
    if (roleBadge) {
        roleBadge.innerText = (data.myRole || 'member').toUpperCase();
        roleBadge.className = `org-role-badge org-role-${data.myRole || 'member'}`;
    }

    // Show/hide admin controls
    const canManage = data.myRole === 'owner';
    const canWithdraw = data.myRole === 'owner' || data.myRole === 'admin';
    document.getElementById('org-withdraw-group')?.classList.toggle('hidden', !canWithdraw);
    document.getElementById('org-transfer-group')?.classList.toggle('hidden', !canWithdraw);
    document.getElementById('org-btn-add-member')?.classList.toggle('hidden', !canManage);

    renderOrgMembers(data.members, data.myRole, data.orgId);
    renderOrgTransactions(data.transactions);
}

function renderOrgMembers(members, myRole, orgId) {
    const list = document.getElementById('org-member-list');
    if (!list) return;
    list.innerHTML = '';
    if (!members || !members.length) {
        list.innerHTML = '<div class="no-loan-sub" style="padding:12px 0">No members yet.</div>';
        return;
    }
    const roleIcons = { owner: '👑', admin: '⚙️', member: '👤' };
    members.forEach(m => {
        const name = [m.fname, m.lname].filter(Boolean).join(' ') || m.citizenid;
        const isMe = m.citizenid === currentOrgData?.myRole; // rough check
        const row = document.createElement('div');
        row.className = 'org-member-row';
        row.innerHTML = `
            <div class="org-member-avatar">${(name[0] || '?').toUpperCase()}</div>
            <div class="org-member-info">
                <div class="org-member-name">${name}</div>
                <div class="org-member-role-text">${roleIcons[m.role] || '👤'} ${(m.role || 'member').charAt(0).toUpperCase() + m.role.slice(1)}</div>
            </div>
            ${myRole === 'owner' && m.role !== 'owner' ? `
            <div class="org-member-actions">
                <button class="org-role-btn" data-cid="${m.citizenid}" data-role="${m.role === 'admin' ? 'member' : 'admin'}">
                    ${m.role === 'admin' ? '↓ Demote' : '↑ Promote'}
                </button>
                <button class="org-remove-btn" data-cid="${m.citizenid}">✕</button>
            </div>` : ''}
        `;
        list.appendChild(row);
    });

    // Promote/demote
    list.querySelectorAll('.org-role-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const cid = btn.dataset.cid, role = btn.dataset.role;
            fetch(`https://${GetParentResourceName()}/orgSetRole`, {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ citizenid: cid, role })
            }).then(r => r.json()).then(ok => { if (ok) loadOrgData(); });
        });
    });

    // Remove
    list.querySelectorAll('.org-remove-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/orgRemoveMember`, {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ citizenid: btn.dataset.cid })
            }).then(r => r.json()).then(ok => { if (ok) loadOrgData(); });
        });
    });
}

function renderOrgTransactions(txs) {
    const list = document.getElementById('org-tx-list');
    if (!list) return;
    list.innerHTML = '';
    if (!txs || !txs.length) {
        list.innerHTML = '<div class="no-loan-sub" style="padding:12px 0">No activity yet.</div>';
        return;
    }
    txs.forEach(t => {
        const isIn = t.type === 'income';
        const row = document.createElement('div');
        row.className = 'transaction-row';
        row.innerHTML = `
            <div class="transaction-details">
                <div class="transaction-icon ${isIn ? 'income' : 'outcome'}">
                    <i class="fa-solid ${isIn ? 'fa-arrow-down' : 'fa-arrow-up'}"></i>
                </div>
                <div class="transaction-meta">
                    <div style="font-weight:700;font-size:15px">${t.label}</div>
                    <div style="font-size:12px;opacity:.45">${t.player_name} &bull; ${new Date(t.date).toLocaleString()}</div>
                </div>
            </div>
            <div class="${isIn ? 'text-income' : 'text-outcome'}">
                ${isIn ? '+' : '-'}${t.amount.toLocaleString()} ${currencySymbol}
            </div>`;
        list.appendChild(row);
    });
}

// Org deposit
document.getElementById('org-btn-deposit')?.addEventListener('click', () => {
    const inp = document.getElementById('org-inp-deposit');
    const amt = getNumericValue(inp);
    if (!amt || amt <= 0) return;
    fetch(`https://${GetParentResourceName()}/orgDeposit`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ amount: amt })
    }).then(r => r.json()).then(ok => { if (ok) { inp.value = ''; loadOrgData(); playSound(configAudio.Success, 0.5); } });
});

// Org withdraw
document.getElementById('org-btn-withdraw')?.addEventListener('click', () => {
    const inp = document.getElementById('org-inp-withdraw');
    const amt = getNumericValue(inp);
    if (!amt || amt <= 0) return;
    fetch(`https://${GetParentResourceName()}/orgWithdraw`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ amount: amt })
    }).then(r => r.json()).then(ok => { if (ok) { inp.value = ''; loadOrgData(); playSound(configAudio.Success, 0.5); } });
});

// Org transfer
document.getElementById('org-btn-transfer')?.addEventListener('click', () => {
    const ibanInp = document.getElementById('org-inp-transfer-iban');
    const amtInp  = document.getElementById('org-inp-transfer-amount');
    const iban = ibanInp?.value.trim();
    const amt  = getNumericValue(amtInp);
    if (!iban || !amt || amt <= 0) return;
    fetch(`https://${GetParentResourceName()}/orgTransfer`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ iban, amount: amt })
    }).then(r => r.json()).then(ok => {
        if (ok) { ibanInp.value = ''; amtInp.value = ''; loadOrgData(); playSound(configAudio.Success, 0.5); }
    });
});

// Add member toggle
document.getElementById('org-btn-add-member')?.addEventListener('click', () => {
    const form = document.getElementById('org-add-member-form');
    form?.classList.toggle('hidden');
});

document.getElementById('org-btn-confirm-add')?.addEventListener('click', () => {
    const inp = document.getElementById('org-inp-add-acc');
    const accNo = inp?.value.trim();
    if (!accNo) return;
    fetch(`https://${GetParentResourceName()}/orgAddMember`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ accountNo: accNo })
    }).then(r => r.json()).then(res => {
        if (res?.ok) {
            inp.value = '';
            document.getElementById('org-add-member-form')?.classList.add('hidden');
            showToast(`${res.name} added as member`, 'success');
            loadOrgData();
        } else {
            showToast(res?.reason || 'Could not add member.', 'error');
        }
    });
});

// Number formatting for org inputs
['org-inp-deposit','org-inp-withdraw','org-inp-transfer-amount'].forEach(id => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener('keydown', e => {
        if ([46,8,9,27,13].includes(e.keyCode)||(e.keyCode>=35&&e.keyCode<=40)) return;
        if ((e.shiftKey||(e.keyCode<48||e.keyCode>57))&&(e.keyCode<96||e.keyCode>105)) e.preventDefault();
    });
    el.addEventListener('input', () => formatNumberInput(el));
});

// ===== TOAST =====
function showToast(message, type = 'info', duration = 3500) {
    const container = document.getElementById('toast-container');
    if (!container) return;
    const icons = { success: 'fa-circle-check', error: 'fa-circle-xmark', info: 'fa-circle-info' };
    const toast = document.createElement('div');
    toast.className = `toast-item toast-${type}`;
    toast.innerHTML = `<i class="fa-solid ${icons[type] || icons.info} toast-icon"></i><span>${message}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
        toast.classList.add('toast-out');
        setTimeout(() => toast.remove(), 350);
    }, duration);
}

// ===== STAT PILLS =====
function updateStatPills(transactions) {
    const now = Date.now();
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000;
    let income = 0, outcome = 0;
    (transactions || []).forEach(t => {
        const ts = new Date(t.date).getTime();
        if (ts >= thirtyDaysAgo) {
            if (t.type === 'income') income += t.amount;
            else outcome += t.amount;
        }
    });
    const incomeEl = document.getElementById('stat-income-total');
    const outcomeEl = document.getElementById('stat-outcome-total');
    if (incomeEl) incomeEl.innerText = `${income.toLocaleString()} ${currencySymbol}`;
    if (outcomeEl) outcomeEl.innerText = `${outcome.toLocaleString()} ${currencySymbol}`;
}

// ===== QUICK CONTACTS =====
function renderQuickContacts(transactions) {
    const chipsEl = document.getElementById('quick-contacts-chips');
    const rowEl = document.getElementById('quick-contacts-row');
    if (!chipsEl || !rowEl) return;
    const seen = new Set();
    const contacts = [];
    (transactions || []).filter(t => t.type === 'outcome' && t.iban).forEach(t => {
        if (!seen.has(t.iban) && contacts.length < 5) {
            seen.add(t.iban);
            contacts.push({ name: t.label, iban: t.iban });
        }
    });
    if (!contacts.length) { rowEl.classList.add('hidden'); return; }
    chipsEl.innerHTML = '';
    contacts.forEach(c => {
        const initials = (c.name || '?').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
        const chip = document.createElement('div');
        chip.className = 'contact-chip';
        chip.innerHTML = `<div class="contact-chip-avatar">${initials}</div><span>${c.name || c.iban}</span>`;
        chip.addEventListener('click', () => {
            const ibanInput = document.getElementById('inp-transfer-iban');
            if (ibanInput) {
                ibanInput.value = c.iban;
                ibanInput.dispatchEvent(new Event('input'));
            }
            playSound(configAudio.Click, 0.15);
        });
        chipsEl.appendChild(chip);
    });
    rowEl.classList.remove('hidden');
}

// ===== RECIPIENT PREVIEW =====
function showRecipientPreview(name, iban) {
    const preview = document.getElementById('recipient-preview');
    if (!preview) return;
    const initials = (name || '?').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
    document.getElementById('recipient-initials').innerText = initials;
    document.getElementById('recipient-name-display').innerText = name || 'Unknown';
    document.getElementById('recipient-iban-display').innerText = iban || '';
    preview.classList.remove('hidden');
}
function hideRecipientPreview() {
    const preview = document.getElementById('recipient-preview');
    if (preview) preview.classList.add('hidden');
}

// ===== LOAN PAGE =====
let currentLoanData = null;
let currentLoanRate = 10;

function loadLoanData() {
    fetch(`https://${GetParentResourceName()}/getLoanData`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(data => renderLoanUI(data));
}

function renderLoanUI(data) {
    if (!data) return;
    currentLoanData = data;
    currentLoanRate = data.interestRate || 10;

    const activeLoanCard = document.getElementById('active-loan-card');
    const noLoanCard = document.getElementById('no-loan-card');
    const loanFormCard = document.getElementById('loan-form-card');
    const loanBadge = document.getElementById('loan-badge');
    const frozenBanner = document.getElementById('loan-frozen-banner');

    document.getElementById('loan-summary-rate').innerText = currentLoanRate;

    // Frozen banner
    if (frozenBanner) {
        if (data.accountLocked) frozenBanner.classList.remove('hidden');
        else frozenBanner.classList.add('hidden');
    }

    if (data.hasLoan && data.loan) {
        const loan = data.loan;
        const pct = 0; // server tracks full remaining; no partial yet

        document.getElementById('loan-amount-display').innerText = `${(loan.remaining || loan.amount).toLocaleString()} ${currencySymbol}`;
        document.getElementById('loan-due-display').innerText = loan.due_date ? new Date(loan.due_date).toLocaleDateString() : '—';
        document.getElementById('loan-rate-text').innerText = `${currentLoanRate}% interest${data.penaltyApplied ? ' +15% penalty' : ''}`;
        document.getElementById('loan-progress-bar').style.width = `100%`;

        // Red bar when overdue
        const bar = document.getElementById('loan-progress-bar');
        if (data.daysOverdue > 0) {
            bar.style.background = 'linear-gradient(90deg, #ef4444, #f59e0b)';
        } else {
            bar.style.background = '';
        }

        activeLoanCard.classList.remove('hidden');
        noLoanCard.classList.add('hidden');
        loanFormCard.classList.add('hidden');
        if (loanBadge) { loanBadge.innerText = '!'; loanBadge.classList.remove('hidden'); }
    } else {
        activeLoanCard.classList.add('hidden');
        noLoanCard.classList.remove('hidden');
        loanFormCard.classList.remove('hidden');
        if (loanBadge) loanBadge.classList.add('hidden');

        // Update preset labels from config
        const maxLoan = data.maxLoanAmount || 200000;
        const presets = [
            Math.round(maxLoan * 0.05),
            Math.round(maxLoan * 0.125),
            Math.round(maxLoan * 0.25),
            Math.round(maxLoan * 0.5)
        ];
        document.querySelectorAll('.loan-preset-btn').forEach((btn, i) => {
            const amt = presets[i];
            btn.dataset.amount = amt;
            btn.innerText = amt >= 1000 ? `$${Math.round(amt / 1000)}K` : `$${amt}`;
        });
    }
}

function updateLoanSummary(amount) {
    const summaryEl = document.getElementById('loan-summary');
    if (!amount || amount <= 0) { summaryEl.classList.remove('visible'); return; }
    const interest = Math.round(amount * (currentLoanRate / 100));
    const total = amount + interest;
    document.getElementById('loan-summary-principal').innerText = `${amount.toLocaleString()} ${currencySymbol}`;
    document.getElementById('loan-summary-interest').innerText = `${interest.toLocaleString()} ${currencySymbol}`;
    document.getElementById('loan-summary-total').innerText = `${total.toLocaleString()} ${currencySymbol}`;
    summaryEl.classList.add('visible');
}

// Loan preset buttons
document.querySelectorAll('.loan-preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.loan-preset-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const amt = parseInt(btn.dataset.amount, 10);
        const inp = document.getElementById('inp-loan-amount');
        if (inp) { inp.value = amt.toLocaleString(); updateLoanSummary(amt); }
        playSound(configAudio.Click, 0.15);
    });
});

// Loan amount input live summary
const loanAmountInput = document.getElementById('inp-loan-amount');
if (loanAmountInput) {
    ['inp-loan-amount'].forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener('keydown', (e) => {
                if ([46,8,9,27,13].includes(e.keyCode) ||
                    (e.keyCode===65&&(e.ctrlKey||e.metaKey)) ||
                    (e.keyCode>=35&&e.keyCode<=40)) return;
                if ((e.shiftKey||(e.keyCode<48||e.keyCode>57))&&(e.keyCode<96||e.keyCode>105)) e.preventDefault();
            });
            el.addEventListener('input', () => {
                formatNumberInput(el);
                updateLoanSummary(getNumericValue(el));
            });
        }
    });
}

// Take loan button
const takeLoanBtn = document.getElementById('btn-take-loan');
if (takeLoanBtn) {
    takeLoanBtn.addEventListener('click', () => {
        const amt = getNumericValue(document.getElementById('inp-loan-amount'));
        if (!amt || amt <= 0) return;
        fetch(`https://${GetParentResourceName()}/takeLoan`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount: amt })
        }).then(res => res.json()).then(ok => {
            if (ok) { loadLoanData(); refreshData(); playSound(configAudio.Success, 0.6); }
        });
    });
}

// Repay loan button
const repayLoanBtn = document.getElementById('btn-repay-loan');
if (repayLoanBtn) {
    repayLoanBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/repayLoan`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).then(res => res.json()).then(ok => {
            if (ok) { loadLoanData(); refreshData(); playSound(configAudio.Success, 0.6); }
        });
    });
}

// ===== ADMIN DASHBOARD =====
let adminPlayerList = [];
let currentInspectCid = null;

function openAdminDashboard(data) {
    if (!data) return;
    adminPlayerList = data.players || [];
    const adminUI = document.getElementById('admin-ui');
    if (!adminUI) return;
    adminUI.style.display = 'flex';
    shield.style.display = 'block';
    setTimeout(() => adminUI.classList.add('show'), 20);
    renderAdminPlayers();
}

function closeAdminUI() {
    const adminUI = document.getElementById('admin-ui');
    if (!adminUI) return;
    adminUI.classList.remove('show');
    setTimeout(() => {
        adminUI.style.display = 'none';
        shield.style.display = 'none';
    }, 300);
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
}

function renderAdminPlayers() {
    const list = document.getElementById('admin-player-list');
    if (!list) return;
    list.innerHTML = '';
    if (!adminPlayerList.length) {
        list.innerHTML = '<div class="admin-no-players"><i class="fa-solid fa-users-slash"></i><br>No players online</div>';
        return;
    }
    adminPlayerList.forEach(p => {
        const initials = (p.name || '?').split(' ').map(w => w[0]).join('').slice(0,2).toUpperCase();
        const row = document.createElement('div');
        row.className = 'admin-player-row';
        row.innerHTML = `
            <div class="admin-player-avatar">${initials}</div>
            <div class="admin-player-info">
                <div class="admin-player-name">${p.name}<span class="admin-player-id">[${p.source}]</span></div>
                <div class="admin-player-cid">${p.citizenid}</div>
            </div>
            <button class="admin-inspect-btn" data-cid="${p.citizenid}">
                <i class="fa-solid fa-magnifying-glass"></i> Inspect
            </button>`;
        list.appendChild(row);
    });

    list.querySelectorAll('.admin-inspect-btn').forEach(btn => {
        btn.addEventListener('click', () => openAdminInspect(btn.dataset.cid));
    });
}

async function openAdminInspect(citizenid) {
    currentInspectCid = citizenid;
    const modal = document.getElementById('admin-inspect-modal');
    const body  = document.getElementById('admin-inspect-body');
    const actions = document.getElementById('admin-inspect-actions');
    if (!modal) return;

    body.innerHTML = '<div style="text-align:center;opacity:.5;padding:20px">Loading...</div>';
    actions.innerHTML = '';
    modal.classList.remove('hidden');
    modal.style.display = 'flex';

    const info = await fetch(`https://${GetParentResourceName()}/adminInspect`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid })
    }).then(r => r.json());

    if (!info) {
        body.innerHTML = '<div style="text-align:center;color:#ef4444;padding:20px">Access denied or player not found.</div>';
        return;
    }

    const isFrozen = info.loan?.locked;
    const hasLoan  = !!info.loan && info.loan.amount > 0;

    body.innerHTML = `
        <div class="admin-info-row"><span class="admin-info-label">Citizen ID</span><span class="admin-info-value" style="font-family:monospace">${info.citizenid}</span></div>
        <div class="admin-info-row"><span class="admin-info-label">Account No.</span><span class="admin-info-value">${info.accNo || '—'}</span></div>
        <div class="admin-info-row"><span class="admin-info-label">Bank Balance</span><span class="admin-info-value">${(info.balance || 0).toLocaleString()} ${currencySymbol}</span></div>
        <div class="admin-info-row">
            <span class="admin-info-label">Account Status</span>
            <span class="admin-info-value ${isFrozen ? 'frozen' : 'ok'}">${isFrozen ? '🔒 FROZEN' : '✅ Active'}</span>
        </div>
        <div class="admin-info-row">
            <span class="admin-info-label">Active Loan</span>
            <span class="admin-info-value ${hasLoan ? 'frozen' : 'ok'}">${hasLoan ? (info.loan.amount || 0).toLocaleString() + ' ' + currencySymbol : 'None'}</span>
        </div>`;

    actions.innerHTML = `
        <button class="admin-action-btn ${isFrozen ? 'admin-action-btn--unfreeze' : 'admin-action-btn--freeze'}" id="admin-btn-freeze">
            <i class="fa-solid ${isFrozen ? 'fa-lock-open' : 'fa-lock'}"></i>
            ${isFrozen ? 'Unfreeze' : 'Freeze'} Account
        </button>
        <button class="admin-action-btn admin-action-btn--pin" id="admin-btn-pin">
            <i class="fa-solid fa-key"></i> Reset PIN
        </button>
        ${hasLoan ? `<button class="admin-action-btn admin-action-btn--loan" id="admin-btn-loan" style="grid-column:1/-1">
            <i class="fa-solid fa-trash-can"></i> Force Clear Loan
        </button>` : ''}`;

    document.getElementById('admin-btn-freeze')?.addEventListener('click', async () => {
        const res = await fetch(`https://${GetParentResourceName()}/adminToggleFreeze`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid })
        }).then(r => r.json());
        if (res) {
            showToast(`Account ${res.frozen ? 'frozen' : 'unfrozen'}`, res.frozen ? 'error' : 'success');
            openAdminInspect(citizenid); // refresh
        }
    });

    document.getElementById('admin-btn-pin')?.addEventListener('click', async () => {
        const ok = await fetch(`https://${GetParentResourceName()}/adminResetPIN`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid })
        }).then(r => r.json());
        showToast(ok ? 'PIN reset to default' : 'Failed to reset PIN', ok ? 'success' : 'error');
    });

    document.getElementById('admin-btn-loan')?.addEventListener('click', async () => {
        const ok = await fetch(`https://${GetParentResourceName()}/adminClearLoan`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ citizenid })
        }).then(r => r.json());
        if (ok) {
            showToast('Loan cleared', 'success');
            openAdminInspect(citizenid);
        } else {
            showToast('Failed to clear loan', 'error');
        }
    });
}

document.getElementById('admin-close-btn')?.addEventListener('click', closeAdminUI);
document.getElementById('admin-modal-close')?.addEventListener('click', () => {
    const modal = document.getElementById('admin-inspect-modal');
    if (modal) { modal.classList.add('hidden'); modal.style.display = 'none'; }
});

window.addEventListener('message', (event) => {
    const action = event.data.action;
    if (action === 'open_pin') {
        currentLocale = event.data.locale;
        if (event.data.audio) configAudio = event.data.audio;
        atmContainer.style.display = 'flex';
        shield.style.display = 'block'; 
        showAtmQuip();
        document.body.style.background = "transparent";
        setTimeout(() => atmUI.classList.add('show'), 50);
    } else if (action === 'open_admin') {
        if (event.data.audio) configAudio = event.data.audio;
        openAdminDashboard(event.data.data);
    } else if (action === 'open_bank') {
        if (event.data.audio) configAudio = event.data.audio;
        openBankDashboard(event.data.data, event.data.locale);
    } else if (action === 'DRAW_TEXT') {
        drawText(event.data.data);
    } else if (action === 'HIDE_TEXT') {
        hideText();
    } else if (action === 'CHANGE_TEXT') {
        drawText(event.data.data);
    } else if (action === 'KEY_PRESSED') {
        keyPressed();
    } else if (action === 'toast') {
        showToast(event.data.message, event.data.toastType || 'info');
    }
});