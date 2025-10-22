const BADGE_CATALOG = [
  {
    name: "Citizenship in the Community",
    focus: "Service project planning, community interviews, and civic participation.",
    length: "4-6 weeks",
    category: "Civic Engagement",
  },
  {
    name: "Citizenship in the Nation",
    focus: "National history, constitutional principles, and communicating with elected officials.",
    length: "3-5 weeks",
    category: "Civic Engagement",
  },
  {
    name: "Citizenship in the World",
    focus: "Global awareness, international organizations, and cultural appreciation activities.",
    length: "4-6 weeks",
    category: "Global Citizenship",
  },
  {
    name: "Family Life",
    focus: "Family meetings, responsibilities, and goal planning with trusted adults.",
    length: "3 months",
    category: "Personal Growth",
  },
  {
    name: "Personal Fitness",
    focus: "Health assessments, exercise plans, and wellness reflections.",
    length: "3 months",
    category: "Wellness",
  },
  {
    name: "Personal Management",
    focus: "Budget tracking, time management, and savings goals.",
    length: "3 months",
    category: "Life Skills",
  },
];

const STORAGE_KEY = "thunderbirdScout";

const currencyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const paceLabels = {
  weekly: "Weekly check-ins",
  biweekly: "Every other week",
  monthly: "Monthly",
};

function updateYear() {
  document.querySelectorAll("[data-year]").forEach((node) => {
    node.textContent = new Date().getFullYear();
  });
}

function renderBadgeSelect(container) {
  if (!container) return;
  BADGE_CATALOG.forEach((badge, index) => {
    const id = `badge-${index}`;
    const label = document.createElement("label");
    const checkbox = document.createElement("input");
    const details = document.createElement("div");
    const title = document.createElement("strong");
    const focus = document.createElement("span");

    checkbox.type = "checkbox";
    checkbox.id = id;
    checkbox.name = "badges";
    checkbox.value = badge.name;

    title.textContent = badge.name;
    focus.textContent = badge.focus;
    focus.className = "badge-select__focus";

    label.htmlFor = id;
    details.appendChild(title);
    details.appendChild(document.createElement("br"));
    details.appendChild(focus);

    label.append(checkbox, details);
    container.appendChild(label);
  });
}

function renderBadgeGrid(container) {
  if (!container) return;
  BADGE_CATALOG.forEach((badge) => {
    const card = document.createElement("article");
    card.className = "badge-card";

    const title = document.createElement("h3");
    title.textContent = badge.name;

    const tag = document.createElement("span");
    tag.className = "badge-card__tag";
    tag.textContent = badge.category;

    const focus = document.createElement("p");
    focus.textContent = badge.focus;

    const length = document.createElement("p");
    length.innerHTML = `<strong>Typical duration:</strong> ${badge.length}`;

    card.append(title, tag, focus, length);
    container.appendChild(card);
  });
}

function loadScoutProfile() {
  const stored = window.localStorage?.getItem(STORAGE_KEY);
  if (!stored) return null;
  try {
    return JSON.parse(stored);
  } catch (error) {
    console.error("Unable to parse stored scout profile", error);
    return null;
  }
}

function saveScoutProfile(profile) {
  try {
    window.localStorage?.setItem(STORAGE_KEY, JSON.stringify(profile));
  } catch (error) {
    console.error("Unable to save scout profile", error);
  }
}

function handleLoginForm(form) {
  if (!form) return;
  renderBadgeSelect(form.querySelector("[data-badge-list]"));

  form.addEventListener("submit", (event) => {
    event.preventDefault();

    const formData = new FormData(form);
    const name = formData.get("scoutName")?.toString().trim();
    const troop = formData.get("troop")?.toString().trim();
    const parentEmail = formData.get("parentEmail")?.toString().trim();
    const contactPhone = formData.get("contactPhone")?.toString().trim();
    const pace = formData.get("pace")?.toString();
    const selectedBadges = formData.getAll("badges").map((badge) => badge.toString());

    if (!name || !troop || !parentEmail) {
      form.reportValidity();
      return;
    }

    const profile = {
      name,
      troop,
      parentEmail,
      contactPhone,
      pace: pace || "weekly",
      createdAt: new Date().toISOString(),
      badges: selectedBadges.map((badgeName) => ({
        name: badgeName,
        progress: badgeName.includes("Citizenship") ? 40 : 10,
        status: "In Progress",
      })),
    };

    if (profile.badges.length === 0) {
      profile.badges.push({
        name: BADGE_CATALOG[0].name,
        progress: 10,
        status: "In Progress",
      });
    }

    saveScoutProfile(profile);
    window.location.href = "./dashboard.html";
  });
}

function createBadgeProgressElement(badge, index, totalBadges) {
  const container = document.createElement("article");
  container.className = "badge-progress";
  container.dataset.badgeIndex = index.toString();

  const header = document.createElement("div");
  header.className = "badge-progress__header";

  const title = document.createElement("h4");
  title.textContent = badge.name;

  const progressLabel = document.createElement("span");
  progressLabel.textContent = `${Math.round(badge.progress)}%`;

  const progress = document.createElement("div");
  progress.className = "progress";

  const bar = document.createElement("div");
  bar.className = "progress__bar";
  bar.style.width = `${Math.min(100, badge.progress)}%`;
  bar.setAttribute("aria-hidden", "true");

  progress.appendChild(bar);

  header.append(title, progressLabel);

  const actions = document.createElement("div");
  actions.className = "badge-progress__actions";

  const advanceButton = document.createElement("button");
  advanceButton.type = "button";
  advanceButton.className = "button button--ghost";
  advanceButton.textContent = "Log Progress (+10%)";
  advanceButton.addEventListener("click", () => updateBadgeProgress(index, 10));

  const completeButton = document.createElement("button");
  completeButton.type = "button";
  completeButton.className = "button";
  completeButton.textContent = "Mark Complete";
  completeButton.addEventListener("click", () => updateBadgeProgress(index, 100));

  const removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.className = "button button--ghost";
  removeButton.dataset.action = "remove";
  removeButton.dataset.index = index.toString();
  removeButton.textContent = "Remove Badge";
  removeButton.addEventListener("click", () => removeBadge(index));

  actions.append(advanceButton, completeButton, removeButton);

  if (badge.progress >= 100) {
    const status = document.createElement("span");
    status.className = "badge-card__tag";
    status.textContent = "Complete";
    actions.appendChild(status);
    advanceButton.disabled = true;
    completeButton.disabled = true;
    container.classList.add("badge-progress--complete");
  }

  container.append(header, progress, actions);
  container.dataset.badgeCount = totalBadges.toString();
  return container;
}

function renderDashboard(profile) {
  const emptyState = document.querySelector("[data-dashboard-empty]");
  const content = document.querySelector("[data-dashboard-content]");
  if (!emptyState || !content) return;

  if (!profile) {
    emptyState.hidden = false;
    content.hidden = true;
    return;
  }

  emptyState.hidden = true;
  content.hidden = false;

  const nameField = document.querySelector("[data-scout-name]");
  const troopField = document.querySelector("[data-scout-troop]");
  const paceField = document.querySelector("[data-scout-pace]");

  if (nameField) nameField.textContent = profile.name;
  if (troopField) troopField.textContent = profile.troop;
  if (paceField) paceField.textContent = paceLabels[profile.pace] || "Custom";

  let badges = [];
  if (Array.isArray(profile.badges)) {
    badges = profile.badges;
  } else {
    profile.badges = [];
    badges = profile.badges;
  }

  const badgeContainer = document.querySelector("[data-badge-progress]");
  if (badgeContainer) {
    badgeContainer.innerHTML = "";
    badges.forEach((badge, index) => {
      badgeContainer.appendChild(createBadgeProgressElement(badge, index, badges.length));
    });
  }

  const addBadgeSelect = document.querySelector("[data-add-badge-form] select");
  if (addBadgeSelect) {
    addBadgeSelect.innerHTML = "";
    const unselectedBadges = BADGE_CATALOG.filter(
      (badge) => !badges.some((item) => item.name === badge.name)
    );
    unselectedBadges.forEach((badge) => {
      const option = document.createElement("option");
      option.value = badge.name;
      option.textContent = badge.name;
      addBadgeSelect.appendChild(option);
    });
    if (!addBadgeSelect.options.length) {
      const option = document.createElement("option");
      option.textContent = "All Eagle-required badges added";
      option.disabled = true;
      addBadgeSelect.appendChild(option);
    }
  }

  updateNextAction(profile);
}

function updateBadgeProgress(index, delta) {
  const profile = loadScoutProfile();
  if (!profile) return;
  if (!Array.isArray(profile.badges)) {
    profile.badges = [];
  }
  const badge = profile.badges[index];
  if (!badge) return;

  if (delta >= 100) {
    badge.progress = 100;
    badge.status = "Complete";
  } else {
    badge.progress = Math.min(100, badge.progress + delta);
    badge.status = badge.progress >= 100 ? "Complete" : "In Progress";
  }

  saveScoutProfile(profile);
  renderDashboard(profile);
}

function updateNextAction(profile) {
  const recommendation = document.querySelector("[data-next-action]");
  if (!recommendation) return;

  const badges = Array.isArray(profile.badges) ? profile.badges : [];

  if (!badges.length) {
    recommendation.textContent = "Add your first badge to unlock personalized guidance.";
    return;
  }

  const inProgress = badges.find((badge) => badge.progress < 100);
  if (!inProgress) {
    recommendation.textContent = "All selected badges are complete! Download your blue card summary and notify your Scoutmaster.";
    return;
  }

  if (inProgress.name.includes("Citizenship")) {
    recommendation.textContent = `Schedule an interview with a community leader for ${inProgress.name}. Use the AI guide to prep your questions.`;
  } else if (inProgress.name === "Personal Fitness") {
    recommendation.textContent = "Log this week's fitness test results and reflect on improvements with the AI coach.";
  } else if (inProgress.name === "Personal Management") {
    recommendation.textContent = "Upload your latest budget tracker and ask the AI mentor to review savings goals.";
  } else {
    recommendation.textContent = `Review your notes for ${inProgress.name} and record a reflection before your next check-in.`;
  }
}

function handleAddBadgeForm() {
  const form = document.querySelector("[data-add-badge-form]");
  if (!form) return;

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const select = form.querySelector("select");
    if (!select || !select.value) return;

    const profile = loadScoutProfile();
    if (!profile) return;
    if (!Array.isArray(profile.badges)) {
      profile.badges = [];
    }

    const alreadyAdded = profile.badges.some((badge) => badge.name === select.value);
    if (alreadyAdded) return;

    profile.badges.push({ name: select.value, progress: 0, status: "Not Started" });
    saveScoutProfile(profile);
    renderDashboard(profile);
    form.reset();
  });
}

function handleSummaryDownload() {
  const button = document.querySelector("[data-download-summary]");
  if (!button) return;

  button.addEventListener("click", () => {
    const profile = loadScoutProfile();
    if (!profile) return;
    const badges = Array.isArray(profile.badges) ? profile.badges : [];

    const lines = [
      `Scout: ${profile.name} (Troop ${profile.troop})`,
      `Parent/Guardian: ${profile.parentEmail}`,
      "",
      "Badge Progress:",
      ...badges.map((badge) => ` - ${badge.name}: ${Math.round(badge.progress)}% (${badge.status})`),
      "",
      "Generated by Thunderbird Merit Badges",
    ];

    const blob = new Blob([lines.join("\n")], { type: "text/plain" });
    const url = URL.createObjectURL(blob);

    const link = document.createElement("a");
    link.href = url;
    link.download = `${profile.name.replace(/\s+/g, "_")}_badge_summary.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  });
}

function handlePaymentForm(form) {
  if (!form) return;

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const summary = document.querySelector("[data-payment-summary]");
    if (!summary) return;

    const formData = new FormData(form);
    const contactName = formData.get("contactName")?.toString().trim();
    const email = formData.get("email")?.toString().trim();
    const badgeCount = Number.parseInt(formData.get("badgeCount"), 10) || 0;
    const discountCode = formData.get("discountCode")?.toString().trim().toUpperCase();

    if (!contactName || !email || badgeCount <= 0) {
      form.reportValidity();
      return;
    }

    const pricing = calculatePricing(badgeCount, discountCode);

    summary.innerHTML = `
      <h3>Payment summary</h3>
      <p><strong>Total due:</strong> ${currencyFormatter.format(pricing.total)}</p>
      <p>
        We'll send a secure Stripe checkout link to <strong>${email}</strong> with
        the details below within a few minutes.
      </p>
      <ul>
        <li>Contact: ${contactName}</li>
        <li>Badges requested: ${badgeCount}</li>
        <li>Discounts applied: ${pricing.notes.join(", ") || "None"}</li>
      </ul>
    `;
  });
}

function calculatePricing(badgeCount, discountCode) {
  let total = badgeCount * 20;
  const notes = [];

  if (badgeCount >= 5) {
    const bundleTotal = Math.round(badgeCount * 20 * 0.85 * 100) / 100;
    notes.push("Troop bundle (15% off)");
    total = bundleTotal;
  }

  if (discountCode === "URBAN20") {
    total = Math.round(total * 0.8 * 100) / 100;
    notes.push("Urban troop scholarship (20% off)");
  } else if (discountCode === "EAGLEDUO") {
    total = Math.round(total * 0.9 * 100) / 100;
    notes.push("Eagle Duo 10% savings");
  }

  return { total, notes };
}

function initPage() {
  updateYear();
  handleLoginForm(document.querySelector("[data-login-form]"));
  renderBadgeGrid(document.querySelector("[data-badge-grid]"));
  const profile = loadScoutProfile();
  renderDashboard(profile);
  handleAddBadgeForm();
  handleSummaryDownload();
  handlePaymentForm(document.querySelector("[data-payment-form]"));

}

function removeBadge(index) {
  const profile = loadScoutProfile();
  if (!profile) return;
  if (!Array.isArray(profile.badges)) {
    profile.badges = [];
  }
  profile.badges.splice(index, 1);
  saveScoutProfile(profile);
  renderDashboard(profile);
}

document.addEventListener("DOMContentLoaded", initPage);
