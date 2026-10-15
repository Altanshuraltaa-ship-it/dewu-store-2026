const $ = (selector) => document.querySelector(selector);
const state = { products: [], cart: readCart(), user: null, mode: "login", categories: [] };
const money = (value) => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(Number(value || 0));
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const safeImage = (url) => /^https:\/\/.+/i.test(String(url || "")) ? String(url) : "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80";
function readCart() { try { const v = JSON.parse(localStorage.getItem("dewu-cart") || "[]"); return Array.isArray(v) ? v.filter(x => Number.isInteger(x.id) && Number.isInteger(x.quantity) && x.quantity > 0) : []; } catch { return []; } }
function saveCart() { localStorage.setItem("dewu-cart", JSON.stringify(state.cart)); renderCart(); }
function toast(message) { const node = $("#toast"); node.textContent = message; node.classList.add("show"); clearTimeout(toast.timer); toast.timer = setTimeout(() => node.classList.remove("show"), 2600); }
async function api(url, options = {}) {
  const response = await fetch(url, { credentials: "same-origin", ...options, headers: { ...(options.body ? { "Content-Type": "application/json" } : {}), ...(options.headers || {}) } });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}
async function loadProducts() {
  const params = new URLSearchParams();
  if ($("#searchInput").value.trim()) params.set("q", $("#searchInput").value.trim());
  if ($("#categorySelect").value) params.set("category", $("#categorySelect").value);
  $("#productGrid").innerHTML = '<div class="loading">LOADING THE ROTATIONâ¦</div>';
  try {
    const data = await api(`/api/products?${params}`);
    state.products = data.products || [];
    $("#resultCount").textContent = `${state.products.length} PAIR${state.products.length === 1 ? "" : "S"}`;
    renderProducts();
  } catch (err) {
    $("#productGrid").innerHTML = `<div class="empty-state">${escapeHtml(err.message)}<br><br>Check that the server and database are running.</div>`;
  }
}
function renderProducts() {
  const grid = $("#productGrid");
  if (!state.products.length) { grid.innerHTML = '<div class="empty-state">NO PAIRS FOUND. TRY ANOTHER SEARCH.</div>'; return; }
  grid.innerHTML = state.products.map((p, index) => `
    <article class="product-card">
      <div class="product-image"><img src="${escapeHtml(safeImage(p.imageUrl))}" alt="${escapeHtml(p.name)}" loading="lazy"><span class="product-tag">${index < 2 ? "FEATURED" : escapeHtml(p.category.toUpperCase())}</span><button class="add-btn" data-add="${p.id}" aria-label="Add ${escapeHtml(p.name)} to bag" ${p.stock < 1 ? "disabled" : ""}>${p.stock < 1 ? "â" : "+"}</button></div>
      <div class="product-info"><div><h3>${escapeHtml(p.name)}</h3><div class="product-category">${escapeHtml(p.category)}</div><div class="stock-note">${p.stock > 0 ? `${p.stock} IN STOCK` : "SOLD OUT"}</div></div><div class="product-price">${money(p.price)}</div></div>
    </article>`).join("");
}
async function loadCategories() {
  try {
    const data = await api("/api/categories");
    state.categories = data.categories || [];
    $("#categorySelect").innerHTML = '<option value="">ALL CATEGORIES</option>' + state.categories.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c.toUpperCase())}</option>`).join("");
  } catch {}
}
function addToCart(id) {
  const p = state.products.find(x => Number(x.id) === Number(id));
  if (!p) return;
  const existing = state.cart.find(x => x.id === Number(id));
  if ((existing?.quantity || 0) >= Math.min(p.stock, 10)) return toast("Stock limit reached for this pair.");
  if (existing) existing.quantity++; else state.cart.push({ id: Number(id), quantity: 1 });
  saveCart(); toast(`${p.name} added to your bag.`);
}
function cartDetails() {
  return state.cart.map(item => {
    const product = state.products.find(p => Number(p.id) === item.id);
    return product ? { ...product, quantity: item.quantity } : null;
  }).filter(Boolean);
}
function renderCart() {
  const items = cartDetails();
  const count = items.reduce((n, p) => n + p.quantity, 0);
  $("#cartCount").textContent = count;
  $("#drawerCount").textContent = `(${count})`;
  $("#subtotal").textContent = money(items.reduce((n, p) => n + p.price * p.quantity, 0));
  $("#cartItems").innerHTML = items.length ? items.map(p => `
    <div class="cart-row"><img src="${escapeHtml(safeImage(p.imageUrl))}" alt=""><div><h3>${escapeHtml(p.name)}</h3><p>${money(p.price)}</p><div class="qty-controls"><button data-qty="${p.id}" data-delta="-1" aria-label="Decrease quantity">â</button><span>${p.quantity}</span><button data-qty="${p.id}" data-delta="1" aria-label="Increase quantity" ${p.quantity >= Math.min(p.stock,10) ? "disabled" : ""}>+</button></div></div><button class="remove-btn" data-remove="${p.id}" aria-label="Remove item">Ã</button></div>`).join("") : '<div class="empty-state">YOUR BAG IS WAITING FOR SOMETHING GOOD.</div>';
}
function openLayer(id) {
  $("#overlay").hidden = false;
  if (id === "cartDrawer") { $("#cartDrawer").classList.add("open"); $("#cartDrawer").setAttribute("aria-hidden", "false"); }
  else $(id).hidden = false;
  document.body.classList.add("locked");
}
function closeLayers() {
  $("#overlay").hidden = true;
  $("#cartDrawer").classList.remove("open");
  $("#cartDrawer").setAttribute("aria-hidden", "true");
  $("#accountModal").hidden = true; $("#adminModal").hidden = true;
  document.body.classList.remove("locked");
}
function setAuthMode(mode) {
  state.mode = mode;
  const registering = mode === "register";
  $("#loginTab").classList.toggle("active", !registering);
  $("#registerTab").classList.toggle("active", registering);
  $("#nameField").hidden = !registering;
  $("#authName").required = registering;
  $("#authPassword").autocomplete = registering ? "new-password" : "current-password";
  $("#authSubmit").textContent = registering ? "CREATE ACCOUNT â" : "LOG IN â";
  $("#authMessage").textContent = "";
}
async function loadMe() {
  try { const data = await api("/api/me"); state.user = data.user; } catch { state.user = null; }
  renderAccount();
}
function renderAccount() {
  const loggedIn = Boolean(state.user);
  $("#authForm").hidden = loggedIn;
  $("#accountInfo").hidden = !loggedIn;
  if (loggedIn) {
    $("#accountInfo").innerHTML = `<p>Signed in as<br><strong>${escapeHtml(state.user.name)}</strong><br>${escapeHtml(state.user.email)}</p><button class="button button-outline full-width" id="ordersBtn">MY ORDERS</button>${state.user.role === "admin" ? '<button class="button button-light full-width" id="adminOpenBtn">OPEN ADMIN PANEL â</button>' : ""}<button class="button button-outline full-width" id="logoutBtn">LOG OUT</button>`;
  }
}
async function openAccount() {
  setAuthMode("login");
  await loadMe();
  openLayer("accountModal");
}
async function submitAuth(event) {
  event.preventDefault();
  $("#authMessage").textContent = "PLEASE WAITâ¦";
  const payload = { email: $("#authEmail").value, password: $("#authPassword").value };
  if (state.mode === "register") payload.name = $("#authName").value;
  try {
    const data = await api(`/api/auth/${state.mode === "register" ? "register" : "login"}`, { method: "POST", body: JSON.stringify(payload) });
    state.user = data.user; renderAccount(); toast(state.mode === "register" ? "Account created." : "Welcome back.");
  } catch (err) { $("#authMessage").textContent = err.message; }
}
async function checkout() {
  $("#checkoutMessage").textContent = "";
  if (!state.cart.length) return $("#checkoutMessage").textContent = "Your bag is empty.";
  if (!state.user) { closeLayers(); await openAccount(); $("#authMessage").textContent = "Log in or create an account before checkout."; return; }
  $("#checkoutBtn").disabled = true; $("#checkoutBtn").textContent = "CONNECTING TO CHECKOUTâ¦";
  try {
    const data = await api("/api/checkout", { method: "POST", body: JSON.stringify({ items: state.cart }) });
    if (!data.url || !data.url.startsWith("https://")) throw new Error("Invalid checkout URL.");
    window.location.assign(data.url);
  } catch (err) { $("#checkoutMessage").textContent = err.message; }
  finally { $("#checkoutBtn").disabled = false; $("#checkoutBtn").textContent = "SECURE CHECKOUT â"; }
}
function resetProductForm() {
  $("#productForm").reset(); $("#productId").value = ""; $("#productCategory").value = "Lifestyle"; $("#saveProductBtn").textContent = "ADD PRODUCT"; $("#adminMessage").textContent = "";
}
async function loadAdminProducts() {
  try {
    const data = await api("/api/admin/products");
    $("#adminList").innerHTML = data.products.length ? data.products.map(p => `<div class="admin-item"><div><strong>${escapeHtml(p.name)}</strong><p>${money(p.price)} Â· Stock ${p.stock} Â· ${p.active ? "Active" : "Hidden"}</p></div><div class="admin-item-actions"><button class="small-action" data-edit="${p.id}">EDIT</button><button class="small-action" data-delete="${p.id}">HIDE</button></div></div>`).join("") : '<p class="muted">No products yet.</p>';
  } catch (err) { $("#adminList").textContent = err.message; }
}
async function openAdmin() {
  if (!state.user || state.user.role !== "admin") return toast("Admin access required.");
  openLayer("adminModal"); await Promise.all([loadAdminProducts(), loadOrders()]);
}
async function saveProduct(event) {
  event.preventDefault();
  const id = $("#productId").value;
  const payload = { name: $("#productName").value, description: $("#productDescription").value, price: Number($("#productPrice").value), stock: Number($("#productStock").value), category: $("#productCategory").value, imageUrl: $("#productImage").value };
  $("#adminMessage").textContent = "SAVINGâ¦";
  try {
    await api(id ? `/api/admin/products/${id}` : "/api/admin/products", { method: id ? "PUT" : "POST", body: JSON.stringify(payload) });
    resetProductForm(); $("#adminMessage").textContent = "Product saved.";
    await Promise.all([loadAdminProducts(), loadProducts(), loadCategories()]);
  } catch (err) { $("#adminMessage").textContent = err.message; }
}
async function loadOrders() {
  try {
    const data = await api("/api/orders");
    $("#ordersList").innerHTML = data.orders.length ? data.orders.map(o => `<div class="order-card"><strong>ORDER #${o.id}</strong> â ${money(o.total)} <span>(${escapeHtml(o.status)})</span><br><span>${escapeHtml(o.customer_email || "")} Â· ${new Date(o.created_at).toLocaleString()}</span></div>`).join("") : '<p class="muted">No orders yet.</p>';
  } catch (err) { $("#ordersList").textContent = err.message; }
}
async function handleClick(event) {
  const target = event.target.closest("button");
  if (!target) return;
  if (target.hasAttribute("data-add")) addToCart(Number(target.dataset.add));
  if (target.hasAttribute("data-qty")) {
    const item = state.cart.find(x => x.id === Number(target.dataset.qty));
    if (item) { item.quantity += Number(target.dataset.delta); if (item.quantity <= 0) state.cart = state.cart.filter(x => x !== item); saveCart(); }
  }
  if (target.hasAttribute("data-remove")) { state.cart = state.cart.filter(x => x.id !== Number(target.dataset.remove)); saveCart(); }
  if (target.hasAttribute("data-close") || target.id === "overlay") closeLayers();
  if (target.id === "cartBtn") { renderCart(); openLayer("cartDrawer"); }
  if (target.id === "accountBtn") await openAccount();
  if (target.id === "loginTab") setAuthMode("login");
  if (target.id === "registerTab") setAuthMode("register");
  if (target.id === "checkoutBtn") await checkout();
  if (target.id === "adminOpenBtn") await openAdmin();
  if (target.id === "logoutBtn") {
    try { await api("/api/auth/logout", { method: "POST" }); state.user = null; renderAccount(); closeLayers(); toast("Logged out."); }
    catch (err) { toast(err.message); }
  }
  if (target.id === "ordersBtn") {
    try { const data = await api("/api/orders"); $("#accountInfo").insertAdjacentHTML("beforeend", `<div class="order-card"><strong>YOUR ORDERS</strong>${data.orders.map(o => `<p>#${o.id} â ${money(o.total)} Â· ${escapeHtml(o.status)}</p>`).join("") || "<p>No orders yet.</p>"}</div>`); target.disabled = true; }
    catch (err) { toast(err.message); }
  }
  if (target.id === "refreshAdminBtn") await loadAdminProducts();
  if (target.id === "refreshOrdersBtn") await loadOrders();
  if (target.id === "resetProductBtn") resetProductForm();
  if (target.hasAttribute("data-edit")) {
    try {
      const data = await api("/api/admin/products");
      const p = data.products.find(x => Number(x.id) === Number(target.dataset.edit)); if (!p) return;
      $("#productId").value = p.id; $("#productName").value = p.name; $("#productDescription").value = p.description; $("#productPrice").value = p.price; $("#productStock").value = p.stock; $("#productCategory").value = p.category; $("#productImage").value = p.imageUrl; $("#saveProductBtn").textContent = "SAVE CHANGES"; $("#adminMessage").textContent = "Editing " + p.name; $("#productName").focus();
    } catch (err) { toast(err.message); }
  }
  if (target.hasAttribute("data-delete")) {
    if (!confirm("Hide this product from the storefront?")) return;
    try { await api(`/api/admin/products/${target.dataset.delete}`, { method: "DELETE" }); await Promise.all([loadAdminProducts(), loadProducts(), loadCategories()]); toast("Product hidden."); }
    catch (err) { toast(err.message); }
  }
}
document.addEventListener("click", handleClick);
$("#overlay").addEventListener("click", closeLayers);
$("#authForm").addEventListener("submit", submitAuth);
$("#productForm").addEventListener("submit", saveProduct);
$("#searchInput").addEventListener("input", () => { clearTimeout(loadProducts.timer); loadProducts.timer = setTimeout(loadProducts, 220); });
$("#categorySelect").addEventListener("change", loadProducts);
document.addEventListener("keydown", event => { if (event.key === "Escape") closeLayers(); });
$("#year").textContent = new Date().getFullYear();

(async function init() {
  const params = new URLSearchParams(location.search);
  if (params.get("checkout") === "success") {
    state.cart = []; saveCart();
    toast("Checkout returned successfully. Payment confirmation may take a moment.");
    history.replaceState({}, "", "/");
  } else if (params.get("checkout") === "cancelled") {
    toast("Checkout cancelled. Your bag is still here.");
    history.replaceState({}, "", "/");
  }
  await Promise.all([loadProducts(), loadCategories(), loadMe()]);
  renderCart();
})();
