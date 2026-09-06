# Architecture

What is here, and why it is the way it is. Everything below is a decision the
next app inherits rather than re-argues.

## How a new app starts

A repository that is cloned and renamed, not a generator script that builds an
app from nothing. Three reasons. Edge Rails moves, and a script that patches
generated files breaks silently whenever the generator's output shifts,
whereas a repository fails loudly in `bin/ci`. A repository can be diffed
against the apps it came from and every app that comes after it; a script
cannot. And half of what is worth inheriting — fifteen locale files, the token
layer, three Kamal files, ninety-odd tests — would have to be heredocs inside
that script.

`template.rb` exists so `rails new my-app -m …` works anyway, for the
ergonomics. It is a wrapper, and honestly so: it clones this repository over
the application `rails new` just generated and then runs `bin/new-app`. The
renaming lives in `bin/new-app` and nowhere else, so the two entry points
cannot drift.

It runs inside `after_bundle` deliberately. `apply_rails_template` fires
before `run_bundle` and before the javascript, hotwire, css, kamal and solid
installers, and each of those would reinstall something already here;
`run_after_bundle_callbacks` is the last task the generator runs.

Both scripts delete themselves, and `bin/new-app` takes `LICENSE` with them. A
second run would rename an application that no longer carries the placeholder;
an app that still shipped `template.rb` would be handing out copies of a
starting point it has already left; and an app that kept the MIT notice would
be publishing a licence, and a copyright holder, its author never chose. The
notice covers the template. What is built from it belongs to whoever built
it.

## Stack

Rails edge on Ruby 4, Hotwire, Tailwind v4 through `tailwindcss-rails`,
Propshaft, importmap, PostgreSQL. Solid Queue, Solid Cache and Solid Cable, so
the database is the only stateful dependency and a deploy is one container plus
one Postgres.

**No `package.json`.** importmap serves ES modules straight from `vendor/` or a
CDN, and `tailwindcss-rails` ships a standalone binary. Adding a bundler is a
decision with a cost — a build step, a lockfile, a second dependency audit — not
a step on the way to writing JavaScript.

`.mise.toml` pins the toolchain. `bin/setup` is idempotent and safe to re-run
after every pull.

## Authentication

The Rails 8 session shape, kept small. `has_secure_password` on `User`, one
`Session` row per signed-in browser, the session id in a signed permanent
cookie, and `Current.session` resolving `Current.user`.

A row rather than only a cookie, because a session has to be endable from the
server: signing out on a lost laptop, or dropping every session for an account
under attack, is a `DELETE` either way.

`require_authentication` is a class-level macro rather than a global filter,
because most of a product is public and a filter you have to remember to skip
is a filter somebody forgets to skip. It carries the requested path in
`return_to`, and `SessionsController` refuses anything that is not a local path
— `//host` and `/\host` included, which is how an absolute URL is usually
smuggled past a "starts with a slash" test.

## Plans

`Plan` is a value object, not a table. The tiers are a product decision that
belongs in the repository with the code that enforces them: a row somebody
edited in an admin screen last March is not an answer to "why was this account
refused". Stripe holds the money and the billing history; `Plan` holds the
ceilings.

Two invariants:

- **`Plan.for(user)` is the authority, not `users.plan`.** The column caches
  what Stripe last said. `subscription_live?` decides whether the cache is
  still true, so a failed payment drops the ceilings on the next webhook rather
  than on a nightly job somebody has to write.
- **A plan raises a ceiling and never lowers one**, and the free tier's numbers
  are whatever the product enforced before there were plans. `plan_test.rb`
  asserts both.

Read ceilings through a `Model.ceiling_for(user)` defined next to the
validation that enforces it. The pricing table then renders the number the
product actually refuses on, and the two cannot drift.

## Payments

`Payments::StripeConfig` holds the credentials and verifies webhook signatures.
`Payments::StripeSubscription` creates the Checkout session and the Billing
Portal session. Nothing else talks to Stripe.

Named `StripeConfig` rather than `Stripe` because a `Payments::Stripe` would
shadow the gem's own top-level `Stripe` for every constant lookup inside the
namespace, and `Stripe::Checkout::Session` would silently resolve to the wrong
class.

**One flow up, one flow sideways.** Starting a subscription is a Checkout
session. Switching, cancelling, resuming, and fixing a card that stopped
working are Stripe's own Billing Portal — already localised, already handling
proration and dunning, already the page the customer's bank statement points
at. Rebuilding those screens is three controllers competing with a page Stripe
maintains.

Prices are inline `price_data` rather than dashboard price objects: a handful
of tiers, one currency, one interval, and a repricing that is a deploy setting
rather than a dashboard click nothing in this repository records. The cost is
that a price id cannot identify a plan afterwards, so the plan key travels in
`subscription_data.metadata` and the webhook reads it back. Swap to price ids
at about six tier-currency-interval combinations.

**The webhook is the only thing that believes a payment.** The success redirect
is the browser talking, and the browser is the one party to the transaction the
app does not control. Every handler is idempotent, because Stripe retries what
it did not get a 2xx for and redelivers days later. Two consequences worth
knowing: read `session.mode` before reading `client_reference_id`, since a
subscription session and a one-off payment session carry different things in
that field; and drop an event about a subscription the account has already
moved off, or a late `deleted` for a cancelled-and-resubscribed customer
cancels the one they are currently paying for.

## Rate limits

rack-attack sits below `ActionDispatch::Cookies`, so the signed session cookie
is readable and a limit can follow the person rather than the desk they are
sitting at. The caller id and the plan are memoised in `request.env`, because
several rules ask the same question and the answer should be one row lookup.

Rules are ordered cheapest-first: the path and verb test rejects nearly every
request before anything touches a cookie or the database.

An unidentifiable caller resolves to the free ceilings. A bad credential must
never buy a bigger budget than a good one.

The throttled response is HTML, in the visitor's language. Turbo renders a 4xx
only when it is HTML — a `text/plain` 429 makes the button do nothing at all —
and the responder runs as middleware, below the layout and below Rails' locale
handling, so it builds its own page and reads the locale off the request.

## Bot challenge

Cloudflare Turnstile, because rate limits meter whoever is asking and assume
the asker is hard to become again; a VPN or a fresh private window makes that
assumption false. A challenge asks a different question, and rotating an
address does not answer it.

Unconfigured, it renders nothing and admits everybody. Unreachable, it admits
everybody: an abuse defence that takes the product down when Cloudflare has a
bad minute has done more damage than the abuse it was there to stop.

## Internationalisation

EN, DE and PL from the first view. Three rather than one because adding the
second language to a shipped app means visiting every string in it, and the
habit is cheap only if it is there from the start.

`LocaleNegotiation` is a plain object in `lib/` rather than a controller
concern, because the throttled response is rendered by middleware that never
reaches a controller and still has to answer in the visitor's language.

`bin/ci` runs `i18n-tasks health`, which fails on a missing key and on an
unused one. A key referenced by construction — `plans.#{key}.name` — is
invisible to the static scanner and belongs in `ignore_unused`.

## Frontend

Self-hosted Geist and Geist Mono, variable, latin and latin-ext. latin-ext is
what carries `ą ć ę ł ń ó ś ź ż` and `ä ö ü ß`, so dropping it breaks two of
the three languages. Self-hosted rather than linked because a Google Fonts
request tells a third party which page a visitor is on, on every page load.

The design system is a token layer in `app/assets/tailwind/application.css`.
Views name tokens (`text-ink-600`, `bg-paper`) rather than Tailwind's palette
(`text-slate-600`), which is what makes a restyle a one-file change. Keep that
rule; it is the only thing standing between the app and a hundred views with a
hex code in them.

## Deployment

Kamal, one base `config/deploy.yml` plus a file per destination. Thruster in
front of Puma for asset caching, compression and `X-Sendfile`. Postgres as a
Kamal accessory publishing no ports, so several apps can share a host without
colliding.

Jobs run in their own container (`cmd: bin/jobs`), so `SOLID_QUEUE_IN_PUMA` is
false on every deployed destination — two supervisors on one queue is two
workers claiming the same job. `deployment_config_test.rb` asserts it, along
with a section per deployed environment in every `config/*.yml`: a missing
`production:` in `solid_cable.yml` fails on the box, after the image has built,
pushed and booted, with `undefined method 'connects_to' for nil`.

`config.hosts` is set per destination. A shared kamal-proxy means a request
arriving with another app's Host header is a misroute, not traffic to serve —
with `/up` excluded, because the proxy healthchecks by container IP.

## Testing

Minitest, fixtures, parallel workers. WebMock with `disable_net_connect!`:
every external service is stubbed, because a test that reaches a real endpoint
is flaky and gets a shared address rate-limited.

`test_helper.rb` deletes every credential from `ENV` *after* the environment
loads, because dotenv puts `.env` into `ENV` during boot and would undo a
delete made before it. Without that, a developer with working credentials runs
the suite against live services — slowly, with real spend, and with the key
printed in WebMock's failure output.

Stripe is the exception that proves the rule: the HTTP is stubbed, but the
webhook signature is verified by Stripe's own code against a body signed with
Stripe's own scheme. The one thing that must not be stubbed is the check that
decides whether a payment is real.
