# Styleya Customer App: Backend API Context

Context for anyone building or maintaining the **Styleya customer mobile app** (Flutter, MStore/FluxStore style) against **https://styleya.net**. Written for app developers and AI coding agents. Every endpoint listed under *Endpoints* was verified live on **2026-10-13** (screenshots in `docs/styleya-api-evidence/`, numbered `#01`–`#17`).

The full reference for each custom endpoint (every field, every error, the server-side code) is in `docs/MOBILE_API_CUSTOMIZATIONS.md`. This file is the app-facing summary for Styleya specifically.

> Both of those paths are in the **backend** repository, not this app repository.

---

## Backend at a glance

- **Platform:** Magento Open Source 2.4.8-p5 with the CedCommerce multi-vendor marketplace. Products belong to marketplace sellers ("vendors").
- **Host:** always call `https://styleya.net`. `vendors.magento2.click` is the same backend, but it redirects storefront pages to styleya.net, so don't hard-code it.
- **Varnish** sits in front. REST responses are not cached, so no cache-busting is needed for API calls.
- **Media:** `https://styleya.net/media/...` (product images under `/media/catalog/product/...`).

### Store views

Use the URL prefix form `https://styleya.net/<prefix>/rest/V1/...` or the store-code form `https://styleya.net/rest/<code>/V1/...`. Both select the same store view.

| Market | Arabic: prefix / code | English: prefix / code | Currency | Default view |
|---|---|---|---|---|
| Egypt | `eg-ar` / `eg_ar` (id 3) | `eg-en` / `eg_en` (id 7) | EGP | English |
| Kuwait | `kw` / `kw_ar` (4) | `kw-en` / `kw_en` (8) | KWD | Arabic |
| Qatar | `qr` / `qr_ar` (5) | `qr-en` / `qr_en` (9) | QAR | Arabic |
| UAE | `uae` / `uae_ar` (6) | `uae-en` / `uae_en` (10) | AED | Arabic |
| Global | `global` / `global_ar` (11) | `global-en` / `global_en` (12) | USD | Arabic |
| Main | `ar` / `ar` (2) | `en` / `en` (1) | EGP | Arabic |

Calls without a store prefix (`/rest/V1/...`, `/graphql`) use the default store. On Styleya that's **English** for Egypt, while Locafy defaults to Arabic. Send an explicit prefix, or a `Store` header for GraphQL.

---

## Authentication

| Endpoint auth | What the app sends | Where it comes from |
|---|---|---|
| anonymous | nothing | — |
| customer (`self`) | `Authorization: Bearer <customer token>` | `POST /V1/integration/customer/token` with `{"username": "<email>", "password": "..."}` |
| catalog (admin ACL) | `Authorization: Bearer <integration token>` | Built into the app config, see below |
| MageNative (`magenative_oauth`) | header `hashkey: <key>` | Returned by MageNative login; only needed for the MageNative wishlist |

**Integration token (catalog calls).**
- Integration **"Mobile App (catalog read)"** (id 3), created 2026-10-13.
- Copy the token from Admin → System → Extensions → Integrations → *Mobile App (catalog read)* → Edit → Integration Details → **Access Token**, and put it in the app or its remote config. It is **not** the Locafy token. Tokens are per database, and each environment has its own.
- It can read: products, categories, product attributes and store views.
- It is refused (401, by design): orders, customers, configuration (`#16`, `#17`).
- The server accepts integration tokens as Bearer (`oauth/consumer/enable_integration_as_bearer = 1`).

**Customer token.**
- Lives **24 hours** (`webapi/jwtauth/customer_expiration = 1440`).
- On a `401` from any `self` endpoint, log the customer in again (or refresh silently) instead of showing an error.

---

## Endpoints

✅ = verified live 2026-10-13 (evidence number in brackets). "—" = part of core Magento / unchanged, not re-tested here.

### Home and content
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/{prefix}/rest/V1/mstore/homepage-sections` | anonymous | ✅ (#01) Sections keyed `brands`, `banner`, `category`. See *Styleya-specific behavior*. |
| GET | `/{prefix}/rest/V1/mstore/shopbrands` | anonymous | ✅ (#03) Brand tiles (Magiccart shop brands). |
| GET | `/rest/{code}/V1/mobiconnect/review/ratingoption` | anonymous | ✅ (#06) Rating ids/options for the review form. |

### Catalog (integration token)
| Method | Path | Notes |
|---|---|---|
| GET | `/{prefix}/rest/V1/mstore/products?searchCriteria[...]` | ✅ (#08) List/search. Filter `category_id` (single or comma list), sort by `created_at`, `price`, `name`, or `position` with one category. `q=` switches to full-text search. `brand=<option_id>` filters by brand. **Always send `pageSize`**: without it every matching product is returned. Configurables include `extension_attributes.swatches` and `minimal_regular_price` (strike-through price) ✅ (#08b). |
| GET | `/{prefix}/rest/V1/mstore/categories` | ✅ (#09) Category tree with sections and featured brands. |
| GET | `/{prefix}/rest/V1/mstore/brands` | ✅ (#10) |
| GET | `/{prefix}/rest/V1/mstore/filters/{categoryId}` | ✅ (#11) Layered-nav filters scoped to the category; top-level categories return `cat`, `brand`, `all_color`, `price`. |
| GET | `/{prefix}/rest/V1/mstore/sections/{categoryId}` | — Category landing sections. |
| GET | `/{prefix}/rest/V1/categories/{id}` | ✅ (#14) |
| GET | `/{prefix}/rest/V1/products/attributes/all_color` | ✅ (#12b) The colour attribute. **There is no `color` attribute** (see *Known app-side issues*). |
| GET | `/{prefix}/rest/V1/products/attributes/brand/options` | ✅ (#13) |
| GET | `/{prefix}/rest/V1/store/storeViews` | ✅ (#07) |
| GET | `/{prefix}/rest/V1/configurable-products/{sku}/options/list` | ✅ (#15) Each value now carries **`attribute_id`**. Use it in `configurable_item_options` when adding to cart, or the server answers "You need to choose options for your item." |

### Search
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/{prefix}/rest/V1/search?searchCriteria[...]` | anonymous | — core |
| GET | `/{prefix}/mageworx_searchsuiteautocomplete/ajax/index/?q=...` | anonymous | — storefront AJAX used for suggestions |

### Reviews
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/{prefix}/rest/V1/products/{sku}/reviews` | anonymous | ✅ (#04) Approved reviews with images. |
| POST | `/{prefix}/rest/V1/products/{sku}/reviews` | customer | Body `{"review": {"nickname", "summary", "text", "ratings": [{"rating_id", "value_id"}], "images": ["data:image/jpeg;base64,..."]}}`. Max 6 images, 5 MB each. Created as **pending** (moderated). |
| GET | `/{prefix}/rest/V1/customers/me/reviews` | customer | The customer's own reviews. |

### Account and login
| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/{prefix}/rest/V1/mstore/phone/is-registered` | anonymous | ✅ (#02) Body `{"phone": "+201001234567"}` → `true`/`false`. Use it before sign-up. |
| POST | `/{prefix}/rest/V1/customers` | anonymous | — Register. A phone already used by another account is rejected. |
| POST | `/{prefix}/rest/V1/integration/customer/token` | anonymous | — Login → customer token |
| GET/PUT | `/{prefix}/rest/V1/customers/me` | customer | — PUT **replaces** the whole customer, so always send the full object you received (see *Validation rules*). |
| PUT | `/{prefix}/rest/V1/customers/password` | anonymous | — Reset password |
| POST | `/{prefix}/rest/V1/mstore/customers/me/changePassword`, `.../changeEmail` | customer | — |

### Addresses and locations
| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/rest/{code}/V1/city?country=EG` | anonymous | ✅ (#05) Governorates with `region_id` + `region_name`. |
| GET | `/rest/{code}/V1/zone?city=<governorate entity_id or name>` | anonymous | — Districts, each with `region_id`. |
| PUT / GET / DELETE | `/{prefix}/rest/V1/mstore/customers/me/address[/{id}]`, `.../address/search` | customer | — Address book |
| GET | `/{prefix}/rest/V1/directory/countries`, `/rest/V1/directory/currency` | anonymous | — |

### Cart and checkout (core)
| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/{prefix}/rest/V1/carts/mine` / `guest-carts` | customer / anonymous | — Create cart |
| GET / POST | `/{prefix}/rest/V1/carts/mine/items` | customer | — Items carry extra `extension_attributes` (see *Styleya-specific behavior*). |
| POST | `/{prefix}/rest/V1/carts/mine/estimate-shipping-methods` | customer | — Send `region_id` (from `/V1/city`) in the address. |
| POST | `/{prefix}/rest/V1/carts/mine/shipping-information`, `/payment-information` | customer | — |
| PUT | `/{prefix}/rest/V1/guest-carts/{cartId}/order` | anonymous | — Guest checkout |

**Product file uploads are refused.** A custom-option `file_info` upload is rejected unless the option really is a file option and the file is an image (server-side PolyShell protection). Styleya currently has no file options, so the app should never send `file_info`.

### Orders (customer token)
| Method | Path | Notes |
|---|---|---|
| GET | `/{prefix}/rest/V1/mstore/me/orders` | — The customer's orders. **Use this, not `/V1/orders`.** |
| GET | `/{prefix}/rest/V1/mstore/me/orders/{id}` | — |
| POST | `/{prefix}/rest/V1/mstore/me/orders/{id}/cancel`, `/mstore/me/orders/reorder/{id}` | — |
| GET | `/{prefix}/rest/V1/mstore/me/invoices/{orderId}`, `/shipments/{orderId}`, `/creditmemos/{orderId}`, `/order/addresses/{orderId}`, `/order/payment/{orderId}` | — Only the order's owner gets data; anyone else gets an error (fixed 2026-10-13). |

### Wishlist (MageNative)
| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/{prefix}/rest/V1/mobiconnect/wishlist/getwishlist` | `hashkey` header | — Body `{"parameters": {"customer_id": <id>, "store_id": <id>, "currency_code": "EGP"}}`. The `customer_id` must belong to the `hashkey`, or the server answers 401. |

---

## Styleya-specific behavior (differs from Locafy)

- **Homepage brands are marketplace sellers.**
  - `brands[].id` is the Ced vendor id, and `brands[].shop_url` is the seller's shop page (`/vendor_shop/...`), not a `/shopbrand/` page.
  - The 8 featured sellers are configured in admin (Stores → Configuration → MagentoEgypt → Homepage Sections → section 10).
- **Homepage images are missing.** The 10 sections use the same layout and texts as Locafy, but their `image_url` files don't exist on the server yet, so banners show broken images until someone uploads them in admin.
- **Cart rows** (`GET /V1/carts/mine/items`):
  - `extension_attributes.entity_id` is the **parent** configurable's id, so open that page when the row is tapped. The SKU, images and prices still describe the chosen variant.
  - `extension_attributes.product_options` lists each chosen option once, plus a `{"label": "Vendor", "value": "<shop name>"}` row for marketplace items.
- **Governorates are English** on Styleya (Locafy's are Arabic). Always send the `region_id` returned by `/V1/city`, not just the name, so shipping rates resolve.
- **Shop brands:** Styleya has its own 3 entries, not Locafy's 9. One of them (AMARI) points at brand option 902, which doesn't exist, so its product filter returns nothing. That's a content fix in admin.
- **Not available on Styleya:**
  - **Returns (RMA):** `/V1/customers/me/return-policy`, `/returnable-orders`, `/returns*` return 404, so hide the returns UI. The marketplace's own returns module is a separate decision.

---

## Validation rules the app must respect

- **Phone numbers:**
  - Send one canonical form, **E.164 with `+`** (`+201001234567`).
  - The uniqueness check treats `+201…`, `00201…` and `201…` as the same number, but a local `01…` as a different one.
  - Arabic-Indic digits are converted on the server.
- **Address telephone** must be a valid **mobile** number for the address country, either in local form or with the country code:

  | Country | Example |
  |---|---|
  | EG | `01012345678` |
  | SA | `0512345678` |
  | AE | `0501234567` |
  | KW | `50123456` |
  | QA | `33123456` |
  | BH | `36123456` |
  | OM | `92123456` |
  | IN | `9876543210` |

  Otherwise you get HTTP 400: *"Please enter a valid mobile number for Egypt (for example 01012345678)."* The check runs on address save, shipping-information and place order.
- **City names** may contain letters, digits, spaces and `- ' . , ( ) /` ("6 October", "New Cairo 5").
- **Profile updates:** `PUT /V1/customers/me` replaces the whole record.
  - The server protects against stale name reverts, and restores omitted `dob`/`gender`/`taxvat`/`prefix`/`middlename`/`suffix`.
  - Still send the complete, freshly fetched object, and never a cached copy from an earlier session.

---

## Known app-side issues to fix

1. **`GET /V1/products/attributes/color` returns 404** on Styleya and Locafy alike (#12). The colour attribute is `all_color` (#12b).
2. **`GET /V1/orders`** is an admin endpoint and is refused for the app token (#16). Use `GET /V1/mstore/me/orders` with the customer token.
3. **Customer token expiry:** the logs show `carts/mine/items` going from 200 to 401 within an hour. Handle 401 by re-authenticating. Tokens now last 24 h.
4. **GraphQL `products(filter: {category_id})`** has been called with a *brand* option id (893, "Junior") as the category, which causes a search error. Brands go through `brand=` on `/V1/mstore/products`.
5. **Don't use these endpoints.** They can't verify who is calling:
   - `POST /V1/mobiconnect/sociallogin/create` doesn't verify Google/Facebook/Apple tokens.
   - `GET /wapplogin/customer/login` and `/wapplogin/customer/forgotPassword` work from a phone number alone.
   - The MageNative checkout routes (`/V1/mobiconnect/checkout/*`) need a matching `hashkey` whenever `customer_id` is sent. Use the core cart API instead.

---

## Change log

- **2026-10-13: Locafy's mobile-API customizations ported to Styleya.**
  - Modules added: shop brands, category filters, configurable prices, phone uniqueness, address phone/city validation, region mapping, profile-overwrite protection, newer review API.
  - Modules enabled: homepage sections, product swatches.
  - Fixes merged: cart-item fixes and the `attribute_id` fix.
  - Login response no longer returns password hashes.
  - New least-privilege integration token; 24-hour customer tokens.
- **2026-10-13: security fixes.**
  - Order-data ownership check.
  - MageNative key tied to its customer.
  - Magecomp write routes locked to admin.
  - Master password disabled.
  - Anonymous order dump removed.
  - PolyShell upload protection.
- **Backups:** `~/vendors-backups/20261013-api-port/` (full database dump + replaced code).
