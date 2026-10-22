import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  createUserWithEmailAndPassword,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  updateProfile,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  arrayUnion,
  collection,
  doc,
  getDocs,
  getFirestore,
  increment,
  limit,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const root = document.querySelector("#app");
const avatars = ["🐦", "🕊️", "🐤", "🦜", "🦉", "🦅", "🦆", "🦢", "🐧", "🐥", "🦩"];

function readTheme() {
  try {
    return localStorage.getItem("ppp-theme") || "dark";
  } catch {
    return "dark";
  }
}

const state = {
  user: null,
  profile: null,
  nest: null,
  tasks: [],
  completions: {},
  screen: "home",
  filter: "both",
  calendarDate: new Date(),
  selectedDate: localDateKey(new Date()),
  authMode: "signin",
  avatar: avatars[0],
  busy: false,
  error: "",
  success: "",
  theme: readTheme(),
};
let auth;
let db;
let profileUnsubscribe;
let nestUnsubscribe;
let tasksUnsubscribe;
let completionListeners = new Map();
let toastTimer;

function localDateKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function fromDateKey(key) {
  const [year, month, day] = key.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function escapeHtml(value = "") {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[character]);
}

function asDate(value) {
  if (value?.toDate) return value.toDate();
  if (value instanceof Date) return value;
  return value ? new Date(value) : new Date();
}

function showMessage(message, kind = "error") {
  state[kind] = message;
  render();
  if (kind === "success") {
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      state.success = "";
      render();
    }, 3200);
  }
}

function clearListeners() {
  profileUnsubscribe?.();
  nestUnsubscribe?.();
  tasksUnsubscribe?.();
  completionListeners.forEach((unsubscribe) => unsubscribe());
  profileUnsubscribe = nestUnsubscribe = tasksUnsubscribe = null;
  completionListeners = new Map();
  state.profile = state.nest = null;
  state.tasks = [];
  state.completions = {};
}

function renderAuth() {
  const signup = state.authMode === "signup";
  return `
    <main class="auth-layout">
      <section class="auth-story">
        <a class="brand" href="/" aria-label="Proper Productive Pigeons home"><span class="brand-mark">P</span><span>PROPER<br />PRODUCTIVE PIGEONS</span></a>
        <div class="story-copy">
          <p class="eyebrow"><span class="eyebrow-dot"></span> YOUR NEXT LEVEL STARTS TODAY</p>
          <h1>Small habits.<br /><span>Shared victories.</span></h1>
          <p class="story-description">Build consistency one check-in at a time. Create your own goals, invite your person, and celebrate every milestone together.</p>
          <div class="story-stats"><div><b>01</b><span>Set your goals</span></div><div><b>02</b><span>Show up daily</span></div><div><b>03</b><span>Earn your rewards</span></div></div>
        </div>
        <div class="story-footer"><span class="tiny-orbit">✦</span> A little progress, every day.</div>
      </section>
      <section class="auth-side">
        <div class="auth-card">
          <div class="mobile-brand"><span class="brand-mark">P</span><span>PROPER PRODUCTIVE PIGEONS</span></div>
          <p class="eyebrow">${signup ? "START YOUR JOURNEY" : "WELCOME BACK"}</p>
          <h2>${signup ? "Create your account" : "Good to see you."}</h2>
          <p class="muted">${signup ? "Your next chapter starts with one small step." : "Sign in and pick up where you left off."}</p>
          <div class="auth-switch" role="tablist">
            <button type="button" data-action="auth-mode" data-mode="signin" class="${signup ? "" : "selected"}">Sign in</button>
            <button type="button" data-action="auth-mode" data-mode="signup" class="${signup ? "selected" : ""}">Create account</button>
          </div>
          ${state.error ? `<div class="alert error" role="alert">${escapeHtml(state.error)}</div>` : ""}
          <form id="auth-form" class="form-stack">
            ${signup ? `<label>Your name<input name="name" autocomplete="name" placeholder="How should we call you?" required maxlength="40" /></label>
              <div class="field-label">Choose your pigeon</div><div class="avatar-picker">${avatars.map((avatar) => `<button type="button" class="avatar-choice ${state.avatar === avatar ? "selected" : ""}" data-action="avatar" data-avatar="${avatar}" aria-label="Choose ${avatar}" aria-pressed="${state.avatar === avatar}">${avatar}</button>`).join("")}</div>` : ""}
            <label>Email address<input name="email" type="email" autocomplete="email" placeholder="you@example.com" required /></label>
            <label>Password<input name="password" type="password" autocomplete="${signup ? "new-password" : "current-password"}" placeholder="At least 6 characters" minlength="6" required /></label>
            <button class="button primary full" type="submit" ${state.busy ? "disabled" : ""}>${state.busy ? "Please wait…" : signup ? "Create account" : "Sign in"} <span>↗</span></button>
          </form>
          <p class="auth-note">Your progress is securely synced with your Firebase account.</p>
        </div>
      </section>
    </main>`;
}

function renderNestSetup() {
  const name = escapeHtml(state.profile.name || "friend");
  return `
    <main class="setup-layout">
      <header class="setup-header"><a class="brand" href="/"><span class="brand-mark">P</span><span>PROPER<br />PRODUCTIVE PIGEONS</span></a><button class="button ghost" data-action="signout">Sign out</button></header>
      <section class="setup-content">
        <p class="eyebrow"><span class="eyebrow-dot"></span> YOUR SHARED SPACE</p>
        <h1>Welcome, ${name}.</h1><p class="muted setup-lead">Create a nest for your goals, or join your partner’s with an invite code.</p>
        ${state.error ? `<div class="alert error" role="alert">${escapeHtml(state.error)}</div>` : ""}
        <div class="setup-cards">
          <form id="create-nest-form" class="setup-card">
            <div class="setup-icon gold-icon">✦</div><h2>Create a nest</h2><p>Start your shared space and invite one person to join you.</p>
            <label>Nest name<input name="nestName" maxlength="40" placeholder="The Sunday Club" required /></label>
            <button class="button primary full" type="submit" ${state.busy ? "disabled" : ""}>Create nest <span>↗</span></button>
          </form>
          <form id="join-nest-form" class="setup-card">
            <div class="setup-icon purple-icon">⌁</div><h2>Join a nest</h2><p>Enter the six-character invite code shared with you.</p>
            <label>Invite code<input name="inviteCode" class="code-input" maxlength="6" autocomplete="off" placeholder="ABC123" required /></label>
            <button class="button secondary full" type="submit" ${state.busy ? "disabled" : ""}>Join nest <span>↗</span></button>
          </form>
        </div>
        <p class="setup-footnote">Nests are private and can have up to two members.</p>
      </section>
    </main>`;
}

function renderApp() {
  const name = escapeHtml(state.profile.name || "Pigeon");
  const initials = (state.profile.name || "P").trim().slice(0, 1).toUpperCase();
  const page = state.screen === "activity" ? renderActivity() : renderHome();
  return `
    <div class="app-shell">
      <aside class="sidebar">
        <a class="brand" href="/" aria-label="Proper Productive Pigeons home"><span class="brand-mark">P</span><span>PROPER<br />PRODUCTIVE PIGEONS</span></a>
        <div class="sidebar-label">WORKSPACE</div>
        <nav class="side-nav" aria-label="Main navigation">
          <button data-action="navigate" data-screen="home" class="${state.screen === "home" ? "active" : ""}"><span class="nav-symbol">⌂</span> Today</button>
          <button data-action="navigate" data-screen="activity" class="${state.screen === "activity" ? "active" : ""}"><span class="nav-symbol">▦</span> Activity</button>
        </nav>
        <div class="sidebar-spacer"></div>
        <div class="nest-mini"><span class="nest-mini-icon">✦</span><div><b>${escapeHtml(state.nest.name)}</b><small>${state.nest.pigeons?.length || 1} / 2 members</small></div></div>
        <div class="sidebar-profile"><div class="user-avatar">${escapeHtml(state.profile.avatar || "🐦")}</div><div class="user-meta"><b>${name}</b><small>${escapeHtml(consistencyLabel(state.profile.total_tasks_completed || 0))}</small></div><button class="icon-button" data-action="signout" title="Sign out" aria-label="Sign out">↗</button></div>
      </aside>
      <div class="app-main">
        <header class="topbar">
          <div class="breadcrumb"><span>Workspace</span><b>/</b><strong>${state.screen === "activity" ? "Activity" : "Today"}</strong></div>
          <div class="topbar-actions"><span class="date-pill"><span class="live-dot"></span>${new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(new Date())}</span><button class="theme-button" data-action="theme" aria-label="Toggle color theme">${state.theme === "dark" ? "☼" : "☾"}</button><div class="user-avatar top-avatar">${escapeHtml(state.profile.avatar || "🐦")}</div></div>
        </header>
        <main class="page-content">
          ${state.error ? `<div class="alert error" role="alert">${escapeHtml(state.error)}<button data-action="dismiss-error" aria-label="Dismiss">×</button></div>` : ""}
          ${state.success ? `<div class="alert success" role="status">${escapeHtml(state.success)}</div>` : ""}
          ${page}
        </main>
      </div>
    </div>`;
}

function consistencyLabel(total) {
  if (total >= 100) return "Unstoppable";
  if (total >= 50) return "Exceptional";
  if (total >= 25) return "Remarkable";
  if (total >= 10) return "Impressive";
  return "Growing";
}

function isScheduled(task, date) {
  const created = asDate(task.created_at);
  if (localDateKey(date) < localDateKey(created)) return false;
  return task.frequency !== "weekly" || date.getDay() === created.getDay();
}

function participantIds(task) {
  if (task.task_type === "personal") return [task.created_by];
  return state.nest.pigeons || [state.user.uid];
}

function completionFor(task, date, pigeonId) {
  return Boolean(state.completions[task.id]?.[`${pigeonId}_${localDateKey(date)}`]?.is_complete);
}

function ownCompletion(task, date = new Date()) {
  return completionFor(task, date, state.user.uid);
}

function progressFor(task, date = new Date()) {
  const people = participantIds(task);
  const done = people.filter((id) => completionFor(task, date, id)).length;
  return { done, total: people.length, ratio: people.length ? done / people.length : 0 };
}

function taskStreak(task) {
  let day = new Date();
  if (!ownCompletion(task, day)) {
    day.setDate(day.getDate() - 1);
    while (day >= asDate(task.created_at) && !isScheduled(task, day)) day.setDate(day.getDate() - 1);
  }
  let streak = 0;
  for (let count = 0; count < 370 && day >= asDate(task.created_at); count += 1) {
    if (!isScheduled(task, day)) {
      day.setDate(day.getDate() - 1);
      continue;
    }
    if (!ownCompletion(task, day)) break;
    streak += 1;
    day.setDate(day.getDate() - 1);
  }
  return streak;
}

function taskCard(task) {
  const done = ownCompletion(task);
  const shared = task.task_type === "shared";
  const progress = progressFor(task);
  const checkpoint = (task.checkpoints || []).slice().sort((a, b) => a.order - b.order).find((item) => taskStreak(task) < item.day_threshold);
  const checkpointTitle = checkpoint?.deserving?.title || "All milestones reached";
  const count = taskStreak(task);
  const target = checkpoint?.day_threshold || count;
  const percentage = target ? Math.min(100, Math.round((count / target) * 100)) : 100;
  return `
    <article class="task-card ${done ? "is-done" : ""}">
      <div class="task-icon ${shared ? "shared-icon" : ""}">${shared ? "↗" : "✦"}</div>
      <div class="task-main">
        <div class="task-title-row"><h3>${escapeHtml(task.name)}</h3><span class="tag ${shared ? "shared-tag" : ""}">${shared ? "SHARED" : "PERSONAL"}</span></div>
        <p class="task-description">${escapeHtml(task.description || "One small step at a time.")}</p>
        <div class="task-foot"><span class="streak">${count ? `🔥 ${count} day${count === 1 ? "" : "s"} in a row` : "Start your streak today"}</span><span class="task-schedule">${task.frequency === "weekly" ? `Weekly · ${new Intl.DateTimeFormat(undefined, { weekday: "long" }).format(asDate(task.created_at))}` : "Daily"}</span></div>
        <div class="milestone"><div class="milestone-label"><span>Next reward · ${escapeHtml(checkpointTitle)}</span><span>${Math.min(count, target)} / ${target}</span></div><div class="progress-track"><span style="width:${percentage}%"></span></div></div>
        ${shared ? `<div class="partner-progress"><span>${progress.done ? "♥" : "♡"} ${progress.done}/${progress.total} checked in today</span><div class="partner-dots">${participantIds(task).map((id) => `<i class="${completionFor(task, new Date(), id) ? "filled" : ""}"></i>`).join("")}</div></div>` : ""}
      </div>
      <button class="check-button ${done ? "checked" : ""}" data-action="toggle-task" data-task="${escapeHtml(task.id)}" aria-label="${done ? "Undo" : "Check in"} ${escapeHtml(task.name)}" ${state.busy ? "disabled" : ""}>${done ? "✓" : "+"}</button>
    </article>`;
}

function renderHome() {
  const tasks = state.tasks.filter((task) => task.task_type !== "personal" || task.created_by === state.user.uid);
  const scheduled = tasks.filter((task) => isScheduled(task, new Date()));
  const doneCount = scheduled.filter((task) => ownCompletion(task)).length;
  const progress = scheduled.length ? Math.round((doneCount / scheduled.length) * 100) : 0;
  const code = state.nest.invite_code || "------";
  const members = state.nest.pigeons || [];
  return `
    <section class="welcome-row"><div><p class="eyebrow"><span class="eyebrow-dot"></span> YOUR DAILY QUEST</p><h1>Good things grow<br />with <span>consistency.</span></h1><p class="muted">Every check-in is a promise you keep to yourself.</p></div><div class="level-card"><div class="level-orb">✦</div><div><small>YOUR LEVEL</small><b>${escapeHtml(consistencyLabel(state.profile.total_tasks_completed || 0))}</b><span>${Number(state.profile.total_tasks_completed || 0)} total check-ins</span></div></div></section>
    <section class="summary-grid">
      <article class="summary-card progress-summary"><div class="summary-top"><span class="summary-icon">◉</span><span class="summary-caption">TODAY'S PROGRESS</span><span class="summary-date">${new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(new Date())}</span></div><div class="summary-value">${doneCount}<span> / ${scheduled.length}</span></div><p>${scheduled.length ? `${progress}% of today complete` : "Add a goal to get started"}</p><div class="summary-progress"><span style="width:${progress}%"></span></div></article>
      <article class="summary-card partner-summary"><div class="summary-top"><span class="summary-icon">♡</span><span class="summary-caption">YOUR NEST</span><span class="nest-status">${members.length === 2 ? "TOGETHER" : "WAITING"}</span></div><div class="nest-name">${escapeHtml(state.nest.name)}</div><p>${members.length === 2 ? "Your partner is in your corner." : "Invite your person to join you."}</p><div class="invite-row"><span>INVITE CODE <b>${escapeHtml(code)}</b></span><button data-action="copy-code" title="Copy invite code">⧉</button></div></article>
    </section>
    <section class="section-heading"><div><p class="eyebrow">MAKE TODAY COUNT</p><h2>Today's goals <span class="count-badge">${scheduled.length}</span></h2></div><button class="button primary" data-action="new-task"><span>＋</span> New goal</button></section>
    <section class="task-list">${scheduled.length ? scheduled.map(taskCard).join("") : `<div class="empty-state"><span>✦</span><h3>Your first goal starts here</h3><p>Choose one small habit you want to make part of your day.</p><button class="button primary" data-action="new-task">Create your first goal ↗</button></div>`}</section>
    <section class="daily-quote"><span>“</span><p>Discipline is choosing what you want most over what you want now.</p><small>YOUR DAILY REMINDER</small></section>
    ${renderModal()}`;
}

function renderModal() {
  if (!state.modal) return "";
  if (state.modal === "goal") {
    return `<div class="modal-backdrop" data-action="close-modal"><section class="modal-card" role="dialog" aria-modal="true" aria-labelledby="goal-title"><button class="modal-close" data-action="close-modal" aria-label="Close">×</button><p class="eyebrow">BUILD YOUR ROUTINE</p><h2 id="goal-title">Create a new goal</h2><p class="muted">Small, repeatable steps lead to the best rewards.</p>
      <form id="goal-form" class="form-stack">
        <label>Goal name<input name="name" maxlength="60" placeholder="Read for 20 minutes" required /></label>
        <label>Description <span class="optional">OPTIONAL</span><textarea name="description" maxlength="180" rows="2" placeholder="A little context for your future self"></textarea></label>
        <div class="form-row"><label>Goal type<select name="taskType"><option value="personal">Personal</option><option value="shared">Shared with my nest</option></select></label><label>Schedule<select name="frequency"><option value="daily">Every day</option><option value="weekly">Once a week</option></select></label></div>
        <div class="form-row"><label>First reward at<input name="threshold" type="number" min="1" max="365" value="4" required /></label><label>Reward title<input name="reward" maxlength="60" placeholder="A guilt-free movie night" required /></label></div>
        <button class="button primary full" type="submit" ${state.busy ? "disabled" : ""}>${state.busy ? "Creating…" : "Create goal"} <span>↗</span></button>
      </form></section></div>`;
  }
  return "";
}

function renderActivity() {
  const date = new Date(state.calendarDate.getFullYear(), state.calendarDate.getMonth(), 1);
  const monthLabel = new Intl.DateTimeFormat(undefined, { month: "long", year: "numeric" }).format(date);
  const firstDay = date.getDay();
  const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  const todayKey = localDateKey(new Date());
  const filteredTasks = state.tasks.filter((task) => (task.task_type !== "personal" || task.created_by === state.user.uid) && (state.filter === "both" || task.task_type === state.filter));
  const monthDates = Array.from({ length: daysInMonth }, (_, index) => new Date(date.getFullYear(), date.getMonth(), index + 1));
  let doneTotal = 0;
  let scheduledTotal = 0;
  let perfectDays = 0;
  const cells = Array.from({ length: firstDay }, () => `<span class="calendar-blank"></span>`);
  for (const day of monthDates) {
    const key = localDateKey(day);
    const due = filteredTasks.filter((task) => isScheduled(task, day));
    const done = day > new Date() ? 0 : due.reduce((sum, task) => sum + progressFor(task, day).ratio, 0);
    if (day <= new Date()) {
      scheduledTotal += due.length;
      doneTotal += done;
      if (due.length && done === due.length) perfectDays += 1;
    }
    const value = due.length ? done / due.length : 0;
    const level = value === 0 ? "none" : value < 0.5 ? "low" : value < 1 ? "mid" : "full";
    cells.push(`<button class="calendar-day ${key === todayKey ? "today" : ""} ${key === state.selectedDate ? "selected" : ""} ${day > new Date() ? "future" : ""}" data-action="select-date" data-date="${key}" title="${due.length ? `${Math.round(value * 100)}% complete` : "No goals scheduled"}"><span>${day.getDate()}</span>${due.length ? `<i class="day-dot ${level}"></i>` : ""}</button>`);
  }
  const pct = scheduledTotal ? Math.round((doneTotal / scheduledTotal) * 100) : 0;
  const selected = fromDateKey(state.selectedDate);
  const selectedTasks = state.tasks.filter((task) =>
    (task.task_type !== "personal" || task.created_by === state.user.uid) &&
    (state.filter === "both" || task.task_type === state.filter) && isScheduled(task, selected));
  const isFuture = selected > new Date();
  const dayRows = selectedTasks.length ? selectedTasks.map((task) => {
    const progress = progressFor(task, selected);
    const mine = ownCompletion(task, selected);
    return `<div class="day-task-row"><div><b>${escapeHtml(task.name)}</b><small>${task.task_type === "shared" ? `Shared · ${progress.done}/${progress.total} check-ins` : "Personal goal"}</small></div><span class="day-task-state ${progress.ratio === 1 ? "done" : progress.ratio ? "partial" : ""}">${isFuture ? "UPCOMING" : progress.ratio === 1 ? "COMPLETE" : progress.ratio ? "IN PROGRESS" : "MISSED"}</span>${selectedDateIsToday(selected) ? `<button class="small-check ${mine ? "checked" : ""}" data-action="toggle-task" data-task="${escapeHtml(task.id)}" aria-label="Toggle ${escapeHtml(task.name)}">${mine ? "✓" : "+"}</button>` : ""}</div>`;
  }).join("") : `<div class="empty-state compact"><span>◌</span><p>No goals scheduled for this day.</p></div>`;
  return `
    <section class="activity-heading"><div><p class="eyebrow"><span class="eyebrow-dot"></span> YOUR CONSISTENCY, IN VIEW</p><h1>Activity</h1><p class="muted">Look back at every small step that brought you here.</p></div><div class="activity-filter" role="group" aria-label="Filter goals">${[["personal", "Personal"], ["shared", "Shared"], ["both", "All goals"]].map(([value, label]) => `<button data-action="filter" data-filter="${value}" class="${state.filter === value ? "active" : ""}">${label}</button>`).join("")}</div></section>
    <section class="activity-layout"><div class="calendar-panel"><div class="calendar-head"><button class="calendar-arrow" data-action="month-shift" data-direction="-1" aria-label="Previous month">‹</button><div><h2>${monthLabel}</h2><button class="text-button" data-action="current-month">Today</button></div><button class="calendar-arrow" data-action="month-shift" data-direction="1" aria-label="Next month">›</button></div>
      <div class="calendar-grid">${["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"].map((day) => `<span class="calendar-weekday">${day}</span>`).join("")}${cells.join("")}</div>
      <div class="calendar-legend"><span><i class="legend-dot low"></i>Started</span><span><i class="legend-dot mid"></i>In progress</span><span><i class="legend-dot full"></i>Complete</span></div>
    </div><aside class="activity-aside"><article class="activity-stat"><p class="eyebrow">THIS MONTH</p><div class="activity-percent">${pct}<span>%</span></div><p>${Math.round(doneTotal * 10) / 10} of ${scheduledTotal} scheduled check-ins</p><div class="summary-progress"><span style="width:${pct}%"></span></div><div class="perfect-days"><span>✦</span><b>${perfectDays}</b><small>perfect day${perfectDays === 1 ? "" : "s"}</small></div></article>
      <article class="day-detail"><p class="eyebrow">${selectedDateIsToday(selected) ? "TODAY" : isFuture ? "UPCOMING" : "DAY DETAILS"}</p><h3>${new Intl.DateTimeFormat(undefined, { weekday: "long", month: "short", day: "numeric" }).format(selected)}</h3><div class="day-task-list">${dayRows}</div></article></aside></section>`;
}

function selectedDateIsToday(date) {
  return localDateKey(date) === localDateKey(new Date());
}

async function handleAuthSubmit(form) {
  const data = new FormData(form);
  const email = String(data.get("email") || "").trim();
  const password = String(data.get("password") || "");
  state.busy = true;
  state.error = "";
  render();
  try {
    if (state.authMode === "signup") {
      const name = String(data.get("name") || "").trim();
      if (!name) throw new Error("Please enter your name.");
      const credential = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(credential.user, { displayName: name });
      await setDoc(doc(db, "pigeons", credential.user.uid), {
        id: credential.user.uid,
        email,
        name,
        avatar: state.avatar,
        total_tasks_completed: 0,
        nest_id: null,
        created_at: new Date(),
        last_active_at: new Date(),
      });
    } else {
      await signInWithEmailAndPassword(auth, email, password);
    }
  } catch (error) {
    state.busy = false;
    state.error = friendlyError(error);
    render();
  }
}

function friendlyError(error) {
  const code = error?.code || "";
  const messages = {
    "auth/email-already-in-use": "An account already exists with this email. Sign in instead.",
    "auth/invalid-credential": "That email and password combination wasn't recognized.",
    "auth/invalid-email": "Enter a valid email address.",
    "auth/weak-password": "Choose a password with at least 6 characters.",
    "auth/too-many-requests": "Too many attempts. Wait a little and try again.",
    "permission-denied": "Firebase denied this action. Check the Firestore rules and your nest membership.",
    "unavailable": "Firebase is temporarily unavailable. Check your connection and try again.",
  };
  return messages[code] || error?.message || "Something went wrong. Please try again.";
}

function subscribeProfile(user) {
  clearListeners();
  profileUnsubscribe = onSnapshot(doc(db, "pigeons", user.uid), (snapshot) => {
    if (!snapshot.exists()) {
      state.profile = null;
      state.error = "Your account exists, but its profile could not be loaded. Sign out and contact your nest owner.";
      render();
      return;
    }
    state.profile = snapshot.data();
    state.error = "";
    if (!state.profile.nest_id) {
      nestUnsubscribe?.();
      tasksUnsubscribe?.();
      nestUnsubscribe = tasksUnsubscribe = null;
      state.nest = null;
      state.tasks = [];
    } else if (!state.nest || state.nest.id !== state.profile.nest_id) {
      subscribeNest(state.profile.nest_id);
    }
    render();
  }, (error) => showMessage(friendlyError(error)));
}

function subscribeNest(nestId) {
  nestUnsubscribe?.();
  tasksUnsubscribe?.();
  completionListeners.forEach((unsubscribe) => unsubscribe());
  completionListeners = new Map();
  state.tasks = [];
  state.completions = {};
  nestUnsubscribe = onSnapshot(doc(db, "nests", nestId), async (snapshot) => {
    if (!snapshot.exists()) {
      state.nest = null;
      state.error = "This nest no longer exists.";
      render();
      return;
    }
    state.nest = { id: snapshot.id, ...snapshot.data() };
    if (!tasksUnsubscribe) subscribeTasks(nestId);
    render();
  }, (error) => showMessage(friendlyError(error)));
}

function subscribeTasks(nestId) {
  const taskQuery = query(collection(db, "tasks"), where("nest_id", "==", nestId));
  tasksUnsubscribe = onSnapshot(taskQuery, (snapshot) => {
    const tasks = snapshot.docs.map((item) => ({ id: item.id, ...item.data() }));
    const currentIds = new Set(tasks.map((task) => task.id));
    completionListeners.forEach((unsubscribe, id) => {
      if (!currentIds.has(id)) {
        unsubscribe();
        completionListeners.delete(id);
        delete state.completions[id];
      }
    });
    for (const task of tasks) {
      if (completionListeners.has(task.id)) continue;
      const completionsQuery = query(collection(db, "task_completions"), where("task_id", "==", task.id));
      completionListeners.set(task.id, onSnapshot(completionsQuery, (completionSnapshot) => {
        state.completions[task.id] = Object.fromEntries(completionSnapshot.docs.map((item) => {
          const completion = item.data();
          return [`${completion.pigeon_id}_${completion.date}`, completion];
        }));
        render();
      }, (error) => showMessage(friendlyError(error))));
    }
    state.tasks = tasks;
    render();
  }, (error) => showMessage(friendlyError(error)));
}

async function createNest(form) {
  const name = String(new FormData(form).get("nestName") || "").trim();
  if (!name) return;
  state.busy = true;
  state.error = "";
  render();
  const nestId = crypto.randomUUID();
  const inviteCode = Array.from(crypto.getRandomValues(new Uint8Array(6)), (byte) => "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"[byte % 36]).join("");
  const createdAt = new Date();
  try {
    await setDoc(doc(db, "nests", nestId), {
      id: nestId,
      name,
      theme: "dark_purple",
      created_by: state.user.uid,
      pigeons: [state.user.uid],
      invite_code: inviteCode,
      invite_expires_at: new Date(createdAt.getTime() + 7 * 24 * 60 * 60 * 1000),
      created_at: createdAt,
      updated_at: createdAt,
    });
    await updateDoc(doc(db, "pigeons", state.user.uid), { nest_id: nestId });
    state.busy = false;
  } catch (error) {
    state.busy = false;
    state.error = friendlyError(error);
    render();
  }
}

async function joinNest(form) {
  const code = String(new FormData(form).get("inviteCode") || "").trim().toUpperCase();
  if (!code) return;
  state.busy = true;
  state.error = "";
  render();
  try {
    const result = await getDocs(query(collection(db, "nests"), where("invite_code", "==", code), limit(1)));
    const snapshot = result.docs[0];
    if (!snapshot) throw new Error("No nest was found for that invite code.");
    const nestRef = doc(db, "nests", snapshot.id);
    const currentNest = snapshot.data();
    if (asDate(currentNest.invite_expires_at) <= new Date()) throw new Error("This invite code has expired. Ask for a new one.");
    if (currentNest.pigeons?.includes(state.user.uid)) {
      await updateDoc(doc(db, "pigeons", state.user.uid), { nest_id: snapshot.id });
      state.busy = false;
      return;
    }
    if ((currentNest.pigeons || []).length >= 2) throw new Error("This nest is already full.");
    await runTransaction(db, async (transaction) => {
      const latest = await transaction.get(nestRef);
      if (!latest.exists()) throw new Error("This nest no longer exists.");
      const pigeons = latest.data().pigeons || [];
      if (pigeons.length >= 2) throw new Error("This nest is already full.");
      transaction.update(nestRef, { pigeons: arrayUnion(state.user.uid), updated_at: serverTimestamp() });
    });
    await updateDoc(doc(db, "pigeons", state.user.uid), { nest_id: snapshot.id });
    state.busy = false;
  } catch (error) {
    state.busy = false;
    state.error = friendlyError(error);
    render();
  }
}

async function createTask(form) {
  const values = new FormData(form);
  const name = String(values.get("name") || "").trim();
  const reward = String(values.get("reward") || "").trim();
  const threshold = Number(values.get("threshold"));
  if (!name || !reward || !Number.isInteger(threshold) || threshold < 1) {
    showMessage("Add a goal name, a reward, and a positive check-in target.");
    return;
  }
  state.busy = true;
  render();
  const id = crypto.randomUUID();
  const now = new Date();
  const checkpointId = crypto.randomUUID();
  const deservingId = crypto.randomUUID();
  const checkpoint = {
    id: checkpointId,
    task_id: id,
    order: 1,
    day_threshold: threshold,
    deserving: {
      id: deservingId,
      task_id: id,
      checkpoint_order: 1,
      title: reward,
      description: "",
      created_by: state.user.uid,
      claimed_by: [],
      created_at: now,
    },
  };
  try {
    await setDoc(doc(db, "tasks", id), {
      id,
      nest_id: state.nest.id,
      name,
      description: String(values.get("description") || "").trim(),
      task_type: values.get("taskType") === "shared" ? "shared" : "personal",
      frequency: values.get("frequency") === "weekly" ? "weekly" : "daily",
      created_by: state.user.uid,
      created_at: now,
      updated_at: now,
      checkpoints: [checkpoint],
      consecutive_days_completed: 0,
    });
    state.busy = false;
    state.modal = null;
    state.error = "";
    showMessage("Your new goal is ready. Let's begin.", "success");
  } catch (error) {
    state.busy = false;
    state.error = friendlyError(error);
    render();
  }
}

async function toggleTask(taskId) {
  const task = state.tasks.find((item) => item.id === taskId);
  if (!task || !isScheduled(task, new Date())) return;
  const complete = !ownCompletion(task);
  state.busy = true;
  render();
  const completionId = `${task.id}_${state.user.uid}_${localDateKey(new Date())}`;
  const completionRef = doc(db, "task_completions", completionId);
  const profileRef = doc(db, "pigeons", state.user.uid);
  try {
    await runTransaction(db, async (transaction) => {
      const previous = await transaction.get(completionRef);
      const wasComplete = previous.exists() && previous.data().is_complete === true;
      transaction.set(completionRef, {
        id: completionId,
        task_id: task.id,
        pigeon_id: state.user.uid,
        date: localDateKey(new Date()),
        is_complete: complete,
        created_at: previous.exists() ? previous.data().created_at : serverTimestamp(),
        updated_at: serverTimestamp(),
      });
      if (complete !== wasComplete) {
        transaction.update(profileRef, {
          total_tasks_completed: increment(complete ? 1 : -1),
          last_active_at: serverTimestamp(),
        });
      }
    });
    state.busy = false;
    state.error = "";
    showMessage(complete ? "Check-in saved. Keep that promise to yourself." : "Check-in removed.", "success");
  } catch (error) {
    state.busy = false;
    state.error = friendlyError(error);
    render();
  }
}

function render() {
  document.documentElement.dataset.theme = state.theme;
  if (!state.user) {
    root.innerHTML = renderAuth();
    return;
  }
  if (!state.profile) {
    root.innerHTML = `<div class="boot-screen"><span class="brand-mark">P</span><p>Loading your profile…</p>${state.error ? `<div class="alert error">${escapeHtml(state.error)}</div><button class="button ghost" data-action="signout">Sign out</button>` : ""}</div>`;
    return;
  }
  if (!state.profile.nest_id || !state.nest) {
    root.innerHTML = renderNestSetup();
    return;
  }
  root.innerHTML = renderApp();
}

root.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (state.busy) return;
  if (event.target.id === "auth-form") await handleAuthSubmit(event.target);
  else if (event.target.id === "create-nest-form") await createNest(event.target);
  else if (event.target.id === "join-nest-form") await joinNest(event.target);
  else if (event.target.id === "goal-form") await createTask(event.target);
});

root.addEventListener("input", (event) => {
  if (event.target.name === "inviteCode") event.target.value = event.target.value.toUpperCase().replace(/[^A-Z0-9]/g, "");
});

root.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-action]");
  if (!button) {
    if (event.target.classList.contains("modal-backdrop")) state.modal = null, render();
    return;
  }
  const action = button.dataset.action;
  if (action === "auth-mode") {
    state.authMode = button.dataset.mode;
    state.error = "";
    render();
  } else if (action === "avatar") {
    state.avatar = button.dataset.avatar;
    render();
  } else if (action === "signout") {
    await signOut(auth);
  } else if (action === "navigate") {
    state.screen = button.dataset.screen;
    state.error = "";
    render();
  } else if (action === "theme") {
    state.theme = state.theme === "dark" ? "light" : "dark";
    try {
      localStorage.setItem("ppp-theme", state.theme);
      state.error = "";
    } catch {
      state.error = "Your appearance changed, but this browser could not save the preference.";
    }
    render();
  } else if (action === "new-task") {
    state.modal = "goal";
    render();
    root.querySelector('input[name="name"]')?.focus();
  } else if (action === "close-modal") {
    state.modal = null;
    render();
  } else if (action === "toggle-task") {
    await toggleTask(button.dataset.task);
  } else if (action === "copy-code") {
    try {
      await navigator.clipboard.writeText(state.nest.invite_code);
      showMessage("Invite code copied.", "success");
    } catch {
      showMessage(`Invite code: ${state.nest.invite_code}`);
    }
  } else if (action === "filter") {
    state.filter = button.dataset.filter;
    render();
  } else if (action === "month-shift") {
    state.calendarDate = new Date(state.calendarDate.getFullYear(), state.calendarDate.getMonth() + Number(button.dataset.direction), 1);
    render();
  } else if (action === "current-month") {
    state.calendarDate = new Date();
    state.selectedDate = localDateKey(new Date());
    render();
  } else if (action === "select-date") {
    state.selectedDate = button.dataset.date;
    render();
  } else if (action === "dismiss-error") {
    state.error = "";
    render();
  }
});

async function start() {
  try {
    const { firebaseConfig } = await import("./firebase-config.js");
    if (!firebaseConfig?.apiKey || !firebaseConfig?.projectId || !firebaseConfig?.appId) {
      throw new Error("Firebase is not configured yet. Add the Firebase Web app values to Render as described in README.md.");
    }
    const app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    db = getFirestore(app);
    onAuthStateChanged(auth, (user) => {
      state.user = user;
      state.busy = false;
      state.error = "";
      if (user) subscribeProfile(user);
      else {
        clearListeners();
        state.screen = "home";
        render();
      }
    }, (error) => showMessage(friendlyError(error)));
  } catch (error) {
    root.innerHTML = `<main class="config-error"><span class="brand-mark">P</span><p class="eyebrow">ONE LAST SETUP STEP</p><h1>Connect your Firebase project</h1><p>${escapeHtml(error.message)}</p><a class="button primary" href="https://console.firebase.google.com/" target="_blank" rel="noreferrer">Open Firebase Console ↗</a><small>See the Render deployment instructions in README.md.</small></main>`;
  }
}

start();
