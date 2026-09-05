# Skeleton

The application that is left when you take the product out.

It is the shared structure of two shipped Rails apps — Quento and the brand
screener — extracted after the second one, on the principle that anything both
of them needed and neither of them wanted to write twice belongs here. Clone
it, run `bin/new-app`, and start on the part that is actually the product.

```bash
git clone git@github.com:DeliveristsIO/rails-template.git my-app
cd my-app
bin/new-app my-app          # module, database, Kamal service, mail sender
bin/setup                   # toolchain, gems, database
bin/rails credentials:edit  # this app's own master key
bin/ci                      # everything green before the first commit
bin/dev                     # web + css + jobs
```

`bin/new-app` deletes itself when it is done. It is the only thing here that
cannot survive its own success.

## What is in it

| | |
| --- | --- |
| **Stack** | Rails edge, Hotwire (Turbo + Stimulus), Tailwind v4, Propshaft, importmap, PostgreSQL, Solid Queue / Cache / Cable. No `package.json`, on purpose. |
| **Accounts** | `has_secure_password`, a server-side `Session` row per browser, `Current.user`, and a `require_authentication` filter that returns you to the page you asked for. |
| **Plans** | `Plan` as a value object, not a table. Stripe Checkout up, Stripe's Billing Portal sideways, and a webhook that is idempotent because Stripe redelivers. |
| **Rate limits** | rack-attack in front of the expensive verbs, reading its ceilings off the plan behind the request. A throttled visitor gets an HTML page in their own language, because Turbo will not render a `text/plain` 429. |
| **Bot challenge** | Cloudflare Turnstile, off until its keys are set, admitting everybody when Cloudflare is unreachable. |
| **i18n** | EN / DE / PL from the first view, negotiated from the path and `Accept-Language`. `bin/ci` fails on a missing or unused key. |
| **Design** | Self-hosted Geist, a token layer in `app/assets/tailwind/application.css`, and views that name tokens rather than Tailwind colours — so a restyle is one file. |
| **Checks** | `bin/ci`: RuboCop, i18n-tasks, bundler-audit, importmap audit, Brakeman, tests. The same command runs in GitHub Actions. |
| **Deploys** | Dockerfile with Thruster in front of Puma, Kamal for a staging and a production destination, Postgres as an accessory, jobs in their own container. |
| **Observability** | Sentry, Flipper behind HTTP basic auth, and an `AiUsageEvent` ledger for what model calls actually cost. |

## What is deliberately not in it

No admin, no background-job dashboard, no CSS framework beyond Tailwind, no
API layer, no OAuth provider, no soft deletes, no `ApplicationService` base
class, no `app/queries`. Each of those is a decision the product gets to make
once it knows what it is. The template's job is to have already made the ones
that are the same every time.

## The rules that are worth keeping

Every one of these is here because breaking it cost somebody a day.

1. **The free tier's numbers never go down.** `Plan` raises a ceiling and never
   lowers one, and `test/models/plan_test.rb` asserts it. An account that has
   paid nothing can do today exactly what it could do yesterday.
2. **`Plan.for(user)` is the authority, not the `plan` column.** The column is
   a cache of what Stripe last said; the subscription status is what decides
   whether that is still true. A card that stops working drops the ceilings on
   the next webhook without anybody running anything.
3. **Unconfigured is a supported state.** No Stripe key means nothing is on
   sale, not a button that 500s. No Turnstile keys means no widget, not a form
   that refuses everybody. A fresh clone with an empty `.env` is a working app.
4. **The webhook is the only thing that believes a payment.** The browser
   coming back from a redirect is the one party to the transaction the app does
   not control.
5. **No hardcoded strings.** Three languages from the first view. Adding the
   second language to a shipped app means visiting every string in it.
6. **`bin/ci` is the definition of green.** CI runs that one command rather
   than re-listing its steps, so the thing that passes locally is the thing
   that passes on the branch.
